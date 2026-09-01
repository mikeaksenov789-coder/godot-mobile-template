extends "res://tests/test_case.gd"
## Tests the live HapticsManager autoload. There is no way to observe real
## device vibration headlessly, so these tests verify the gating/dispatch
## logic (last_triggered_kind, trigger_count, haptic_triggered) rather
## than the OS-level effect.

var _haptics: Node
var _settings: Node


func setup() -> void:
	_haptics = root.get_node("HapticsManager")
	_settings = root.get_node("SettingsManager")
	_settings.vibration_enabled = true
	_haptics.last_triggered_kind = ""
	_haptics.trigger_count = 0


func test_semantic_calls_trigger_when_vibration_enabled() -> void:
	_haptics.light()
	assert_eq(_haptics.last_triggered_kind, "light")
	assert_eq(_haptics.trigger_count, 1)

	_haptics.success()
	assert_eq(_haptics.last_triggered_kind, "success")
	assert_eq(_haptics.trigger_count, 2)


func test_all_five_semantic_calls_are_distinct_and_ordered() -> void:
	var seen: Array = []
	var callback := func(kind): seen.append(kind)
	_haptics.haptic_triggered.connect(callback)
	_haptics.light()
	_haptics.medium()
	_haptics.heavy()
	_haptics.success()
	_haptics.failure()
	_haptics.haptic_triggered.disconnect(callback)
	assert_eq(seen, ["light", "medium", "heavy", "success", "failure"])


func test_calls_are_suppressed_when_vibration_disabled() -> void:
	_settings.vibration_enabled = false
	_haptics.light()
	_haptics.heavy()
	assert_eq(_haptics.trigger_count, 0, "no haptic should fire while vibration is disabled")
	assert_eq(_haptics.last_triggered_kind, "")


func test_disabled_vibration_does_not_emit_signal() -> void:
	_settings.vibration_enabled = false
	var emit_count := [0]
	var callback := func(_kind): emit_count[0] += 1
	_haptics.haptic_triggered.connect(callback)
	_haptics.success()
	_haptics.haptic_triggered.disconnect(callback)
	assert_eq(emit_count[0], 0)


func test_calls_resume_after_vibration_re_enabled() -> void:
	_settings.vibration_enabled = false
	_haptics.light()
	_settings.vibration_enabled = true
	_haptics.medium()
	assert_eq(_haptics.trigger_count, 1)
	assert_eq(_haptics.last_triggered_kind, "medium")
