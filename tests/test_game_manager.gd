extends "res://tests/test_case.gd"
## Tests the live GameManager autoload — the actual singleton other scripts
## use, not a mock — resetting its state before each test.

var _gm: Node


func setup() -> void:
	_gm = root.get_node("GameManager")
	_gm.current_state = _gm.State.BOOT


func test_initial_state_is_boot() -> void:
	assert_eq(_gm.current_state, _gm.State.BOOT, "a fresh GameManager should start in BOOT")


func test_valid_chain_boot_to_result() -> void:
	assert_true(_gm.transition_to(_gm.State.MAIN_MENU), "Boot -> MainMenu should be allowed")
	assert_eq(_gm.current_state, _gm.State.MAIN_MENU)

	assert_true(_gm.transition_to(_gm.State.LOADING), "MainMenu -> Loading should be allowed")
	assert_true(_gm.transition_to(_gm.State.PLAYING), "Loading -> Playing should be allowed")
	assert_true(_gm.transition_to(_gm.State.PAUSED), "Playing -> Paused should be allowed")
	assert_true(_gm.transition_to(_gm.State.PLAYING), "Paused -> Playing should be allowed")
	assert_true(_gm.transition_to(_gm.State.RESULT), "Playing -> Result should be allowed")
	assert_eq(_gm.current_state, _gm.State.RESULT)


func test_invalid_transition_is_rejected() -> void:
	assert_false(_gm.transition_to(_gm.State.PLAYING), "Boot -> Playing must be rejected")
	assert_eq(_gm.current_state, _gm.State.BOOT, "state must not change on a rejected transition")


func test_result_allows_only_loading_and_main_menu() -> void:
	# As of Phase 3 (Result Flow), Result -> Loading (Retry/Next) and
	# Result -> MainMenu are valid; nothing else is. This test superseded
	# Phase 1's "Result is a dead end" test, which explicitly documented
	# that Phase 3 would add exactly these edges.
	_gm.transition_to(_gm.State.MAIN_MENU)
	_gm.transition_to(_gm.State.LOADING)
	_gm.transition_to(_gm.State.PLAYING)
	_gm.transition_to(_gm.State.RESULT)

	assert_false(_gm.transition_to(_gm.State.PLAYING), "Result -> Playing directly must be rejected")
	assert_false(_gm.transition_to(_gm.State.PAUSED), "Result -> Paused must be rejected")
	assert_false(_gm.transition_to(_gm.State.BOOT), "Result -> Boot must be rejected")
	assert_eq(_gm.current_state, _gm.State.RESULT, "none of the rejected calls above may have moved the state")

	assert_true(_gm.transition_to(_gm.State.MAIN_MENU), "Result -> MainMenu should be allowed")


func test_state_changed_signal_emits_with_correct_args() -> void:
	var received: Array = []
	var callback := func(previous_state, new_state): received.append([previous_state, new_state])
	_gm.state_changed.connect(callback)
	_gm.transition_to(_gm.State.MAIN_MENU)
	_gm.state_changed.disconnect(callback)

	assert_eq(received.size(), 1, "state_changed should fire exactly once per successful transition")
	if received.size() == 1:
		assert_eq(received[0][0], _gm.State.BOOT)
		assert_eq(received[0][1], _gm.State.MAIN_MENU)


func test_state_changed_does_not_emit_on_rejected_transition() -> void:
	var emit_count := 0
	var callback := func(_previous_state, _new_state): emit_count += 1
	_gm.state_changed.connect(callback)
	_gm.transition_to(_gm.State.PLAYING)  # invalid from BOOT
	_gm.state_changed.disconnect(callback)

	assert_eq(emit_count, 0, "a rejected transition must not emit state_changed")
