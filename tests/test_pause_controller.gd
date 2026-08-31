extends "res://tests/test_case.gd"
## Tests the live PauseController autoload.

var _pause: Node


func setup() -> void:
	_pause = root.get_node("PauseController")
	_pause.is_paused = false
	root.get_tree().paused = false


func test_pause_sets_state_and_tree_flag() -> void:
	var ok: bool = _pause.pause()
	assert_true(ok)
	assert_true(_pause.is_paused)
	assert_true(root.get_tree().paused)


func test_resume_clears_state_and_tree_flag() -> void:
	_pause.pause()
	var ok: bool = _pause.resume()
	assert_true(ok)
	assert_false(_pause.is_paused)
	assert_false(root.get_tree().paused)


func test_double_pause_is_a_no_op() -> void:
	_pause.pause()
	var second_call: bool = _pause.pause()
	assert_false(second_call, "pausing an already-paused controller should report no-op")
	assert_true(_pause.is_paused, "state must remain paused")


func test_double_resume_is_a_no_op() -> void:
	var resume_while_not_paused: bool = _pause.resume()
	assert_false(resume_while_not_paused, "resuming an already-running controller should report no-op")


func test_toggle_flips_state() -> void:
	_pause.toggle()
	assert_true(_pause.is_paused)
	_pause.toggle()
	assert_false(_pause.is_paused)


func test_paused_and_resumed_signals_fire_exactly_once() -> void:
	var pause_count := [0]
	var resume_count := [0]
	_pause.paused.connect(func(): pause_count[0] += 1)
	_pause.resumed.connect(func(): resume_count[0] += 1)

	_pause.pause()
	_pause.pause()  # rejected, must not fire again
	_pause.resume()
	_pause.resume()  # rejected, must not fire again

	assert_eq(pause_count[0], 1)
	assert_eq(resume_count[0], 1)
