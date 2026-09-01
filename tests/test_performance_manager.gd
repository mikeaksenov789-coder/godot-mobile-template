extends "res://tests/test_case.gd"
## Tests the live PerformanceManager autoload against an isolated
## SaveSystem test path — persistence goes through the real
## SettingsManager/SaveSystem, not a mock, since "persistent through
## existing SettingsManager/SaveSystem" is the whole point.

var _perf: Node
var _settings: Node
var _save: Node
var _test_dir: String = "user://test_performance_manager"


func setup() -> void:
	_perf = root.get_node("PerformanceManager")
	_settings = root.get_node("SettingsManager")
	_save = root.get_node("SaveSystem")

	DirAccess.make_dir_recursive_absolute(_test_dir)
	_clear_test_dir()
	_save.save_path = _test_dir + "/save.dat"
	_settings.load_settings()  # -> defaults (graphics_quality = HIGH)
	_perf.apply_preset(_settings.graphics_quality)


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


func test_default_preset_is_high() -> void:
	assert_eq(_perf.current_preset, _perf.PRESET_HIGH)


func test_low_preset_reduces_every_advisory_budget() -> void:
	_perf.apply_preset(_perf.PRESET_LOW)
	assert_eq(_perf.current_preset, _perf.PRESET_LOW)
	assert_false(_perf.shadows_enabled())
	assert_true(_perf.use_simplified_materials())

	_perf.apply_preset(_perf.PRESET_HIGH)
	var high_render_scale: float = _perf.get_render_scale()
	var high_lights: int = _perf.get_max_active_lights()
	var high_ratio: float = _perf.get_particle_amount_ratio()

	_perf.apply_preset(_perf.PRESET_LOW)
	assert_true(_perf.get_render_scale() < high_render_scale, "LOW render scale should be lower than HIGH")
	assert_true(_perf.get_max_active_lights() < high_lights, "LOW light budget should be lower than HIGH")
	assert_true(_perf.get_particle_amount_ratio() < high_ratio, "LOW particle ratio should be lower than HIGH")


func test_high_preset_enables_shadows_and_full_budgets() -> void:
	_perf.apply_preset(_perf.PRESET_HIGH)
	assert_eq(_perf.current_preset, _perf.PRESET_HIGH)
	assert_true(_perf.shadows_enabled())
	assert_false(_perf.use_simplified_materials())


func test_set_preset_persists_through_settings_manager() -> void:
	assert_true(_perf.set_preset(_perf.PRESET_LOW))
	assert_eq(_settings.graphics_quality, _perf.PRESET_LOW)

	# Simulate a fresh app start: reload settings from disk and re-apply,
	# exactly what boot.gd does.
	_settings.load_settings()
	_perf.apply_preset(_settings.graphics_quality)
	assert_eq(_perf.current_preset, _perf.PRESET_LOW, "the LOW preset must survive a reload")


func test_invalid_preset_apply_falls_back_to_high() -> void:
	_perf.apply_preset(_perf.PRESET_LOW)
	_perf.apply_preset("ULTRA")
	assert_eq(_perf.current_preset, _perf.PRESET_HIGH,
		"an unrecognised preset must fall back to HIGH rather than leaving stale LOW state")


func test_invalid_preset_set_is_rejected() -> void:
	_perf.set_preset(_perf.PRESET_LOW)  # persists LOW, unlike apply_preset() alone
	var ok: bool = _perf.set_preset("ULTRA")
	assert_false(ok)
	assert_eq(_settings.graphics_quality, _perf.PRESET_LOW, "a rejected set_preset must not touch persisted settings")
	assert_eq(_perf.current_preset, _perf.PRESET_LOW, "a rejected set_preset must not touch the applied preset either")


func test_settings_changed_reapplies_preset_even_without_set_preset() -> void:
	# Changing graphics_quality through SettingsManager directly (as the
	# Settings screen does) must still reach PerformanceManager.
	_settings.set_graphics_quality(_perf.PRESET_LOW)
	assert_eq(_perf.current_preset, _perf.PRESET_LOW)

	_settings.set_graphics_quality(_perf.PRESET_HIGH)
	assert_eq(_perf.current_preset, _perf.PRESET_HIGH)


func test_preset_applied_signal_fires_with_resolved_preset() -> void:
	var seen: Array = []
	var callback := func(preset): seen.append(preset)
	_perf.preset_applied.connect(callback)
	_perf.apply_preset(_perf.PRESET_LOW)
	_perf.apply_preset("nonsense")
	_perf.preset_applied.disconnect(callback)
	assert_eq(seen, [_perf.PRESET_LOW, _perf.PRESET_HIGH])
