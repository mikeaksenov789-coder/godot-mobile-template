extends "res://tests/test_case.gd"
## Tests VirtualJoystick's drag-tracking logic directly — _gui_input() is
## called like any other method, no real Viewport/GUI focus routing
## needed to exercise it headlessly.

var _joystick


func setup() -> void:
	_joystick = load("res://addons/core/input/virtual_joystick.gd").new()
	_joystick.size = Vector2(160, 160)
	_joystick.max_radius = 80.0
	_joystick.dead_zone = 0.1
	_joystick.recompute_center()  # normally done by _ready(), which we skip here


func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _drag(index: int, position: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event


func _collect_input() -> Array:
	var received: Array = []
	_joystick.joystick_input.connect(func(direction, strength): received.append([direction, strength]))
	return received


func test_press_at_center_emits_zero_strength_within_dead_zone() -> void:
	var received := _collect_input()
	_joystick._gui_input(_touch(0, Vector2(80, 80), true))  # exactly the center
	assert_eq(received.size(), 1)
	if received.size() == 1:
		assert_eq(received[0][0], Vector2.ZERO)
		assert_eq(received[0][1], 0.0)


func test_drag_to_edge_emits_full_strength_in_direction() -> void:
	var received := _collect_input()
	_joystick._gui_input(_touch(0, Vector2(80, 80), true))
	_joystick._gui_input(_drag(0, Vector2(160, 80)))  # full right, at max_radius

	assert_eq(received.size(), 2)
	if received.size() == 2:
		assert_true(received[1][0].is_equal_approx(Vector2(1, 0)))
		assert_true(is_equal_approx(received[1][1], 1.0))


func test_drag_beyond_radius_clamps_strength_to_one() -> void:
	var received := _collect_input()
	_joystick._gui_input(_touch(0, Vector2(80, 80), true))
	_joystick._gui_input(_drag(0, Vector2(500, 80)))  # way past max_radius

	assert_eq(received.size(), 2)
	if received.size() == 2:
		assert_true(is_equal_approx(received[1][1], 1.0), "strength must clamp at 1.0, not exceed it")


func test_release_emits_zero_vector() -> void:
	var received := _collect_input()
	_joystick._gui_input(_touch(0, Vector2(160, 80), true))
	_joystick._gui_input(_touch(0, Vector2(160, 80), false))

	assert_eq(received.size(), 2)
	if received.size() == 2:
		assert_eq(received[1][0], Vector2.ZERO)
		assert_eq(received[1][1], 0.0)


func test_second_finger_is_ignored_while_first_is_active() -> void:
	var received := _collect_input()
	_joystick._gui_input(_touch(0, Vector2(80, 80), true))
	_joystick._gui_input(_touch(1, Vector2(160, 160), true))  # second finger, different index
	_joystick._gui_input(_drag(1, Vector2(0, 0)))  # should be ignored — not the active touch

	assert_eq(received.size(), 1, "only the first touch should drive the joystick")


func test_drag_for_inactive_index_is_ignored() -> void:
	var received := _collect_input()
	_joystick._gui_input(_drag(3, Vector2(50, 50)))  # no matching touch-down at all
	assert_eq(received.size(), 0)
