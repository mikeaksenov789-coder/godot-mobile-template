extends "res://tests/test_case.gd"
## Tests the live AdsService autoload. Uses the real no-op backend
## (ads_backend.gd) for the default-behavior/safety tests, and swaps in
## mock_ads_backend.gd (never the wired-in default) to exercise the
## success/failure/frequency-cap paths deterministically, without any real
## ad SDK or network call.

var _ads: Node


func setup() -> void:
	_ads = root.get_node("AdsService")
	_ads.set_backend(load("res://addons/core/ads/ads_backend.gd").new())
	_ads.placements = {}
	_ads.frequency_cap_seconds = 0.0
	_ads._last_shown_at_ms = {}


func test_is_rewarded_ready_is_false_by_default() -> void:
	assert_false(_ads.is_rewarded_ready("rewarded_main"))


func test_show_rewarded_with_default_backend_fails_gracefully_without_crashing() -> void:
	var failures: Array = []
	var callback := func(placement_id, reason): failures.append([placement_id, reason])
	_ads.rewarded_ad_failed.connect(callback)

	var ok: bool = _ads.show_rewarded("rewarded_main")

	_ads.rewarded_ad_failed.disconnect(callback)
	assert_false(ok)
	assert_eq(failures.size(), 1)
	if failures.size() == 1:
		assert_eq(failures[0][0], "rewarded_main")


func test_show_rewarded_with_empty_placement_id_fails_gracefully() -> void:
	var ok: bool = _ads.show_rewarded("")
	assert_false(ok)


func test_rewarded_success_callback_fires_through_mock_backend() -> void:
	var mock = load("res://addons/core/ads/mock_ads_backend.gd").new()
	mock.simulate_ready = true
	mock.simulate_success = true
	_ads.set_backend(mock)

	var completions: Array = []
	var callback := func(placement_id): completions.append(placement_id)
	_ads.rewarded_ad_completed.connect(callback)

	assert_true(_ads.is_rewarded_ready("rewarded_main"))
	var ok: bool = _ads.show_rewarded("rewarded_main")

	_ads.rewarded_ad_completed.disconnect(callback)
	assert_true(ok)
	assert_eq(completions, ["rewarded_main"])


func test_rewarded_failure_callback_fires_through_mock_backend() -> void:
	var mock = load("res://addons/core/ads/mock_ads_backend.gd").new()
	mock.simulate_ready = true
	mock.simulate_success = false
	mock.simulate_failure_reason = "no fill"
	_ads.set_backend(mock)

	var failures: Array = []
	var callback := func(placement_id, reason): failures.append([placement_id, reason])
	_ads.rewarded_ad_failed.connect(callback)

	var ok: bool = _ads.show_rewarded("rewarded_main")

	_ads.rewarded_ad_failed.disconnect(callback)
	assert_true(ok, "show_rewarded reports the request was dispatched to the backend, independent of its outcome")
	assert_eq(failures, [["rewarded_main", "no fill"]])


func test_frequency_cap_blocks_a_second_show_within_the_window() -> void:
	var mock = load("res://addons/core/ads/mock_ads_backend.gd").new()
	mock.simulate_ready = true
	mock.simulate_success = true
	_ads.set_backend(mock)
	_ads.set_frequency_cap(60.0)

	assert_true(_ads.show_rewarded("rewarded_main"), "first show should go through")

	var failures: Array = []
	var callback := func(placement_id, reason): failures.append([placement_id, reason])
	_ads.rewarded_ad_failed.connect(callback)
	var ok: bool = _ads.show_rewarded("rewarded_main")
	_ads.rewarded_ad_failed.disconnect(callback)

	assert_false(ok, "a second show within the frequency cap window must be rejected")
	assert_false(_ads.is_rewarded_ready("rewarded_main"), "is_rewarded_ready should also reflect the active cap")
	assert_eq(failures.size(), 1)
	if failures.size() == 1:
		assert_true(failures[0][1].findn("frequency") != -1, "the failure reason should mention the frequency cap")


func test_frequency_cap_allows_a_show_again_once_the_window_has_elapsed() -> void:
	var mock = load("res://addons/core/ads/mock_ads_backend.gd").new()
	mock.simulate_ready = true
	mock.simulate_success = true
	_ads.set_backend(mock)
	_ads.set_frequency_cap(30.0)

	_ads.show_rewarded("rewarded_main")
	# Simulate 31 elapsed seconds without a real sleep, matching this
	# codebase's existing pattern of poking tracked-time state directly
	# rather than waiting in real time (see InputManager's advance_time()).
	_ads._last_shown_at_ms["rewarded_main"] = Time.get_ticks_msec() - 31000

	assert_true(_ads.is_rewarded_ready("rewarded_main"))
	assert_true(_ads.show_rewarded("rewarded_main"))


func test_unconfigured_placement_is_rejected_once_placements_are_configured() -> void:
	_ads.configure_placements(["rewarded_main", "rewarded_bonus"])
	var mock = load("res://addons/core/ads/mock_ads_backend.gd").new()
	mock.simulate_ready = true
	_ads.set_backend(mock)

	assert_true(_ads.is_rewarded_ready("rewarded_main"))
	assert_false(_ads.is_rewarded_ready("unknown_placement"))

	var ok: bool = _ads.show_rewarded("unknown_placement")
	assert_false(ok)


func test_empty_placements_dictionary_accepts_any_non_empty_id() -> void:
	# Dev-friendly default: a game that hasn't called configure_placements()
	# yet isn't blocked from testing show_rewarded() end-to-end.
	assert_eq(_ads.placements, {}, "setup() should leave placements unconfigured for this test")
	var mock = load("res://addons/core/ads/mock_ads_backend.gd").new()
	mock.simulate_ready = true
	_ads.set_backend(mock)

	assert_true(_ads.is_rewarded_ready("any_placement_id_at_all"))


func test_backend_is_swappable_without_changing_the_calling_api() -> void:
	var mock = load("res://addons/core/ads/mock_ads_backend.gd").new()
	mock.simulate_ready = true
	_ads.set_backend(mock)
	assert_true(_ads.is_rewarded_ready("rewarded_main"))

	_ads.set_backend(load("res://addons/core/ads/ads_backend.gd").new())
	assert_false(_ads.is_rewarded_ready("rewarded_main"), "swapping back to the no-op backend must take effect immediately")
