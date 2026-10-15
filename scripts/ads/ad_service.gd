extends Node
## Autoload ("Ads") that gameplay talks to. It applies AdPolicy and forwards to
## a provider. Until the AdMob plugin is added, the provider is a stub that
## logs and grants rewards immediately.

signal reward_earned(kind: String)

const AdPolicy = preload("res://scripts/ads/ad_policy.gd")

var policy := AdPolicy.new()


func level_completed() -> void:
	policy.on_level_complete()
	var now := Time.get_ticks_msec() / 1000.0
	if policy.can_show_interstitial(now):
		policy.record_interstitial(now)
		_show_interstitial()


## Shows a rewarded video; `reward_earned` fires with `kind` once watched.
func show_rewarded(kind: String) -> void:
	print("[ads] rewarded video for '%s' (stub, granted immediately)" % kind)
	reward_earned.emit(kind)


func _show_interstitial() -> void:
	print("[ads] interstitial (stub)")
