import UIKit

/// 触觉反馈辅助（音效用系统 TTS 替代，不需要额外音频文件）
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
}
