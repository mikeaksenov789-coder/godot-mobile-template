extends "res://addons/core/ads/ads_backend.gd"
## Development/testing backend: simulates rewarded-ad readiness and outcome
## without any real SDK. Not wired in by default — `AdsService` starts with
## the plain no-op `ads_backend.gd`; a game (or a test) opts into this one
## explicitly via `AdsService.set_backend(MockAdsBackend.new())` to exercise
## the success/failure paths end-to-end during development. `simulate_ready`
## defaults to false so a freshly created mock is just as "nothing to show"
## as the real no-op default until deliberately configured otherwise.

var simulate_ready: bool = false
var simulate_success: bool = true
var simulate_failure_reason: String = "simulated failure"


func _is_rewarded_ready(_placement_id: String) -> bool:
	return simulate_ready


func _show_rewarded(placement_id: String, on_success: Callable, on_failure: Callable) -> void:
	if not simulate_ready:
		on_failure.call(placement_id, "ad not ready")
		return
	if simulate_success:
		on_success.call(placement_id)
	else:
		on_failure.call(placement_id, simulate_failure_reason)
