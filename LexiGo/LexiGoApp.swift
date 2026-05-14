import SwiftUI

@main
struct LexiGoApp: App {
    // 在 App 启动时预加载数据
    init() {
        _ = WordDatabase.shared
        _ = TTSManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
