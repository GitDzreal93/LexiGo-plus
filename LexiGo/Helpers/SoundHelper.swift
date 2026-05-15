import UIKit
import AVFoundation

/// 触觉反馈 + 音效
enum Haptic {
    case light
    case medium
    case success
    case error

    func play() {
        switch self {
        case .light:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    /// 答对音效（程序生成的和弦铃声，无需外部音频文件）
    static func playSuccessSound() {
        let sampleRate = 22050
        let duration: Float = 0.35
        let numSamples = Int(sampleRate * duration)

        var samples = [Float](repeating: 0, count: numSamples)

        for i in 0..<numSamples {
            let t = Float(i) / Float(sampleRate)
            // A 大三和弦：A5(880Hz) + C#6(1108.8Hz) + E6(1320Hz)
            var sample = sin(2 * .pi * 880 * t) * 0.30
            sample += sin(2 * .pi * 1108.8 * t) * 0.25
            sample += sin(2 * .pi * 1320 * t) * 0.20

            // 淡入淡出包络
            let fadeIn = min(1.0, t / 0.02)
            let fadeOut = min(1.0, (duration - t) / 0.06)
            sample *= fadeIn * fadeOut * 0.6

            samples[i] = sample
        }

        let wavData = Self.buildWAV(from: samples, sampleRate: sampleRate)
        playWAVData(wavData)
    }

    private static var audioPlayer: AVAudioPlayer?

    private static func playWAVData(_ data: Data) {
        guard !data.isEmpty else { return }
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.volume = 0.5
            audioPlayer?.play()
        } catch {
            print("⚠️ Failed to play success sound: \(error)")
        }
    }

    private static func buildWAV(from samples: [Float], sampleRate: Int) -> Data {
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
            int16Samples[i] = Int16(clamped * Float(Int16.max))
        }
        int16Samples.withUnsafeBytes { data.append(contentsOf: $0) }

        return data
    }
}
