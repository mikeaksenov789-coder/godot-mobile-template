extends Control
## Reusable on-screen virtual joystick — a Foundation input HOOK, not a
## gameplay control scheme. Emits a normalized direction (and 0..1
## strength) while dragged, and a zero vector on release. Gameplay code
## (a later phase) listens to `joystick_input`, exactly as it would listen
## to InputManager's gesture signals. Visuals are theme-driven (see
## virtual_joystick.tscn) — this script only tracks the drag.

signal joystick_input(direction: Vector2, strength: float)

@export var max_radius: float = 80.0
@export var dead_zone: float = 0.1

var _active_touch_index: int = -1
var _center: Vector2 = Vector2.ZERO


func _ready() -> void:
	recompute_center()
	resized.connect(recompute_center)


func recompute_center() -> void:
	_center = size / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_touch_index == -1:
			_active_touch_index = event.index
			_update_from_position(event.position)
		elif not event.pressed and event.index == _active_touch_index:
			_active_touch_index = -1
			joystick_input.emit(Vector2.ZERO, 0.0)
	elif event is InputEventScreenDrag and event.index == _active_touch_index:
		_update_from_position(event.position)


func _update_from_position(local_position: Vector2) -> void:
	var offset: Vector2 = local_position - _center
	var raw_distance: float = offset.length()
	var distance: float = minf(raw_distance, max_radius)
	var strength: float = distance / max_radius if max_radius > 0.0 else 0.0
	var direction: Vector2 = offset.normalized() if raw_distance > 0.0 else Vector2.ZERO

	if strength < dead_zone:
		joystick_input.emit(Vector2.ZERO, 0.0)
	else:
		joystick_input.emit(direction, strength)
