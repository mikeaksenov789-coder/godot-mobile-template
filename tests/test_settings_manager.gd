extends "res://tests/test_case.gd"
## Tests the live SettingsManager autoload against an isolated SaveSystem
## test path (never the real user://save.dat), cleaned before every test.
## Persistence goes through the real SaveSystem, not a mock, since
## "settings survive restart" is exactly what SaveSystem's Foundation
## block is for.

var _settings: Node
var _save: Node
var _test_dir: String = "user://test_settings_manager"


func setup() -> void:
	_settings = root.get_node("SettingsManager")
	_save = root.get_node("SaveSystem")

	DirAccess.make_dir_recursive_absolute(_test_dir)
	_clear_test_dir()
	_save.save_path = _test_dir + "/save.dat"
	_settings.load_settings()  # re-derive from the now-empty test save -> defaults


func _clear_test_dir() -> void:
	var dir := DirAccess.open(_test_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func test_defaults_when_no_save_exists() -> void:
	assert_eq(_settings.master_volume, 1.0)
	assert_eq(_settings.music_volume, 1.0)
	assert_eq(_settings.sfx_volume, 1.0)
	assert_true(_settings.vibration_enabled)
	assert_eq(_settings.graphics_quality, _settings.GRAPHICS_HIGH)
	assert_eq(_settings.control_sensitivity, 1.0)


func test_volume_settings_persist_across_reload() -> void:
	_settings.set_master_volume(0.4)
	_settings.set_music_volume(0.2)
	_settings.set_sfx_volume(0.6)

	_settings.load_settings()  # simulate a fresh app start re-reading the save

	assert_true(is_equal_approx(_settings.master_volume, 0.4))
	assert_true(is_equal_approx(_settings.music_volume, 0.2))
	assert_true(is_equal_approx(_settings.sfx_volume, 0.6))


func test_vibration_setting_persists_across_reload() -> void:
	_settings.set_vibration_enabled(false)
	_settings.load_settings()
	assert_false(_settings.vibration_enabled)


func test_control_sensitivity_persists_across_reload() -> void:
	_settings.set_control_sensitivity(2.5)
	_settings.load_settings()
	assert_true(is_equal_approx(_settings.control_sensitivity, 2.5))


func test_graphics_quality_low_persists_across_reload() -> void:
	_settings.set_graphics_quality(_settings.GRAPHICS_LOW)
	_settings.load_settings()
	assert_eq(_settings.graphics_quality, _settings.GRAPHICS_LOW)


func test_graphics_quality_high_persists_across_reload() -> void:
	_settings.set_graphics_quality(_settings.GRAPHICS_LOW)
	_settings.set_graphics_quality(_settings.GRAPHICS_HIGH)
	_settings.load_settings()
	assert_eq(_settings.graphics_quality, _settings.GRAPHICS_HIGH)


func test_invalid_graphics_quality_is_rejected() -> void:
	_settings.set_graphics_quality(_settings.GRAPHICS_LOW)
	_settings.set_graphics_quality("ULTRA")  # not a real preset
	assert_eq(_settings.graphics_quality, _settings.GRAPHICS_LOW,
		"an unrecognised quality value must be ignored, not silently accepted")


func test_volume_values_are_clamped_to_0_1() -> void:
	_settings.set_master_volume(5.0)
	assert_eq(_settings.master_volume, 1.0)
	_settings.set_master_volume(-3.0)
	assert_eq(_settings.master_volume, 0.0)


func test_control_sensitivity_is_clamped() -> void:
	_settings.set_control_sensitivity(100.0)
	assert_eq(_settings.control_sensitivity, 3.0)
	_settings.set_control_sensitivity(-1.0)
	assert_eq(_settings.control_sensitivity, 0.1)


func test_settings_are_stored_under_foundation_not_game_payload() -> void:
	_settings.set_master_volume(0.33)
	var envelope: Dictionary = _save.read_save()
	assert_true(envelope.get("foundation", {}).has("settings"))
	assert_eq(envelope.get("game", {}), {}, "settings must never leak into the per-game payload")


func test_corrupted_save_falls_back_to_default_settings() -> void:
	var file := FileAccess.open(_save.save_path, FileAccess.WRITE)
	file.store_string("{not valid json")
	file.close()

	_settings.load_settings()

	assert_eq(_settings.master_volume, 1.0)
	assert_eq(_settings.graphics_quality, _settings.GRAPHICS_HIGH)


func test_settings_changed_signal_fires_on_each_setter() -> void:
	var emit_count := [0]
	var callback := func(): emit_count[0] += 1
	_settings.settings_changed.connect(callback)
	_settings.set_master_volume(0.5)
	_settings.set_vibration_enabled(false)
	_settings.settings_changed.disconnect(callback)
	assert_eq(emit_count[0], 2)
