import SwiftUI
import UIKit

// MARK: - 数据模型

struct WordEntry: Codable, Identifiable {
    let word: String
    let display: String
    let category: String
    let image: String
    let ipa: String?

    var id: String { word + category }

    /// 加载对应的 .webp 图片（从 App Bundle 中的 categorized/ 文件夹）
    func loadImage() -> UIImage? {
        let url = image
        guard let path = Bundle.main.path(forResource: (url as NSString).deletingPathExtension,
                                          ofType: "webp",
                                          inDirectory: "categorized")
        else {
            // 尝试在 categorized/<category>/ 下找
            let components = url.split(separator: "/")
            guard components.count == 2 else { return nil }
            let dir = String(components[0])
            let file = String(components[1])
            let name = (file as NSString).deletingPathExtension
            let ext = (file as NSString).pathExtension
            guard let path = Bundle.main.path(forResource: name, ofType: ext, inDirectory: "categorized/\(dir)")
            else { return nil }
            return UIImage(contentsOfFile: path)
        }
        return UIImage(contentsOfFile: path)
    }
}

// MARK: - 分类定义

struct CategoryDef: Identifiable {
    let id: String
    let name: String
    let icon: String
    let theme: ThemeColor

    static let all: [CategoryDef] = [
        .init(id: "transportation",    name: "Vehicles",   icon: "🚁", theme: .blue),
        .init(id: "land_animals",      name: "Animals",    icon: "🐶", theme: .yellow),
        .init(id: "electronics",       name: "Gadgets",    icon: "💻", theme: .purple),
        .init(id: "clothes_accessories", name: "Clothes",  icon: "👗", theme: .pink),
        .init(id: "food_drinks",       name: "Yummy",      icon: "🍔", theme: .yellow),
        .init(id: "buildings_places",  name: "Places",     icon: "🏫", theme: .blue),
        .init(id: "daily_items",       name: "Stuff",      icon: "🛁", theme: .purple),
        .init(id: "music_art",         name: "Music & Art",icon: "🎨", theme: .pink),
        .init(id: "kitchenware",       name: "Kitchen",    icon: "🍳", theme: .yellow),
        .init(id: "occupations",       name: "Jobs",       icon: "👮", theme: .blue),
        .init(id: "sports",            name: "Sports",     icon: "⚽", theme: .green),
        .init(id: "countries_regions", name: "World",      icon: "🌍", theme: .blue),
        .init(id: "tools_hardware",    name: "Tools",      icon: "🔨", theme: .purple),
        .init(id: "toys_games",        name: "Toys",       icon: "🧸", theme: .pink),
        .init(id: "school_stationery", name: "School",     icon: "🎒", theme: .yellow),
        .init(id: "nature",            name: "Nature",     icon: "🌲", theme: .green),
        .init(id: "military_security", name: "Heroes",     icon: "🛡️", theme: .blue),
        .init(id: "events_festivals",  name: "Party",      icon: "🎈", theme: .pink),
        .init(id: "materials",         name: "Build",      icon: "🧱", theme: .purple),
        .init(id: "birds_insects",     name: "Bugs & Birds",icon: "🦋", theme: .yellow),
        .init(id: "my_body",           name: "My Body",    icon: "👀", theme: .pink),
        .init(id: "science_space",     name: "Space",      icon: "🚀", theme: .purple),
        .init(id: "outdoor_travel",    name: "Travel",     icon: "⛺", theme: .green),
        .init(id: "fantasy_myth",      name: "Magic",      icon: "🦄", theme: .pink),
        .init(id: "plants_flowers",    name: "Plants",     icon: "🌻", theme: .green),
        .init(id: "fruits_vegetables", name: "Fruits",     icon: "🍎", theme: .yellow),
        .init(id: "history_culture",   name: "History",    icon: "🏛️", theme: .purple),
        .init(id: "health_medical",    name: "Doctor",     icon: "💊", theme: .blue),
        .init(id: "ui_symbols",        name: "Signs",      icon: "➡️", theme: .purple),
        .init(id: "business_finance",  name: "Money",      icon: "💰", theme: .yellow),
        .init(id: "media_entertainment", name: "Movies",   icon: "🎬", theme: .pink),
        .init(id: "furniture",         name: "Furniture",  icon: "🛏️", theme: .blue),
        .init(id: "sea_creatures",     name: "Ocean",      icon: "🐳", theme: .blue),
        .init(id: "religion_ritual",   name: "Peace",      icon: "🕊️", theme: .purple),
        .init(id: "actions",           name: "Actions",    icon: "🏃", theme: .green),
        .init(id: "descriptions",      name: "Words",      icon: "✨", theme: .pink),
        .init(id: "numbers_math",      name: "Numbers",    icon: "🔢", theme: .blue),
        .init(id: "other",             name: "More",       icon: "📦", theme: .purple),
    ]

    static func find(by id: String) -> CategoryDef? { all.first { $0.id == id } }
}

// MARK: - 颜色主题

enum ThemeColor {
    case pink, blue, yellow, green, purple

    var gradient: [Color] {
        switch self {
        case .pink:   [Color(hex: "ffa8cd"), Color(hex: "FF85B3")]
        case .blue:   [Color(hex: "8fe0ff"), Color(hex: "60D0FF")]
        case .yellow: [Color(hex: "ffe08a"), Color(hex: "FFD15C")]
        case .green:  [Color(hex: "bdf16a"), Color(hex: "9CE32D")]
        case .purple: [Color(hex: "cebfff"), Color(hex: "B6A2FF")]
        }
    }

    var solid: Color {
        switch self {
        case .pink:   Color(hex: "FF85B3")
        case .blue:   Color(hex: "60D0FF")
        case .yellow: Color(hex: "FFD15C")
        case .green:  Color(hex: "9CE32D")
        case .purple: Color(hex: "B6A2FF")
        }
    }
}

// MARK: - Color HEX 扩展

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let scanner = Scanner(string: hex)
        var int: UInt64 = 0
        scanner.scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - 数据加载

class WordDatabase {
    static let shared = WordDatabase()
    private(set) var words: [WordEntry] = []
    private(set) var wordsByCategory: [String: [WordEntry]] = [:]

    private init() {
        load()
    }

    func load() {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json") else {
            print("⚠️ words.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            words = try JSONDecoder().decode([WordEntry].self, from: data)
            wordsByCategory = Dictionary(grouping: words) { $0.category }
            print("✅ Loaded \(words.count) words across \(wordsByCategory.count) categories")
        } catch {
            print("⚠️ Failed to load words.json: \(error)")
        }
    }

    func words(for category: String) -> [WordEntry] {
        wordsByCategory[category] ?? []
    }
}
