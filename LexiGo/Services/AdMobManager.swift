import GoogleMobileAds
import SwiftUI

@MainActor
class AdMobManager: NSObject, ObservableObject {
    static let shared = AdMobManager()

    // ⚠️ Replace with your real AdMob ad unit IDs before release
    let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"       // Test banner
    let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // Test interstitial

    @Published var isInterstitialReady = false

    private var interstitial: GADInterstitialAd?

    override private init() {
        super.init()
    }

    func loadInterstitial() {
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: interstitialAdUnitID, request: request) { ad, error in
            if let error = error {
                print("⚠️ Interstitial ad failed to load: \(error.localizedDescription)")
                Task { @MainActor in AdMobManager.shared.isInterstitialReady = false }
                return
            }
            Task { @MainActor in
                AdMobManager.shared.interstitial = ad
                AdMobManager.shared.isInterstitialReady = true
            }
        }
    }

    func showInterstitial() {
        guard let interstitial = interstitial,
              let root = rootViewController
        else { return }
        interstitial.present(fromRootViewController: root)
        self.interstitial = nil
        isInterstitialReady = false
        loadInterstitial()
    }

    private var rootViewController: UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController
        else { return nil }
        return root
    }
}
