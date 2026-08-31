extends Node
## Foundation touch input gateway — the only place raw touch input is
## interpreted. Gameplay/UI code reacts to the gesture signals below, or
## to `action_triggered` (a gesture resolved through the current
## InputProfile), never to InputEventScreenTouch/Drag directly.
##
## Real touch events reach this through `_input()`; tests instead call
## `feed_touch_event()` / `advance_time()` directly — the same code path,
## with no real Viewport/InputEvent injection needed. Hold detection is
## time-based rather than a per-touch Timer specifically so it can be
## driven deterministically from a test with `advance_time(seconds)`.

signal gesture_tap(position: Vector2)
signal gesture_hold(position: Vector2)
signal gesture_drag(position: Vector2, relative: Vector2)
signal gesture_swipe(direction: Vector2, position: Vector2)
signal gesture_pinch(factor: float, center: Vector2)
signal action_triggered(action_name: String, position: Vector2)

const DEFAULT_PROFILE_PATH := "res://addons/core/input/default_input_profile.tres"

@export var hold_duration: float = 0.4
@export var tap_max_duration: float = 0.3
@export var tap_max_distance: float = 20.0
@export var swipe_min_distance: float = 60.0
@export var swipe_max_duration: float = 0.6

var profile: Resource = null

var _touches: Dictionary = {}
var _pinch_initial_distance: float = -1.0


func _ready() -> void:
	profile = load(DEFAULT_PROFILE_PATH)


func set_profile(new_profile: Resource) -> void:
	profile = new_profile


func _input(event: InputEvent) -> void:
	feed_touch_event(event)


func _process(delta: float) -> void:
	advance_time(delta)


func feed_touch_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func advance_time(delta: float) -> void:
	for index in _touches.keys():
		var touch: Dictionary = _touches[index]
		touch["elapsed_time"] += delta
		if touch["dragged"] or touch["hold_fired"]:
			continue
		if touch["elapsed_time"] >= hold_duration:
			touch["hold_fired"] = true
			gesture_hold.emit(touch["last_position"])
			_maybe_trigger_action(_profile_action("hold_action"), touch["last_position"])


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = {
			"start_position": event.position,
			"last_position": event.position,
			"elapsed_time": 0.0,
			"dragged": false,
			"hold_fired": false,
		}
		if _touches.size() == 2:
			_pinch_initial_distance = _pinch_distance()
		return

	var touch = _touches.get(event.index)
	_touches.erase(event.index)
	if _touches.size() < 2:
		_pinch_initial_distance = -1.0
	if touch == null:
		return
	_resolve_release(touch)


func _handle_drag(event: InputEventScreenDrag) -> void:
	var touch = _touches.get(event.index)
	if touch == null:
		return

	touch["last_position"] = event.position
	if touch["start_position"].distance_to(event.position) > tap_max_distance:
		touch["dragged"] = true

	gesture_drag.emit(event.position, event.relative)
	_maybe_trigger_action(_profile_action("drag_action"), event.position)

	if _touches.size() == 2 and _pinch_initial_distance > 0.0:
		var current_distance := _pinch_distance()
		var factor := current_distance / _pinch_initial_distance
		var center := _pinch_center()
		gesture_pinch.emit(factor, center)
		_maybe_trigger_action(_profile_action("pinch_action"), center)


func _resolve_release(touch: Dictionary) -> void:
	if touch["hold_fired"]:
		return  # already resolved as a hold; release isn't a separate gesture

	var distance: float = touch["start_position"].distance_to(touch["last_position"])

	if not touch["dragged"] and distance <= tap_max_distance and touch["elapsed_time"] <= tap_max_duration:
		gesture_tap.emit(touch["last_position"])
		_maybe_trigger_action(_profile_action("tap_action"), touch["last_position"])
		return

	if touch["dragged"] and distance >= swipe_min_distance and touch["elapsed_time"] <= swipe_max_duration:
		var direction: Vector2 = (touch["last_position"] - touch["start_position"]).normalized()
		gesture_swipe.emit(direction, touch["last_position"])
		if profile != null:
			_maybe_trigger_action(profile.resolve_swipe_action(direction), touch["last_position"])


func _maybe_trigger_action(action_name: String, position: Vector2) -> void:
	if action_name != "":
		action_triggered.emit(action_name, position)


func _profile_action(field_name: String) -> String:
	if profile == null:
		return ""
	return profile.get(field_name)


func _pinch_distance() -> float:
	var positions := _touch_positions()
	if positions.size() != 2:
		return 0.0
	return positions[0].distance_to(positions[1])


func _pinch_center() -> Vector2:
	var positions := _touch_positions()
	if positions.size() != 2:
		return Vector2.ZERO
	return (positions[0] + positions[1]) / 2.0


func _touch_positions() -> Array:
	var result: Array = []
	for index in _touches.keys():
		result.append(_touches[index]["last_position"])
	return result
