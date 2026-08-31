extends "res://tests/test_case.gd"
## Tests InputProfile.resolve_swipe_action() directly — the InputManager
## suite covers it indirectly through action_triggered, this suite covers
## the mapping logic itself in isolation, including edge cases.

var _profile


func setup() -> void:
	_profile = load("res://addons/core/input/input_profile.gd").new()
	_profile.swipe_up_action = "up"
	_profile.swipe_down_action = "down"
	_profile.swipe_left_action = "left"
	_profile.swipe_right_action = "right"


func test_resolves_dominant_horizontal_axis() -> void:
	assert_eq(_profile.resolve_swipe_action(Vector2(1, 0.2)), "right")
	assert_eq(_profile.resolve_swipe_action(Vector2(-1, 0.2)), "left")


func test_resolves_dominant_vertical_axis() -> void:
	assert_eq(_profile.resolve_swipe_action(Vector2(0.2, 1)), "down")
	assert_eq(_profile.resolve_swipe_action(Vector2(0.2, -1)), "up")


func test_zero_vector_resolves_to_empty_string() -> void:
	assert_eq(_profile.resolve_swipe_action(Vector2.ZERO), "")


func test_unmapped_action_field_is_empty_by_default() -> void:
	var blank = load("res://addons/core/input/input_profile.gd").new()
	assert_eq(blank.resolve_swipe_action(Vector2(1, 0)), "")
	assert_eq(blank.tap_action, "")
	assert_eq(blank.hold_action, "")
