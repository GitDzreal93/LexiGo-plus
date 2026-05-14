import AVFoundation
import KokoroTTS

/// 音频管理器
///
/// 使用 aufklarer/Kokoro-82M-CoreML 引擎进行高保真离线语音合成。
/// 模型在 App 启动时后台预热，点击发音时零延迟。
///
/// 如果 Kokoro 模型未加载完成（启动初期），自动降级到 AVSpeechSynthesizer。
@MainActor
class TTSManager: NSObject, ObservableObject {
    static let shared = TTSManager()

    @Published var isReady: Bool = false
    @Published var isSpeaking: Bool = false

    private var kokoro: KokoroTTSModel?
    private let fallbackSynth = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?

    /// 当前使用的发音人：American Female "Heart"（温暖亲切的女生）
    private let voiceName = "af_heart"

    override private init() {
        super.init()
        fallbackSynth.delegate = self

        Task { [weak self] in
            await self?.loadModel()
        }
    }

    // MARK: - 模型加载

    private func loadModel() async {
        print("🎤 Loading Kokoro TTS model...")

        guard let bundlePath = Bundle.main.resourcePath else {
            print("⚠️ Cannot access bundle path")
            return
        }

        let bundledModelDir = (bundlePath as NSString).appendingPathComponent("kokoro-coreml")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: bundledModelDir) else {
            print("⚠️ Kokoro model not bundled at: \(bundledModelDir)")
            return
        }

        // 需要从 Bundle（只读）拷贝到可写目录
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("kokoro-coreml", isDirectory: true)

        if !fileManager.fileExists(atPath: cacheDir.path) {
            do {
                try fileManager.copyItem(atPath: bundledModelDir, toPath: cacheDir.path)
                print("✅ Copied model to cache: \(cacheDir.path)")
            } catch {
                print("⚠️ Failed to copy model to cache: \(error)")
                return
            }
        }

        do {
            let model = try await KokoroTTSModel.fromPretrained(
                modelId: "aufklarer/Kokoro-82M-CoreML",
                voice: voiceName,
                cacheDir: cacheDir,
                offlineMode: true
            )
            self.kokoro = model
            self.isReady = true
            print("✅ Kokoro TTS loaded! Voice: \(voiceName)")
        } catch {
            print("⚠️ Kokoro load failed: \(error)")
        }
    }

    // MARK: - 公开接口

    /// 播放单词发音
    func speak(text: String, ipa: String? = nil, slow: Bool = false) {
        stop()

        if let kokoro = kokoro, isReady {
            speakWithKokoro(kokoro, text: text, slow: slow)
        } else {
            speakWithFallback(text: text, slow: slow)
        }
    }

    func stop() {
        fallbackSynth.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        isSpeaking = false
    }

    // MARK: - Kokoro 引擎

    private func speakWithKokoro(_ model: KokoroTTSModel, text: String, slow: Bool) {
        let speed: Float = slow ? 0.6 : 1.0

        Task { @MainActor in
            do {
                isSpeaking = true
                let pcmFloats: [Float] = try model.synthesize(
                    text: text,
                    voice: voiceName,
                    speed: speed
                )
                try playPCMAudio(pcmFloats, sampleRate: 24000)
                isSpeaking = false
            } catch {
                print("⚠️ Kokoro synthesis failed: \(error)")
                isSpeaking = false
                speakWithFallback(text: text, slow: slow)
            }
        }
    }

    /// 将 [Float] PCM 数据转为 WAV 并播放
    private func playPCMAudio(_ samples: [Float], sampleRate: Int) throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("kokoro_\(UUID().uuidString).wav")

        var wavData = Data()

        // RIFF header
        let dataSize = UInt32(samples.count * 4)
        let fileSize = dataSize + 36
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(Data(of: fileSize))
        wavData.append("WAVE".data(using: .ascii)!)

        // fmt chunk (IEEE Float 32)
        let audioFormat: UInt16 = 3
        let numChannels: UInt16 = 1
        let sr = UInt32(sampleRate)
        let byteRate = sr * UInt32(numChannels * 4)
        let blockAlign = numChannels * 4
        let bitsPerSample: UInt16 = 32

        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(Data(of: UInt32(16)))
        wavData.append(Data(of: audioFormat))
        wavData.append(Data(of: numChannels))
        wavData.append(Data(of: sr))
        wavData.append(Data(of: byteRate))
        wavData.append(Data(of: blockAlign))
        wavData.append(Data(of: bitsPerSample))

        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(Data(of: dataSize))
        samples.withUnsafeBytes { wavData.append(Data($0)) }

        try wavData.write(to: tempFile)

        audioPlayer = try AVAudioPlayer(contentsOf: tempFile)
        audioPlayer?.delegate = self
        audioPlayer?.volume = 1.0
        audioPlayer?.play()
    }

    // MARK: - 降级方案 (AVSpeechSynthesizer)

    private func speakWithFallback(text: String, slow: Bool) {
        let utterance = AVSpeechUtterance(string: text)

        // 优先使用 Premium 品质（Siri 语音，iOS 17+），模拟器上可能回退
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
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isSpeaking = false
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}

// MARK: - Helper

extension Data {
    init<T>(of value: T) {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
    }
}
