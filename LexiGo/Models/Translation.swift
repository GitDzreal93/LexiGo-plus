import Foundation

// MARK: - 支持的语言

enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case zh = "zh"
    case ja = "ja"
    case ko = "ko"

    var displayName: String {
        switch self {
        case .zh: "中文"
        case .ja: "日本語"
        case .ko: "한국어"
        }
    }

    var flag: String {
        switch self {
        case .zh: "🇨🇳"
        case .ja: "🇯🇵"
        case .ko: "🇰🇷"
        }
    }
}

// MARK: - 翻译数据

struct Translations: Codable, Sendable {
    let zh: String?
    let ja: String?
    let ko: String?

    func value(for language: AppLanguage) -> String? {
        switch language {
        case .zh: zh
        case .ja: ja
        case .ko: ko
        }
    }
}

// MARK: - 翻译服务

@MainActor
class TranslationService: ObservableObject {
    static let shared = TranslationService()

    @Published var currentLanguage: AppLanguage = .zh {
        didSet { UserDefaults.standard.set(currentLanguage.rawValue, forKey: "lexigo_translation_lang") }
    }

    @Published var showTranslation: Bool = true {
        didSet { UserDefaults.standard.set(showTranslation, forKey: "lexigo_show_translation") }
    }

    @Published var showEnglishWord: Bool = true {
        didSet { UserDefaults.standard.set(showEnglishWord, forKey: "lexigo_show_english") }
    }

    private var translations: [String: Translations] = [:]

    private init() {
        currentLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "lexigo_translation_lang") ?? "") ?? .zh
        showTranslation = UserDefaults.standard.object(forKey: "lexigo_show_translation") as? Bool ?? true
        showEnglishWord = UserDefaults.standard.object(forKey: "lexigo_show_english") as? Bool ?? true
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "translations", withExtension: "json") else {
            print("⚠️ translations.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            translations = try JSONDecoder().decode([String: Translations].self, from: data)
            print("✅ Loaded \(translations.count) translations")
        } catch {
            print("⚠️ Failed to load translations.json: \(error)")
        }
    }

    func translate(_ wordId: String) -> String? {
        translations[wordId]?.value(for: currentLanguage)
    }
}
