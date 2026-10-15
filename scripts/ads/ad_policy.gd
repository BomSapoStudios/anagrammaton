extends RefCounted
## When ads may show. Kept separate from the provider so the rules are
## testable and stay the same whichever ad network is plugged in.

const MIN_LEVELS_BETWEEN := 3
const MIN_SECONDS_BETWEEN := 180.0
const MAX_CONTINUES_PER_LEVEL := 1
const BANNER_SCREENS := ["menu", "level_map"]

var remove_ads := false
## 1 on the player's first launch. Saving it is future work.
var session_count := 1

var _levels_since_interstitial := 0
var _last_interstitial_at := -INF


func on_level_complete() -> void:
	_levels_since_interstitial += 1


## Interstitials need both enough levels and enough time since the last one,
## never show in the first session, and stop once ads are removed.
func can_show_interstitial(now_seconds: float) -> bool:
	if remove_ads or session_count <= 1:
		return false
	return _levels_since_interstitial >= MIN_LEVELS_BETWEEN \
		and now_seconds - _last_interstitial_at >= MIN_SECONDS_BETWEEN


func record_interstitial(now_seconds: float) -> void:
	_levels_since_interstitial = 0
	_last_interstitial_at = now_seconds


## Rewarded continues are opt-in, capped per level, and never allowed on
## ranked (daily or leaderboard) levels so ads cannot buy rank.
func can_offer_continue(continues_used: int, ranked: bool) -> bool:
	return not ranked and continues_used < MAX_CONTINUES_PER_LEVEL


## Rewarded ads stay available after "remove ads" because players choose them.
func can_offer_rewarded(ranked: bool) -> bool:
	return not ranked


func can_show_banner(screen: String) -> bool:
	return not remove_ads and screen in BANNER_SCREENS
