import SwiftUI

// MARK: - Bubble 卡片样式修饰器

struct BubbleCard: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 40)
                    .fill(color)
                    .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(.white.opacity(0.3), lineWidth: 0)
                    )
            )
            .overlay(
                // 顶部高光
                RoundedRectangle(cornerRadius: 40)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.white.opacity(0.6), .clear]),
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .allowsHitTesting(false)
            )
            .compositingGroup()
    }
}

extension View {
    func bubbleCard(color: Color) -> some View {
        modifier(BubbleCard(color: color))
    }
}

// MARK: - 图标凹坑 (Icon Pit)

struct IconPit: View {
    let systemName: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.25))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.4), lineWidth: 2)
                )

            Text(systemName)
                .font(.system(size: size * 0.5))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 软糖按钮 (Gummy Button)

struct GummyButton: View {
    let label: String
    let color: Color
    let textColor: Color
    let action: () -> Void

    init(label: String, color: Color = Color(hex: "FF85B3"),
         textColor: Color = .white, action: @escaping () -> Void) {
        self.label = label
        self.color = color
        self.textColor = textColor
        self.action = action
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                action()
            }
        }) {
            Text(label)
                .font(.bubbleFont(size: 24, relativeTo: .title2))
                .foregroundColor(textColor)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(color)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 6)
                        .overlay(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.white.opacity(0.5), .clear]),
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        )
                )
        }
        .buttonStyle(GummyButtonStyle())
    }
}

struct GummyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// MARK: - Pop In 动画

struct PopIn: ViewModifier {
    let delay: Double

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(delay)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}

extension View {
    func popIn(delay: Double = 0) -> some View {
        modifier(PopIn(delay: delay))
    }
}

// MARK: - 摇晃动画 (Quiz 错题)

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 1
    var shakes: Int = 3
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 8 * sin(amount * .pi * CGFloat(shakes))
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
