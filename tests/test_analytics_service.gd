extends "res://tests/test_case.gd"
## Tests the live AnalyticsService autoload — including its own wiring into
## GameManager/PauseController/ResultFlowController's real signals, since
## "integrate analytics hooks into existing Foundation flows" is the whole
## point of Phase 5. Uses the real no-op backend for the API/safety tests
## (there is nothing to observe from a real backend, hence last_*/
## event_log for direct inspection — mirrors HapticsManager's testable-
## without-a-device pattern) and a small in-file stub backend to verify a
## per-game backend can be swapped in without any caller changing.

class _StubBackend:
	extends RefCounted
	var events: Array = []
	var user_properties: Array = []
	var screens: Array = []

	func _log_event(event_name: String, params: Dictionary) -> void:
		events.append([event_name, params])

	func _set_user_property(property_name: String, value) -> void:
		user_properties.append([property_name, value])

	func _screen_view(screen_name: String) -> void:
		screens.append(screen_name)


const FIXTURE_A := "res://tests/fixtures/dummy_scene_a.tscn"
const FIXTURE_B := "res://tests/fixtures/dummy_scene_b.tscn"

var _analytics: Node
var _gm: Node
var _pause: Node
var _flow: Node
var _router: Node


func setup() -> void:
	_analytics = root.get_node("AnalyticsService")
	_gm = root.get_node("GameManager")
	_pause = root.get_node("PauseController")
	_flow = root.get_node("ResultFlowController")
	_router = root.get_node("SceneRouter")

	_analytics.set_backend(load("res://addons/core/analytics/analytics_backend.gd").new())
	_analytics.last_event_name = ""
	_analytics.last_event_params = {}
	_analytics.last_user_property_name = ""
	_analytics.last_user_property_value = null
	_analytics.last_screen_name = ""

	_pause.is_paused = false
	root.get_tree().paused = false
	_router.is_loading = false
	_flow.current_payload = {}
	_gm.current_state = _gm.State.BOOT


func test_log_event_with_default_no_op_backend_does_not_crash_and_reports_success() -> void:
	var ok: bool = _analytics.log_event("test_event", {"a": 1})
	assert_true(ok)
	assert_eq(_analytics.last_event_name, "test_event")
	assert_eq(_analytics.last_event_params, {"a": 1})


func test_log_event_with_empty_name_is_rejected() -> void:
	var ok: bool = _analytics.log_event("")
	assert_false(ok)
	assert_eq(_analytics.last_event_name, "", "an empty name must not update last_event_name")


func test_log_event_default_params_is_an_empty_dictionary() -> void:
	var ok: bool = _analytics.log_event("no_params_event")
	assert_true(ok)
	assert_eq(_analytics.last_event_params, {})


func test_set_user_property_stores_name_and_value() -> void:
	var ok: bool = _analytics.set_user_property("player_level", 5)
	assert_true(ok)
	assert_eq(_analytics.last_user_property_name, "player_level")
	assert_eq(_analytics.last_user_property_value, 5)


func test_set_user_property_with_empty_name_is_rejected() -> void:
	var ok: bool = _analytics.set_user_property("", "value")
	assert_false(ok)
	assert_eq(_analytics.last_user_property_name, "")


func test_screen_view_stores_name() -> void:
	var ok: bool = _analytics.screen_view("main_menu")
	assert_true(ok)
	assert_eq(_analytics.last_screen_name, "main_menu")


func test_screen_view_with_empty_name_is_rejected() -> void:
	var ok: bool = _analytics.screen_view("")
	assert_false(ok)
	assert_eq(_analytics.last_screen_name, "")


func test_backend_is_swappable_without_changing_the_calling_api() -> void:
	var stub := _StubBackend.new()
	_analytics.set_backend(stub)

	_analytics.log_event("swap_test", {"x": 1})
	_analytics.set_user_property("swap_prop", "swap_value")
	_analytics.screen_view("swap_screen")

	assert_eq(stub.events, [["swap_test", {"x": 1}]])
	assert_eq(stub.user_properties, [["swap_prop", "swap_value"]])
	assert_eq(stub.screens, ["swap_screen"])


func test_fresh_instance_logs_app_boot_event_once_in_ready() -> void:
	# AnalyticsService logs "app_boot" exactly once, from its own _ready().
	# The live autoload singleton already did this long before any test ran
	# (and its event_log is a capped ring buffer, so relying on that first
	# entry surviving hundreds of later tests would be flaky) — spinning up
	# a second, throwaway instance of the same script instead exercises the
	# exact same _ready() logic deterministically.
	var fresh_analytics = load("res://addons/core/analytics/analytics_service.gd").new()
	root.add_child(fresh_analytics)

	assert_eq(fresh_analytics.last_event_name, "app_boot")
	assert_eq(fresh_analytics.event_log.size(), 1)
	if fresh_analytics.event_log.size() == 1:
		assert_eq(fresh_analytics.event_log[0].get("name"), "app_boot")

	fresh_analytics.queue_free()


func test_foundation_hook_state_transition_triggers_screen_view() -> void:
	_gm.transition_to(_gm.State.MAIN_MENU)
	assert_eq(_analytics.last_screen_name, "MAIN_MENU")


func test_foundation_hook_pause_and_resume_log_events() -> void:
	_pause.pause()
	assert_eq(_analytics.last_event_name, "game_paused")

	_pause.resume()
	assert_eq(_analytics.last_event_name, "game_resumed")


func test_foundation_hook_result_shown_retry_next_main_menu_log_events() -> void:
	_gm.transition_to(_gm.State.MAIN_MENU)
	_gm.transition_to(_gm.State.LOADING)
	_gm.transition_to(_gm.State.PLAYING)

	_flow.show_result({
		"outcome": "victory",
		"retry_scene_path": FIXTURE_A,
		"next_scene_path": FIXTURE_B,
		"main_menu_scene_path": FIXTURE_A,
	})
	assert_eq(_analytics.last_event_name, "result_shown")
	assert_eq(_analytics.last_event_params.get("outcome"), "victory")

	_flow.retry()
	assert_eq(_analytics.last_event_name, "retry")
	assert_eq(_analytics.last_event_params.get("scene_path"), FIXTURE_A)

	# retry() left GameManager in Loading; drive back to Playing -> Result
	# to exercise next() too.
	_gm.transition_to(_gm.State.PLAYING)
	_flow.show_result({"outcome": "failure", "next_scene_path": FIXTURE_B, "main_menu_scene_path": FIXTURE_A})
	_flow.next()
	assert_eq(_analytics.last_event_name, "next")
	assert_eq(_analytics.last_event_params.get("scene_path"), FIXTURE_B)

	_gm.transition_to(_gm.State.PLAYING)
	_flow.show_result({"outcome": "failure", "main_menu_scene_path": FIXTURE_A})
	_flow.main_menu()
	assert_eq(_analytics.last_event_name, "main_menu")
	assert_eq(_analytics.last_event_params.get("scene_path"), FIXTURE_A)
