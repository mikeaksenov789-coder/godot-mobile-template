extends Node
## Foundation rewarded-ads gateway. Rewarded ads only (Phase 5 scope — no
## interstitial/banner). Ships with the plain no-op `ads_backend.gd` by
## default: no real SDK, no credentials, `is_rewarded_ready()` always false
## until a real (or mock) backend is swapped in via `set_backend()`.
## Gameplay reads readiness before offering a reward and must never assume
## an ad is available — every rejection path here is a graceful failure
## signal, never a crash or a thrown error.
##
## Per-game configuration hooks: `configure_placements()` (which placement
## ids are valid — an empty set means "accept any non-empty id", so a game
## that hasn't configured placements yet still works during development),
## `set_frequency_cap()` (minimum seconds between successful shows of the
## same placement), and `set_backend()` (real SDK vs mock vs no-op).

signal rewarded_ad_completed(placement_id: String)
signal rewarded_ad_failed(placement_id: String, reason: String)

var placements: Dictionary = {}  # placement_id -> true; empty = accept any id
var frequency_cap_seconds: float = 0.0  # 0 = no cap

var _backend
var _last_shown_at_ms: Dictionary = {}


func _ready() -> void:
	_backend = load("res://addons/core/ads/ads_backend.gd").new()


func set_backend(backend) -> void:
	_backend = backend


func configure_placements(placement_ids: Array) -> void:
	placements.clear()
	for placement_id in placement_ids:
		placements[placement_id] = true


func set_frequency_cap(seconds: float) -> void:
	frequency_cap_seconds = maxf(seconds, 0.0)


func is_rewarded_ready(placement_id: String) -> bool:
	if not _is_valid_placement(placement_id):
		return false
	if _is_frequency_capped(placement_id):
		return false
	return _backend._is_rewarded_ready(placement_id)


## Never throws. Returns false immediately (and emits rewarded_ad_failed)
## for an invalid placement, an active frequency cap, or a backend that
## reports not-ready; otherwise delegates to the backend and returns true.
## The actual outcome always arrives via rewarded_ad_completed/
## rewarded_ad_failed, since a real ad SDK is inherently asynchronous.
func show_rewarded(placement_id: String) -> bool:
	if not _is_valid_placement(placement_id):
		_fail(placement_id, "unknown or unconfigured placement id")
		return false
	if _is_frequency_capped(placement_id):
		_fail(placement_id, "frequency cap active")
		return false
	if not _backend._is_rewarded_ready(placement_id):
		_fail(placement_id, "ad not ready")
		return false

	_last_shown_at_ms[placement_id] = Time.get_ticks_msec()
	_backend._show_rewarded(placement_id, _on_backend_success, _on_backend_failure)
	return true


func _on_backend_success(placement_id: String) -> void:
	rewarded_ad_completed.emit(placement_id)


func _on_backend_failure(placement_id: String, reason: String) -> void:
	rewarded_ad_failed.emit(placement_id, reason)


func _fail(placement_id: String, reason: String) -> void:
	rewarded_ad_failed.emit(placement_id, reason)


func _is_valid_placement(placement_id: String) -> bool:
	if placement_id == "":
		return false
	if placements.is_empty():
		return true
	return placements.has(placement_id)


func _is_frequency_capped(placement_id: String) -> bool:
	if frequency_cap_seconds <= 0.0:
		return false
	if not _last_shown_at_ms.has(placement_id):
		return false
	var elapsed_sec: float = (Time.get_ticks_msec() - _last_shown_at_ms[placement_id]) / 1000.0
	return elapsed_sec < frequency_cap_seconds
