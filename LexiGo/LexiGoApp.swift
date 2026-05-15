import SwiftUI
import GoogleMobileAds

@main
struct LexiGoApp: App {
    init() {
        _ = WordDatabase.shared
        _ = TTSManager.shared
        GADMobileAds.sharedInstance().start()
        AdMobManager.shared.loadInterstitial()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
