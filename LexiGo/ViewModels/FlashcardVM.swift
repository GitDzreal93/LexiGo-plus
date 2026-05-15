import Foundation
import SwiftUI

// MARK: - 应用状态管理

@MainActor
class FlashcardVM: ObservableObject {
    // 页面导航
    enum Page: Equatable {
        case home
        case flashcard(category: String)
        case quiz(category: String)
    }

    @Published var currentPage: Page = .home
    @Published var currentIndex: Int = 0
    @Published var wordRevealed: Bool = false
    @Published var showOnlyNew: Bool = false

    // 积分
    @Published var stars: Int {
        didSet { UserDefaults.standard.set(stars, forKey: "lexigo_stars") }
    }

    // 已学分类（自动计算：分类内所有词都学会了）
    @Published var learnedCategories: Set<String> {
        didSet { saveLearned() }
    }

    // 已学单词
    @Published var learnedWords: Set<String> {
        didSet { saveLearnedWords() }
    }

    // MARK: - 翻译

    let translationService = TranslationService.shared

    var currentWordTranslation: String? {
        guard let word = currentWord,
              translationService.showTranslation,
              let t = translationService.translate(word.word)
        else { return nil }
        return t
    }

    func cycleLanguage() {
        let all = AppLanguage.allCases
        guard let idx = all.firstIndex(of: translationService.currentLanguage) else { return }
        let next = all[(idx + 1) % all.count]
        translationService.currentLanguage = next
        objectWillChange.send()
    }

    func toggleTranslation() {
        translationService.showTranslation.toggle()
        objectWillChange.send()
    }

    func toggleEnglishWord() {
        translationService.showEnglishWord.toggle()
        objectWillChange.send()
    }

    // MARK: - 计算属性

    var currentWord: WordEntry? {
        let words = currentCategoryWords
        guard words.indices.contains(currentIndex) else { return nil }
        return words[currentIndex]
    }

    /// 当前显示的单词列表（受 showOnlyNew 过滤）
    var currentCategoryWords: [WordEntry] {
        guard case let .flashcard(cat) = currentPage else { return [] }
        let all = WordDatabase.shared.words(for: cat)
        if showOnlyNew {
            return all.filter { !learnedWords.contains($0.id) }
        }
        return all
    }

    /// 分类下全部词（不受过滤影响，用于进度计算）
    private var allCategoryWords: [WordEntry] {
        guard case let .flashcard(cat) = currentPage else { return [] }
        return WordDatabase.shared.words(for: cat)
    }

    var currentCategoryName: String {
        guard case let .flashcard(cat) = currentPage else { return "" }
        return CategoryDef.find(by: cat)?.name ?? cat
    }

    var currentCategoryId: String {
        guard case let .flashcard(cat) = currentPage else { return "" }
        return cat
    }

    var isCurrentWordLearned: Bool {
        guard let word = currentWord else { return false }
        return learnedWords.contains(word.id)
    }

    /// 分类是否全部学完（自动判断）
    var isCurrentCategoryLearned: Bool {
        guard case let .flashcard(cat) = currentPage else { return false }
        let all = WordDatabase.shared.words(for: cat)
        guard !all.isEmpty else { return false }
        return all.allSatisfy { learnedWords.contains($0.id) }
    }

    var wordProgressText: String {
        let all = allCategoryWords
        let learned = all.filter { learnedWords.contains($0.id) }.count
        return "\(learned)/\(all.count)"
    }

    /// 当前卡片位置（如 "3/204"）
    var positionText: String {
        let total = currentCategoryWords.count
        guard total > 0 else { return "0/0" }
        return "\(currentIndex + 1)/\(total)"
    }

    // MARK: - 初始化

    init() {
        stars = UserDefaults.standard.integer(forKey: "lexigo_stars")
        learnedCategories = Set(UserDefaults.standard.stringArray(forKey: "lexigo_learned") ?? [])
        learnedWords = Set(UserDefaults.standard.stringArray(forKey: "lexigo_learned_words") ?? [])
    }

