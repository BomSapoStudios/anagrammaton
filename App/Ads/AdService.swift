import AnagrammatonCore
import Foundation

/// Shows ads. Implementations wrap an ad network SDK (AdMob next).
protocol AdProvider {
    func showInterstitial()
    /// Calls `completion(true)` once the player has earned the reward.
    func showRewarded(completion: @escaping (Bool) -> Void)
}

/// Logs instead of showing ads, and grants rewards immediately.
struct StubAdProvider: AdProvider {
    func showInterstitial() {
        print("[ads] interstitial (stub)")
    }

    func showRewarded(completion: @escaping (Bool) -> Void) {
        print("[ads] rewarded video (stub, granted immediately)")
        completion(true)
    }
}

/// The one place gameplay talks to about ads. It applies AdPolicy and
/// forwards to the provider.
final class AdService {
    static let shared = AdService()

    let policy = AdPolicy()
    var provider: AdProvider = StubAdProvider()

    private let launchedAt = Date()

    func levelCompleted() {
        policy.levelCompleted()
        let now = Date().timeIntervalSince(launchedAt)
        if policy.canShowInterstitial(now: now) {
            policy.recordInterstitial(now: now)
            provider.showInterstitial()
        }
    }

    func showRewarded(completion: @escaping (Bool) -> Void) {
        provider.showRewarded(completion: completion)
    }
}
