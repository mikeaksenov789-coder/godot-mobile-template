extends "res://tests/test_case.gd"
## Tests the live ResultFlowController autoload, driving the real
## GameManager/SceneRouter singletons through it — not mocks — since the
## whole point of Result Flow is the state machine + scene routing it
## orchestrates.

const FIXTURE_A := "res://tests/fixtures/dummy_scene_a.tscn"
const FIXTURE_B := "res://tests/fixtures/dummy_scene_b.tscn"
const FIXTURE_MISSING := "res://tests/fixtures/does_not_exist.tscn"

var _flow: Node
var _gm: Node
var _router: Node


func setup() -> void:
	_flow = root.get_node("ResultFlowController")
	_gm = root.get_node("GameManager")
	_router = root.get_node("SceneRouter")

	_router.is_loading = false
	_flow.current_payload = {}

	# Drive GameManager to Playing — the only state show_result() may act from.
	_gm.current_state = _gm.State.BOOT
	_gm.transition_to(_gm.State.MAIN_MENU)
	_gm.transition_to(_gm.State.LOADING)
	_gm.transition_to(_gm.State.PLAYING)


func test_victory_result_flow() -> void:
	var shown: Array = []
	var callback := func(payload): shown.append(payload)
	_flow.result_shown.connect(callback)

	var ok: bool = _flow.show_result({"outcome": "victory", "retry_scene_path": FIXTURE_A})
	_flow.result_shown.disconnect(callback)

	assert_true(ok)
	assert_eq(_gm.current_state, _gm.State.RESULT)
	assert_eq(shown.size(), 1)
	if shown.size() == 1:
		assert_eq(shown[0].get("outcome"), "victory")


func test_failure_result_flow() -> void:
	var ok: bool = _flow.show_result({"outcome": "failure", "main_menu_scene_path": FIXTURE_A})
	assert_true(ok)
	assert_eq(_gm.current_state, _gm.State.RESULT)
	assert_eq(_flow.current_payload.get("outcome"), "failure")


func test_retry_transitions_to_loading_and_routes_scene() -> void:
	_flow.show_result({"outcome": "failure", "retry_scene_path": FIXTURE_A})

	var requested: Array = []
	var callback := func(path): requested.append(path)
	_flow.retry_requested.connect(callback)
	var ok: bool = _flow.retry()
	_flow.retry_requested.disconnect(callback)

	assert_true(ok)
	assert_eq(_gm.current_state, _gm.State.LOADING)
	assert_eq(requested, [FIXTURE_A])
	assert_not_null(_router.get_current_scene())
	if _router.get_current_scene() != null:
		assert_eq(_router.get_current_scene().name, "DummySceneA")


func test_next_transitions_to_loading_and_routes_scene() -> void:
	_flow.show_result({"outcome": "victory", "next_scene_path": FIXTURE_B})
	var ok: bool = _flow.next()
	assert_true(ok)
	assert_eq(_gm.current_state, _gm.State.LOADING)
	assert_not_null(_router.get_current_scene())
	if _router.get_current_scene() != null:
		assert_eq(_router.get_current_scene().name, "DummySceneB")


func test_main_menu_transitions_correctly() -> void:
	_flow.show_result({"outcome": "failure", "main_menu_scene_path": FIXTURE_A})
	var ok: bool = _flow.main_menu()
	assert_true(ok)
	assert_eq(_gm.current_state, _gm.State.MAIN_MENU)


func test_retry_without_retry_scene_path_is_rejected() -> void:
	_flow.show_result({"outcome": "victory"})  # no retry_scene_path provided
	var ok: bool = _flow.retry()
	assert_false(ok)
	assert_eq(_gm.current_state, _gm.State.RESULT, "state must not change on a rejected retry")


func test_next_without_next_scene_path_is_rejected() -> void:
	_flow.show_result({"outcome": "victory", "retry_scene_path": FIXTURE_A})  # no next_scene_path
	var ok: bool = _flow.next()
	assert_false(ok)
	assert_eq(_gm.current_state, _gm.State.RESULT)


func test_actions_rejected_when_not_in_result_state() -> void:
	# setup() leaves GameManager in Playing, not Result.
	assert_false(_flow.retry())
	assert_false(_flow.next())
	assert_false(_flow.main_menu())
	assert_eq(_gm.current_state, _gm.State.PLAYING)


func test_invalid_payload_missing_outcome_is_rejected() -> void:
	var rejections: Array = []
	var callback := func(reason): rejections.append(reason)
	_flow.invalid_payload_rejected.connect(callback)
	var ok: bool = _flow.show_result({"retry_scene_path": FIXTURE_A})
	_flow.invalid_payload_rejected.disconnect(callback)

	assert_false(ok)
	assert_eq(_gm.current_state, _gm.State.PLAYING, "an invalid payload must not move the state machine")
	assert_eq(rejections.size(), 1)


func test_invalid_payload_unknown_outcome_is_rejected() -> void:
	var ok: bool = _flow.show_result({"outcome": "draw"})
	assert_false(ok)
	assert_eq(_gm.current_state, _gm.State.PLAYING)


func test_invalid_payload_empty_dictionary_does_not_crash() -> void:
	var ok: bool = _flow.show_result({})
	assert_false(ok)
	assert_eq(_gm.current_state, _gm.State.PLAYING)


func test_retry_with_missing_scene_reports_routing_failure() -> void:
	_flow.show_result({"outcome": "failure", "retry_scene_path": FIXTURE_MISSING})
	var ok: bool = _flow.retry()
	assert_false(ok, "routing to a nonexistent scene must be reported as a failure")
	assert_eq(_gm.current_state, _gm.State.LOADING,
		"Foundation can't know the content is broken until SceneRouter tries, so the state machine still left Result")


func test_state_transitions_around_result_full_cycle() -> void:
	assert_eq(_gm.current_state, _gm.State.PLAYING)
	_flow.show_result({
		"outcome": "victory",
		"retry_scene_path": FIXTURE_A,
		"main_menu_scene_path": FIXTURE_B,
	})
	assert_eq(_gm.current_state, _gm.State.RESULT)

	_flow.main_menu()
	assert_eq(_gm.current_state, _gm.State.MAIN_MENU)