    // MARK: - 导航

    func goHome() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            currentPage = .home
            wordRevealed = false
        }
    }

    func selectCategory(_ id: String) {
        currentIndex = 0
        wordRevealed = false
        let all = WordDatabase.shared.words(for: id)

        // 立即预加载第一个词的音频，利用动画时间完成合成
        if let first = all.first {
            TTSManager.shared.preload(text: first.display, ipa: first.ipa)
        }

        if showOnlyNew && all.allSatisfy({ learnedWords.contains($0.id) }) {
            showOnlyNew = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                self.currentPage = .flashcard(category: id)
            }
        }
    }

    // MARK: - 闪卡操作

    func revealWord() {
        if !wordRevealed {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                wordRevealed = true
            }
            autoSpeak()
        } else {
            autoSpeak()
        }
    }

    /// 预加载下一张卡的音频缓存
    func preloadAdjacent() {
        let words = currentCategoryWords
        guard words.count > 1 else { return }
        let nextIdx = (currentIndex + 1) % words.count
        TTSManager.shared.preload(text: words[nextIdx].display, ipa: words[nextIdx].ipa)
    }

    func nextCard() {
        let words = currentCategoryWords
        if words.isEmpty { return }
        currentIndex = (currentIndex + 1) % words.count
        wordRevealed = false
    }

    func prevCard() {
        let words = currentCategoryWords
        if words.isEmpty { return }
        currentIndex = (currentIndex - 1 + words.count) % words.count
        wordRevealed = false
    }

    func autoSpeak() {
        guard let word = currentWord else { return }
        TTSManager.shared.speak(text: word.display, ipa: word.ipa)
    }

    // MARK: - 逐词学习

    /// 标记/取消当前词已学
    func toggleWordLearned() {
        guard let word = currentWord else { return }
        let justLearned = !learnedWords.contains(word.id)

        if justLearned {
            learnedWords.insert(word.id)
            stars += 1
        } else {
            learnedWords.remove(word.id)
        }

        // "仅新词"模式下，学完后自动跳到下一个未学词
        if justLearned && showOnlyNew {
            wordRevealed = false
            let remaining = currentCategoryWords
            if remaining.isEmpty {
                // 全部学完
                if case let .flashcard(cat) = currentPage {
                    learnedCategories.insert(cat)
                }
                showOnlyNew = false
                currentIndex = 0
            } else if currentIndex >= remaining.count {
                currentIndex = remaining.count - 1
            }
        }
    }

    /// 切换"仅新词"模式
    func toggleShowOnlyNew() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            showOnlyNew.toggle()
            currentIndex = 0
            wordRevealed = false
        }
    }

    // MARK: - 分类级别

    /// 手动标记整个分类已学/未学
    func toggleCategoryLearned() {
        guard case let .flashcard(cat) = currentPage else { return }

        if isCurrentCategoryLearned {
            // 取消分类完成 → 清除所有词的已学状态
            for word in allCategoryWords {
                learnedWords.remove(word.id)
            }
            learnedCategories.remove(cat)
        } else {
            // 标记全部分类完成
            for word in allCategoryWords {
                learnedWords.insert(word.id)
            }
            learnedCategories.insert(cat)
            stars += 1
            AdMobManager.shared.showInterstitial()
        }
        // 更新 learnedCategories 的自动保存
        saveLearned()
        saveLearnedWords()
    }

    private func saveLearned() {
        UserDefaults.standard.set(Array(learnedCategories), forKey: "lexigo_learned")
    }

    private func saveLearnedWords() {
        UserDefaults.standard.set(Array(learnedWords), forKey: "lexigo_learned_words")
    }

    // MARK: - 测验

    func startQuiz() {
        guard case let .flashcard(cat) = currentPage else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            currentPage = .quiz(category: cat)
        }
        AdMobManager.shared.showInterstitial()
    }

    func goBackToFlashcard() {
        guard case let .quiz(cat) = currentPage else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            currentPage = .flashcard(category: cat)
        }
    }
}
