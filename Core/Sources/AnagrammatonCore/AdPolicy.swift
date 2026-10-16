/// When ads may show. Kept separate from the ad provider so the rules are
/// testable and stay the same whichever ad network is plugged in.
public final class AdPolicy {
    public static let minLevelsBetween = 3
    public static let minSecondsBetween = 180.0
    public static let maxContinuesPerLevel = 1
    public static let bannerScreens: Set<String> = ["menu", "level_map"]

    public var removeAds = false
    /// 1 on the player's first launch. Saving it is future work.
    public var sessionCount = 1

    private var levelsSinceInterstitial = 0
    private var lastInterstitialAt = -Double.infinity

    public init() {}

    public func levelCompleted() {
        levelsSinceInterstitial += 1
    }

    /// Interstitials need both enough levels and enough time since the last
    /// one, never show in the first session, and stop once ads are removed.
    public func canShowInterstitial(now: Double) -> Bool {
        if removeAds || sessionCount <= 1 {
            return false
        }
        return levelsSinceInterstitial >= Self.minLevelsBetween
            && now - lastInterstitialAt >= Self.minSecondsBetween
    }

    public func recordInterstitial(now: Double) {
        levelsSinceInterstitial = 0
        lastInterstitialAt = now
    }

    /// Rewarded continues are opt-in, capped per level, and never allowed on
    /// ranked (daily or leaderboard) levels so ads cannot buy rank.
    public func canOfferContinue(continuesUsed: Int, ranked: Bool) -> Bool {
        !ranked && continuesUsed < Self.maxContinuesPerLevel
    }

    /// Rewarded ads stay available after "remove ads" because players choose
    /// them.
    public func canOfferRewarded(ranked: Bool) -> Bool {
        !ranked
    }

    public func canShowBanner(on screen: String) -> Bool {
        !removeAds && Self.bannerScreens.contains(screen)
    }
}
