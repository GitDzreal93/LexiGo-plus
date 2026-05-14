import Foundation
import SwiftUI

@MainActor
class QuizVM: ObservableObject {
    @Published var options: [WordEntry] = []
    @Published var correctAnswer: WordEntry? = nil
    @Published var selectedWord: WordEntry? = nil
    @Published var isCorrect: Bool? = nil
    @Published var disabledIndices: Set<Int> = []

    private weak var appVM: FlashcardVM?
    private var category: String = ""

    func configure(category: String, appVM: FlashcardVM) {
        self.category = category
        self.appVM = appVM
        loadQuestion()
    }

    func loadQuestion() {
        let words = WordDatabase.shared.words(for: category)
        guard words.count >= 4 else { return }

        // 重置状态
        selectedWord = nil
        isCorrect = nil
        disabledIndices = []
        options = []

        // 随机选正确答案
        guard let target = words.randomElement() else { return }
        correctAnswer = target

        // 凑 4 个选项并打乱
        var pool = [target]
        while pool.count < 4 {
            if let random = words.randomElement(), !pool.contains(where: { $0.word == random.word }) {
                pool.append(random)
            }
        }
        options = pool.shuffled()

        // 延迟发音（让动画先播）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            TTSManager.shared.speak(text: target.display, ipa: target.ipa)
        }
    }

    func selectOption(at index: Int) {
        guard let correct = correctAnswer, selectedWord == nil else { return }
        let chosen = options[index]

        if chosen.word == correct.word {
            // 正确
            selectedWord = chosen
            isCorrect = true
            appVM?.stars += 1
            TTSManager.shared.speak(text: "Great job!")

            // 1.5 秒后下一题
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.loadQuestion()
            }
        } else {
            // 错误
            selectedWord = chosen
            isCorrect = false
            disabledIndices.insert(index)
            TTSManager.shared.speak(text: "Uh oh")

            // 短暂摇晃后恢复，但禁用该选项
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.selectedWord = nil
                self.isCorrect = nil
            }

            // 排除法：该选项变灰
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.disabledIndices.insert(index)
            }
        }
    }

    func repeatAudio() {
        guard let correct = correctAnswer else { return }
        TTSManager.shared.speak(text: correct.display, ipa: correct.ipa)
    }
}
