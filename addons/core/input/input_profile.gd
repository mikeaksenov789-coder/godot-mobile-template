extends Resource
## Maps normalized gestures to logical action names. A game swaps this
## Resource to change controls without touching InputManager or gameplay
## code. No `class_name`: global class names aren't resolved on a fresh
## checkout with no `.godot/` cache (confirmed against this engine build,
## see docs/ARCHITECTURE.md) — reference this script by path/`load()`.

@export var tap_action: String = ""
@export var hold_action: String = ""
@export var drag_action: String = ""
@export var pinch_action: String = ""
@export var swipe_up_action: String = ""
@export var swipe_down_action: String = ""
@export var swipe_left_action: String = ""
@export var swipe_right_action: String = ""


## Resolves a swipe direction to the mapped action for its dominant axis.
## Empty direction or an unmapped axis returns "".
func resolve_swipe_action(direction: Vector2) -> String:
	if direction == Vector2.ZERO:
		return ""
	if absf(direction.x) > absf(direction.y):
		return swipe_right_action if direction.x > 0.0 else swipe_left_action
	return swipe_down_action if direction.y > 0.0 else swipe_up_action
