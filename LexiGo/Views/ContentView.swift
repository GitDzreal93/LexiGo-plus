import SwiftUI

struct ContentView: View {
    @StateObject private var vm = FlashcardVM()
    @StateObject private var quizVM = QuizVM()

    var body: some View {
        ZStack {
            // 背景
            BackgroundView()

            switch vm.currentPage {
            case .home:
                CategoryGrid(vm: vm)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

            case .flashcard:
                FlashcardView(vm: vm)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

            case .quiz(let category):
                QuizView(vm: quizVM, appVM: vm, category: category)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: vm.currentPage)
    }
}

// MARK: - 背景

struct BackgroundView: View {
    var body: some View {
        ZStack {
            Color(hex: "F8F5EE").ignoresSafeArea()

            // 装饰性光晕
            Circle()
                .fill(Color(hex: "FF85B3").opacity(0.08))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: -120, y: -200)

            Circle()
                .fill(Color(hex: "60D0FF").opacity(0.08))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: 120, y: 200)
        }
    }
}
