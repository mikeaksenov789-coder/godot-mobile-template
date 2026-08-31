extends "res://tests/test_case.gd"
## Tests the live InputManager autoload. Feeds synthetic
## InputEventScreenTouch/Drag events through feed_touch_event() and drives
## time with advance_time() — the same entry points a test uses are the
## same ones _input()/_process() call in real usage, so no real touch
## injection is needed.

const DEFAULT_PROFILE_PATH := "res://addons/core/input/default_input_profile.tres"

var _im: Node


func setup() -> void:
	_im = root.get_node("InputManager")
	_im._touches = {}
	_im._pinch_initial_distance = -1.0
	_im.profile = load(DEFAULT_PROFILE_PATH)


func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _drag(index: int, position: Vector2, relative: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	return event


func _collect(sig: Signal) -> Array:
	var received: Array = []
	sig.connect(func(a1=null, a2=null): received.append([a1, a2]))
	return received


func test_tap_gesture_fires_on_quick_short_release() -> void:
	var taps := _collect(_im.gesture_tap)
	var actions := _collect(_im.action_triggered)

	_im.feed_touch_event(_touch(0, Vector2(100, 100), true))
	_im.advance_time(0.05)
	_im.feed_touch_event(_touch(0, Vector2(100, 100), false))

	assert_eq(taps.size(), 1, "a quick, still release should fire exactly one tap")
	if taps.size() == 1:
		assert_eq(taps[0][0], Vector2(100, 100))
	assert_eq(actions.size(), 1, "the default profile maps tap -> primary_action")
	if actions.size() == 1:
		assert_eq(actions[0][0], "primary_action")


func test_hold_gesture_fires_after_threshold_without_movement() -> void:
	var holds := _collect(_im.gesture_hold)
	var taps := _collect(_im.gesture_tap)

	_im.feed_touch_event(_touch(0, Vector2(50, 50), true))
	_im.advance_time(_im.hold_duration + 0.01)
	assert_eq(holds.size(), 1, "holding past hold_duration without moving should fire gesture_hold")

	_im.feed_touch_event(_touch(0, Vector2(50, 50), false))
	assert_eq(taps.size(), 0, "releasing after a hold already fired must not also fire a tap")


func test_drag_gesture_fires_on_movement() -> void:
	var drags := _collect(_im.gesture_drag)

	_im.feed_touch_event(_touch(0, Vector2(0, 0), true))
	_im.feed_touch_event(_drag(0, Vector2(10, 5), Vector2(10, 5)))

	assert_eq(drags.size(), 1)
	if drags.size() == 1:
		assert_eq(drags[0][0], Vector2(10, 5))
		assert_eq(drags[0][1], Vector2(10, 5))


func test_swipe_gesture_fires_on_fast_long_release() -> void:
	var swipes := _collect(_im.gesture_swipe)
	var actions := _collect(_im.action_triggered)

	_im.feed_touch_event(_touch(0, Vector2(0, 0), true))
	_im.feed_touch_event(_drag(0, Vector2(200, 0), Vector2(200, 0)))
	_im.advance_time(0.1)
	_im.feed_touch_event(_touch(0, Vector2(200, 0), false))

	assert_eq(swipes.size(), 1, "a fast, long, straight drag-release should fire exactly one swipe")
	if swipes.size() == 1:
		assert_true(swipes[0][0].is_equal_approx(Vector2(1, 0)), "swipe direction should point right")
	assert_true(actions.any(func(a): return a[0] == "swipe_right"),
		"the default profile maps a rightward swipe -> swipe_right")


func test_pinch_gesture_fires_with_two_touches() -> void:
	var pinches := _collect(_im.gesture_pinch)

	_im.feed_touch_event(_touch(0, Vector2(0, 0), true))
	_im.feed_touch_event(_touch(1, Vector2(100, 0), true))
	_im.feed_touch_event(_drag(0, Vector2(-50, 0), Vector2(-50, 0)))

	assert_eq(pinches.size(), 1)
	if pinches.size() == 1:
		assert_true(is_equal_approx(pinches[0][0], 1.5),
			"distance grew from 100 to 150, so factor should be 1.5, got %s" % pinches[0][0])


func test_ambiguous_drag_release_fires_neither_tap_nor_swipe() -> void:
	# Distance is past the tap tolerance but short of the swipe minimum —
	# this must resolve to nothing, not a wrong guess.
	var taps := _collect(_im.gesture_tap)
	var swipes := _collect(_im.gesture_swipe)

	_im.feed_touch_event(_touch(0, Vector2(0, 0), true))
	_im.feed_touch_event(_drag(0, Vector2(35, 0), Vector2(35, 0)))
	_im.feed_touch_event(_touch(0, Vector2(35, 0), false))

	assert_eq(taps.size(), 0)
	assert_eq(swipes.size(), 0)


func test_touch_up_without_matching_touch_down_does_not_crash() -> void:
	var taps := _collect(_im.gesture_tap)
	_im.feed_touch_event(_touch(7, Vector2(1, 1), false))
	assert_eq(taps.size(), 0, "an unmatched release must be ignored, not crash or fire a gesture")


func test_drag_without_touch_down_is_ignored() -> void:
	var drags := _collect(_im.gesture_drag)
	_im.feed_touch_event(_drag(9, Vector2(1, 1), Vector2(1, 1)))
	assert_eq(drags.size(), 0, "a drag for an untracked touch index must be ignored")


func test_action_not_triggered_for_unmapped_gesture() -> void:
	var blank_profile = load("res://addons/core/input/input_profile.gd").new()
	_im.profile = blank_profile

	var actions := _collect(_im.action_triggered)
	_im.feed_touch_event(_touch(0, Vector2(10, 10), true))
	_im.feed_touch_event(_touch(0, Vector2(10, 10), false))

	assert_eq(actions.size(), 0, "an empty-string action mapping must not emit action_triggered")


func test_set_profile_changes_action_mapping() -> void:
	var custom_profile = load("res://addons/core/input/input_profile.gd").new()
	custom_profile.tap_action = "custom_tap"
	_im.set_profile(custom_profile)

	var actions := _collect(_im.action_triggered)
	_im.feed_touch_event(_touch(0, Vector2(10, 10), true))
	_im.feed_touch_event(_touch(0, Vector2(10, 10), false))

	assert_eq(actions.size(), 1)
	if actions.size() == 1:
		assert_eq(actions[0][0], "custom_tap")
