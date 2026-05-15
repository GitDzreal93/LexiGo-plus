import AVFoundation
import KokoroCoreML

/// 音频管理器
///
/// 防崩溃策略：
/// - 所有 engine.synthesize() 通过 NSLock 串行化（引擎非线程安全）
/// - speak 和 preload 各自独立 OperationQueue，不互相阻塞排队
/// - preload 用 tryLock()，engine 空闲才跑；speak 用 lock() 保证执行
/// - 若模型不可用则自动降级到 AVSpeechSynthesizer
@MainActor
class TTSManager: NSObject, ObservableObject {
    static let shared = TTSManager()

    @Published var isReady: Bool = false
    @Published var isSpeaking: Bool = false

    private var engine: KokoroEngine?
    private let fallbackSynth = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var audioCache: [String: Data] = [:]
    private let voiceName = "af_heart"

    // MARK: - 并发控制

    /// 保护 engine.synthesize() 的互斥锁，同一时间只有一个线程能合成
    private let engineLock = NSLock()

    /// speak 专用队列：立即执行，不被 preload 阻塞
    private let speakQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInitiated
        return q
    }()

    /// preload 专用队列：只在 engine 空闲时运行
    private let preloadQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .background
        return q
    }()

    override private init() {
        super.init()
        fallbackSynth.delegate = self
        loadEngine()
    }

    // MARK: - 引擎加载

    private func loadEngine() {
        Task.detached(priority: .high) {
            if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("kokoro_models"),
               KokoroEngine.isDownloaded(at: bundleURL)
            {
                do {
                    let eng = try KokoroEngine(modelDirectory: bundleURL)
                    await MainActor.run {
                        self.engine = eng
                        self.isReady = true
                        print("✅ Kokoro engine loaded from bundle. \(eng.availableVoices.count) voices")
                        self.warmUpEngine()
                    }
                    return
                } catch {
                    print("⚠️ Kokoro bundle load failed: \(error)")
                }
            }

            let cacheDir = KokoroEngine.defaultModelDirectory
            if KokoroEngine.isDownloaded(at: cacheDir) {
                do {
                    let eng = try KokoroEngine(modelDirectory: cacheDir)
                    await MainActor.run {
                        self.engine = eng
                        self.isReady = true
                        print("✅ Kokoro engine loaded from cache.")
                        self.warmUpEngine()
                    }
                    return
                } catch {
                    print("⚠️ Kokoro cache load failed: \(error)")
                }
            }

            print("⚠️ Kokoro models not available — using AVSpeechSynthesizer fallback")
        }
    }

    /// 引擎加载后立即预热一个短词，让 CoreML 模型热起来
    /// 通过 preload 路径走，受 engineLock 保护
    private func warmUpEngine() {
        preload(text: "hello")
    }

    // MARK: - 公开接口

    /// 预生成音频并缓存（不播放）
    func preload(text: String, ipa: String? = nil) {
        guard let engine = engine, isReady else { return }
        guard audioCache[text] == nil else { return }

        let speed: Float = 0.75
        let op = BlockOperation { [engine, text, ipa, speed, voiceName] in
            // 只在 engine 空闲时执行，不阻塞 speak
            guard self.engineLock.try() else { return }
            defer { self.engineLock.unlock() }

            do {
                let result: SynthesisResult
                if let ipa = ipa, !ipa.isEmpty {
                    result = try engine.synthesize(ipa: ipa, voice: voiceName, speed: speed)
                } else {
                    result = try engine.synthesize(text: text, voice: voiceName, speed: speed)
                }
                let wavData = Self.buildWAV(from: result.samples)
                DispatchQueue.main.async {
                    let mgr = TTSManager.shared
                    guard mgr.audioCache[text] == nil else { return }
                    mgr.audioCache[text] = wavData
                }
            } catch {
                // 预加载失败不影响主流程
            }
        }
        preloadQueue.addOperation(op)
    }

    /// 播放单词发音
    func speak(text: String, ipa: String? = nil) {
        stop()

        if let cached = audioCache[text] {
            playWAVData(cached)
            return
        }

        guard let engine = engine, isReady else {
            speakWithFallback(text: text)
            return
        }

        isSpeaking = true
        let speed: Float = 0.75

        // 取消上一个等待中的 speak（如果快速连续滑动）
        speakQueue.cancelAllOperations()

        let op = BlockOperation { [engine, text, ipa, speed, voiceName] in
            self.engineLock.lock()
            defer { self.engineLock.unlock() }

            // 检查缓存（等待锁期间 preload 可能已完成）
            var cached: Data?
            DispatchQueue.main.sync { cached = TTSManager.shared.audioCache[text] }
            if let cached = cached {
                DispatchQueue.main.async {
                    TTSManager.shared.playWAVData(cached)
                    TTSManager.shared.isSpeaking = false
                }
                return
            }

            do {
                let result: SynthesisResult
                if let ipa = ipa, !ipa.isEmpty {
                    result = try engine.synthesize(ipa: ipa, voice: voiceName, speed: speed)
                } else {
                    result = try engine.synthesize(text: text, voice: voiceName, speed: speed)
                }
                let wavData = Self.buildWAV(from: result.samples)
                DispatchQueue.main.async {
                    let mgr = TTSManager.shared
                    mgr.audioCache[text] = wavData
                    mgr.playWAVData(wavData)
                    mgr.isSpeaking = false
                }
            } catch {
                DispatchQueue.main.async {
                    let mgr = TTSManager.shared
                    mgr.isSpeaking = false
                    mgr.speakWithFallback(text: text)
                }
            }
        }
        speakQueue.addOperation(op)
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

        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        appendLE(UInt32(fileSize - 8))
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        appendLE(UInt32(16))
        appendLE(UInt16(1))
        appendLE(UInt16(1))
        appendLE(UInt32(sampleRate))
        appendLE(UInt32(sampleRate * 2))
        appendLE(UInt16(2))
        appendLE(UInt16(16))
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
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

    private func speakWithFallback(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        let usVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
        utterance.voice = usVoices.first(where: { $0.quality == .premium })
            ?? usVoices.first(where: { $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
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
