import SwiftUI

/// 统一字体管理
/// 默认使用系统圆体字（iOS 原生），接近 Baloo 2 的圆润风格。
/// 将来如果把 Baloo2 字体文件加入 Bundle，可自动切换到自定义字体。
extension Font {
    /// 粗圆体，用于标题和主文字
    static func bubbleFont(size: CGFloat, relativeTo textStyle: TextStyle = .body) -> Font {
        .system(textStyle, design: .rounded).weight(.heavy)
    }

    /// 常规字体
    static func bubbleFont(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}
