extends Node
## Foundation haptics. Semantic calls only — gameplay code asks for
## "light"/"success"/etc., never a raw millisecond duration, so tuning
## the actual feel later is a one-line change here, not a hunt through
## call sites. Gated by SettingsManager.vibration_enabled.

signal haptic_triggered(kind: String)

const _DURATIONS_MS := {
	"light": 10,
	"medium": 25,
	"heavy": 50,
	"success": 30,
	"failure": 60,
}

## Observable record of the last dispatched call — there is no way to
## query real device vibration state, headless or otherwise, so tests
## verify this gating/dispatch logic instead of the OS-level effect.
var last_triggered_kind: String = ""
var trigger_count: int = 0


func light() -> void:
	_fire("light")


func medium() -> void:
	_fire("medium")


func heavy() -> void:
	_fire("heavy")


func success() -> void:
	_fire("success")


func failure() -> void:
	_fire("failure")


func _fire(kind: String) -> void:
	if not SettingsManager.vibration_enabled:
		return
	last_triggered_kind = kind
	trigger_count += 1
	haptic_triggered.emit(kind)
	Input.vibrate_handheld(_DURATIONS_MS.get(kind, 20))
