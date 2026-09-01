extends RefCounted
## Base Ads backend contract — the true no-op default. `AdsService` starts
## with an instance of exactly this file: no ad is ever "ready", and a show
## request always reports a graceful failure, never a crash and never a
## real ad SDK call. A per-game backend overrides both methods (`extends
## "res://addons/core/ads/ads_backend.gd"`, no `class_name` — see
## docs/ARCHITECTURE.md) and is swapped in via `AdsService.set_backend()`.
##
## `mock_ads_backend.gd` in this same directory is a separate, opt-in
## backend for local development/testing that can simulate readiness and
## outcomes — it is not what ships as the default.


func _is_rewarded_ready(_placement_id: String) -> bool:
	return false


func _show_rewarded(placement_id: String, _on_success: Callable, on_failure: Callable) -> void:
	on_failure.call(placement_id, "no ad backend configured")
