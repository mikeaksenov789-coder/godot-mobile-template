extends Control
## Insets its content by the device's safe-area margins (notch/punch-hole/
## gesture-nav), read from DisplayServer at runtime. On platforms that
## don't report a real safe area — desktop, headless CI —
## DisplayServer.get_display_safe_area()'s own default falls back to the
## full usable screen rect, so this is a safe no-op there too, not just
## on Android.

func _ready() -> void:
	apply_safe_area()
	get_tree().root.size_changed.connect(apply_safe_area)


func apply_safe_area() -> void:
	var screen_size := Vector2(DisplayServer.screen_get_size())
	var safe_area := Rect2(DisplayServer.get_display_safe_area())
	var insets := compute_insets(safe_area, screen_size)
	offset_left = insets["left"]
	offset_top = insets["top"]
	offset_right = -insets["right"]
	offset_bottom = -insets["bottom"]


## Pure function, kept separate from DisplayServer so it can be unit
## tested with synthetic values — a headless CI runner never sees a real
## notch to test against.
func compute_insets(safe_area: Rect2, screen_size: Vector2) -> Dictionary:
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	return {
		"left": maxf(safe_area.position.x, 0.0),
		"top": maxf(safe_area.position.y, 0.0),
		"right": maxf(screen_size.x - (safe_area.position.x + safe_area.size.x), 0.0),
		"bottom": maxf(screen_size.y - (safe_area.position.y + safe_area.size.y), 0.0),
	}
