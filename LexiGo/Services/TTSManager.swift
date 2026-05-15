import AVFoundation
import KokoroCoreML

/// 音频管理器
///
/// 使用 jud/kokoro-coreml（Kokoro-82M 纯 CoreML 引擎）
/// 模型从 app bundle 的 Models/ 加载（首次构建需下载）
/// 若模型不可用则自动降级到 AVSpeechSynthesizer
@MainActor
class TTSManager: NSObject, ObservableObject {
    static let shared = TTSManager()

    @Published var isReady: Bool = false
    @Published var isSpeaking: Bool = false

    private var engine: KokoroEngine?
    private let fallbackSynth = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?

    /// 会话内音频缓存（text -> WAV Data）
    private var audioCache: [String: Data] = [:]

    /// 当前使用的发音人
    private let voiceName = "af_heart"

    override private init() {
        super.init()
        fallbackSynth.delegate = self
        loadEngine()
    }

    // MARK: - 引擎加载

    private func loadEngine() {
        Task.detached(priority: .high) {
            // 优先从 bundle 加载（预打包的 Models/ 文件夹）
            if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("kokoro_models"),
               KokoroEngine.isDownloaded(at: bundleURL)
            {
                do {
                    let eng = try KokoroEngine(modelDirectory: bundleURL)
                    await MainActor.run {
                        self.engine = eng
                        self.isReady = true
                        print("✅ Kokoro engine loaded from bundle. \(eng.availableVoices.count) voices")
                    }
                    return
                } catch {
                    print("⚠️ Kokoro bundle load failed: \(error)")
                }
            }

            // 回退到缓存目录
            let cacheDir = KokoroEngine.defaultModelDirectory
            if KokoroEngine.isDownloaded(at: cacheDir) {
                do {
                    let eng = try KokoroEngine(modelDirectory: cacheDir)
                    await MainActor.run {
                        self.engine = eng
                        self.isReady = true
                        print("✅ Kokoro engine loaded from cache.")
                    }
                    return
                } catch {
                    print("⚠️ Kokoro cache load failed: \(error)")
                }
            }

            print("⚠️ Kokoro models not available — using AVSpeechSynthesizer fallback")
        }
    }

    // MARK: - 公开接口

    /// 播放单词发音
    func speak(text: String, ipa: String? = nil, slow: Bool = false) {
        stop()

        // 缓存命中
        if let cached = audioCache[text] {
            playWAVData(cached)
            return
        }

        guard let engine = engine, isReady else {
            speakWithFallback(text: text, slow: slow)
            return
        }

        isSpeaking = true
        let speed: Float = slow ? 0.55 : 0.75

        Task.detached(priority: .userInitiated) {
            [weak self, engine, text, ipa, speed, voiceName] in
            do {
                let result: SynthesisResult
                if let ipa = ipa, !ipa.isEmpty {
                    result = try engine.synthesize(ipa: ipa, voice: voiceName, speed: speed)
                } else {
                    result = try engine.synthesize(text: text, voice: voiceName, speed: speed)
                }
                let wavData = Self.buildWAV(from: result.samples)

                await MainActor.run { [text, wavData] in
                    guard let self else { return }
                    self.audioCache[text] = wavData
                    self.playWAVData(wavData)
                    self.isSpeaking = false
                }
            } catch {
                await MainActor.run { [text, slow] in
                    guard let self else { return }
                    print("⚠️ Kokoro synthesis failed: \(error)")
                    self.isSpeaking = false
                    self.speakWithFallback(text: text, slow: slow)
                }
            }
        }
    }

    func stop() {
        fallbackSynth.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        isSpeaking = false
    }

    // MARK: - WAV 播放

    private func playWAVData(_ data: Data) {
        guard !data.isEmpty else { return }
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
        } catch {
            print("⚠️ AVAudioPlayer init failed: \(error)")
        }
    }

    // MARK: - WAV 构建（16-bit PCM）

    private nonisolated static func buildWAV(from samples: [Float], sampleRate: Int = 24000) -> Data {
        let numSamples = samples.count
        let dataSize = numSamples * 2
        let fileSize = 44 + dataSize

        var data = Data(capacity: fileSize)

        func appendLE<T: FixedWidthInteger>(_ value: T) {
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])  // "RIFF"
        appendLE(UInt32(fileSize - 8))
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])  // "WAVE"
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])  // "fmt "
        appendLE(UInt32(16))
        appendLE(UInt16(1))   // PCM
        appendLE(UInt16(1))   // mono
        appendLE(UInt32(sampleRate))
        appendLE(UInt32(sampleRate * 2))
        appendLE(UInt16(2))   // block align
        appendLE(UInt16(16))  // bits per sample
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])  // "data"
        appendLE(UInt32(dataSize))

        var int16Samples = [Int16](repeating: 0, count: numSamples)
        for i in 0..<numSamples {
            let clamped = max(-1.0, min(1.0, samples[i]))
            int16Samples[i] = Int16(clamped * 32767)
        }
        int16Samples.withUnsafeBytes { data.append(contentsOf: $0) }

        return data
    }

    // MARK: - 降级方案（AVSpeechSynthesizer）

    private func speakWithFallback(text: String, slow: Bool) {
        let utterance = AVSpeechUtterance(string: text)
        let usVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
        utterance.voice = usVoices.first(where: { $0.quality == .premium })
            ?? usVoices.first(where: { $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = slow ? 0.22 : 0.45
        utterance.pitchMultiplier = 1.2
        utterance.volume = 1.0
        isSpeaking = true
        fallbackSynth.speak(utterance)
    }
}

// MARK: - AVAudioPlayerDelegate

extension TTSManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            Self.shared.isSpeaking = false
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            Self.shared.isSpeaking = false
        }
    }
}
