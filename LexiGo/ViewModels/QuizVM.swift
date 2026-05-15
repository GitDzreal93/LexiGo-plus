import Foundation
import SwiftUI

@MainActor
class QuizVM: ObservableObject {
    @Published var options: [WordEntry] = []
    @Published var correctAnswer: WordEntry? = nil
    @Published var selectedWord: WordEntry? = nil
    @Published var isCorrect: Bool? = nil
    @Published var disabledIndices: Set<Int> = []

    let translationService = TranslationService.shared

    private weak var appVM: FlashcardVM?
    private var category: String = ""

    var translation: String? {
        guard translationService.showTranslation,
              let word = correctAnswer,
              let t = translationService.translate(word.word)
        else { return nil }
        return t
    }

    var targetText: String {
        correctAnswer?.display ?? ""
    }

    func configure(category: String, appVM: FlashcardVM) {
        self.category = category
        self.appVM = appVM
        loadQuestion()
    }

    func loadQuestion() {
        let words = WordDatabase.shared.words(for: category)
        guard words.count >= 4 else { return }

        selectedWord = nil
        isCorrect = nil
        disabledIndices = []
        options = []

        guard let target = words.randomElement() else { return }
        correctAnswer = target

        var pool = [target]
        while pool.count < 4 {
            if let random = words.randomElement(), !pool.contains(where: { $0.word == random.word }) {
                pool.append(random)
            }
        }
        options = pool.shuffled()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            TTSManager.shared.speak(text: target.display, ipa: target.ipa)
        }
    }

    func selectOption(at index: Int) {
        guard let correct = correctAnswer, selectedWord == nil else { return }
        let chosen = options[index]

        if chosen.word == correct.word {
            selectedWord = chosen
            isCorrect = true
            appVM?.stars += 1
            Haptic.success.play()
            Haptic.playSuccessSound()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.loadQuestion()
            }
        } else {
            selectedWord = chosen
            isCorrect = false
            disabledIndices.insert(index)
            TTSManager.shared.speak(text: "It's not \(correct.display)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.selectedWord = nil
                self.isCorrect = nil
            }
        }
    }

    func repeatAudio() {
        guard let correct = correctAnswer else { return }
        TTSManager.shared.speak(text: correct.display, ipa: correct.ipa)
    }

    func toggleTranslation() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            translationService.showTranslation.toggle()
        }
    }

    func toggleEnglishWord() {
        translationService.showEnglishWord.toggle()
        objectWillChange.send()
    }

    func cycleLanguage() {
        let all = AppLanguage.allCases
        guard let idx = all.firstIndex(of: translationService.currentLanguage) else { return }
        let next = all[(idx + 1) % all.count]
        translationService.currentLanguage = next
        objectWillChange.send()
    }
}
