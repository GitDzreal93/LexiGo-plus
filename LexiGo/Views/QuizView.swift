import SwiftUI

// MARK: - 听音辨图测验

struct QuizView: View {
    @ObservedObject var vm: QuizVM
    @ObservedObject var appVM: FlashcardVM
    let category: String

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                Button(action: { appVM.goBackToFlashcard() }) {
                    Text("◀")
                        .font(.system(size: 28))
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 4)
                        )
                }

                Spacer()

                Text("🎧 Listen & Find!")
                    .font(.bubbleFont(size: 28, relativeTo: .title2))
                    .foregroundColor(Color(hex: "4A4E69"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    )

                Spacer()

                // 星星
                HStack(spacing: 4) {
                    Text("🫧")
                        .font(.system(size: 24))
                    Text("\(appVM.stars)")
                        .font(.bubbleFont(size: 24))
                        .foregroundColor(Color(hex: "FF85B3"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)

            Spacer()

            // 选项网格
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(vm.options.enumerated()), id: \.element.id) { index, word in
                    QuizOptionCard(
                        word: word,
                        isDisabled: vm.disabledIndices.contains(index),
                        isSelected: vm.selectedWord?.word == word.word,
                        isCorrect: vm.isCorrect
                    )
                    .onTapGesture {
                        guard !vm.disabledIndices.contains(index) else { return }
                        let impact = UIImpactFeedbackGenerator(style: .soft)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            vm.selectOption(at: index)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // 重新播放按钮
            Button(action: { vm.repeatAudio() }) {
                Text("🔊 Say it again")
                    .font(.bubbleFont(size: 26, relativeTo: .title3))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color(hex: "60D0FF"))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 6)
                            .overlay(
                                Capsule()
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [.white.opacity(0.5), .clear]),
                                        startPoint: .top, endPoint: .center
                                    ))
                            )
                    )
            }
            .buttonStyle(GummyButtonStyle())
            .padding(.bottom, 40)
        }
        .ignoresSafeArea()
        .onAppear {
            vm.configure(category: category, appVM: appVM)
        }
    }
}

// MARK: - 测验选项卡片

struct QuizOptionCard: View {
    let word: WordEntry
    let isDisabled: Bool
    let isSelected: Bool
    let isCorrect: Bool?

    @State private var shakeAmount: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.white.opacity(0.6), .clear]),
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )

            VStack(spacing: 4) {
                // 图片
                if let image = word.loadImage() {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 3)
                } else {
                    Text("🖼️")
                        .font(.system(size: 40))
                }

                // 单词文字（让家长看字教学）
                Text(word.display)
                    .font(.bubbleFont(size: 18, relativeTo: .caption))
                    .foregroundColor(Color(hex: "6366F1"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            }
        }
        .frame(height: 190)
        .opacity(isDisabled ? 0.35 : 1.0)
        .saturation(isDisabled ? 0.0 : 1.0)
        .scaleEffect(isSelected && isCorrect == true ? 1.05 : 1.0)
        .modifier(ShakeEffect(amount: isSelected && isCorrect == false ? shakeAmount : 0))
        .animation(.spring(response: 0.3), value: isDisabled)
        .animation(.spring(response: 0.3), value: isSelected)
    }

    private var backgroundColor: Color {
        if isSelected && isCorrect == true {
            return Color(hex: "9CE32D").opacity(0.3)
        }
        if isDisabled {
            return Color(hex: "E5E5E5").opacity(0.5)
        }
        return .white.opacity(0.95)
    }
}
