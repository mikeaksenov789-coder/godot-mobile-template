extends Node
## Foundation pause gate. Pausing sets the SceneTree's own `paused` flag —
## gameplay nodes freeze via their normal `process_mode`, standard Godot
## behavior — and emits signals for HUD/audio to react to. It does not
## know about or reach into gameplay itself.

signal paused
signal resumed

var is_paused: bool = false


func pause() -> bool:
	if is_paused:
		return false
	is_paused = true
	get_tree().paused = true
	paused.emit()
	return true


func resume() -> bool:
	if not is_paused:
		return false
	is_paused = false
	get_tree().paused = false
	resumed.emit()
	return true


func toggle() -> void:
	if is_paused:
		resume()
	else:
		pause()
