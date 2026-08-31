extends "res://tests/test_case.gd"
## Tests SafeArea.compute_insets() — the pure inset-math half of the
## script. A headless CI runner never sees a real notch, so this is
## exercised with synthetic Rect2/Vector2 values rather than the actual
## DisplayServer call.

var _safe_area


func setup() -> void:
	_safe_area = load("res://addons/core/hud/safe_area.gd").new()


func test_full_screen_safe_area_produces_zero_insets() -> void:
	var screen_size := Vector2(1080, 2340)
	var safe_area := Rect2(Vector2.ZERO, screen_size)
	var insets: Dictionary = _safe_area.compute_insets(safe_area, screen_size)

	assert_eq(insets["left"], 0.0)
	assert_eq(insets["top"], 0.0)
	assert_eq(insets["right"], 0.0)
	assert_eq(insets["bottom"], 0.0)


func test_top_notch_produces_top_inset_only() -> void:
	var screen_size := Vector2(1080, 2340)
	var safe_area := Rect2(Vector2(0, 100), Vector2(1080, 2240))
	var insets: Dictionary = _safe_area.compute_insets(safe_area, screen_size)

	assert_eq(insets["top"], 100.0)
	assert_eq(insets["left"], 0.0)
	assert_eq(insets["right"], 0.0)
	assert_eq(insets["bottom"], 0.0)


func test_notch_and_gesture_bar_produce_top_and_bottom_insets() -> void:
	var screen_size := Vector2(1080, 2340)
	var safe_area := Rect2(Vector2(0, 80), Vector2(1080, 2200))  # 80 top, 60 bottom
	var insets: Dictionary = _safe_area.compute_insets(safe_area, screen_size)

	assert_eq(insets["top"], 80.0)
	assert_eq(insets["bottom"], 60.0)


func test_zero_screen_size_returns_zero_insets_without_error() -> void:
	var insets: Dictionary = _safe_area.compute_insets(Rect2(), Vector2.ZERO)
	assert_eq(insets["left"], 0.0)
	assert_eq(insets["top"], 0.0)
	assert_eq(insets["right"], 0.0)
	assert_eq(insets["bottom"], 0.0)
