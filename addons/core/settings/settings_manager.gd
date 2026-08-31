extends Node
## Foundation user settings. Values live in-memory here and persist
## through SaveSystem's Foundation block (never the per-game payload) —
## settings apply across every game cloned from this template, not to one
## game's save data.

signal settings_changed

const GRAPHICS_LOW := "LOW"
const GRAPHICS_HIGH := "HIGH"
const _VALID_GRAPHICS_QUALITIES := [GRAPHICS_LOW, GRAPHICS_HIGH]

const _MIN_SENSITIVITY := 0.1
const _MAX_SENSITIVITY := 3.0

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var vibration_enabled: bool = true
var graphics_quality: String = GRAPHICS_HIGH
var control_sensitivity: float = 1.0


func _ready() -> void:
	load_settings()


func _default_settings() -> Dictionary:
	return {
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"vibration_enabled": true,
		"graphics_quality": GRAPHICS_HIGH,
		"control_sensitivity": 1.0,
	}


## Re-reads settings from SaveSystem. Never fails — a missing/corrupted
## save (already handled by SaveSystem itself) or a malformed settings
## block just falls back to defaults field-by-field.
func load_settings() -> void:
	var foundation: Dictionary = SaveSystem.get_foundation_data()
	var stored: Dictionary = foundation.get("settings", {})
	var defaults := _default_settings()

	master_volume = clampf(float(stored.get("master_volume", defaults["master_volume"])), 0.0, 1.0)
	music_volume = clampf(float(stored.get("music_volume", defaults["music_volume"])), 0.0, 1.0)
	sfx_volume = clampf(float(stored.get("sfx_volume", defaults["sfx_volume"])), 0.0, 1.0)
	vibration_enabled = bool(stored.get("vibration_enabled", defaults["vibration_enabled"]))
	control_sensitivity = clampf(
		float(stored.get("control_sensitivity", defaults["control_sensitivity"])),
		_MIN_SENSITIVITY, _MAX_SENSITIVITY,
	)

	var stored_quality = stored.get("graphics_quality", defaults["graphics_quality"])
	graphics_quality = stored_quality if _VALID_GRAPHICS_QUALITIES.has(stored_quality) else GRAPHICS_HIGH

	settings_changed.emit()


func save_settings() -> bool:
	var foundation: Dictionary = SaveSystem.get_foundation_data()
	foundation["settings"] = {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"vibration_enabled": vibration_enabled,
		"graphics_quality": graphics_quality,
		"control_sensitivity": control_sensitivity,
	}
	return SaveSystem.set_foundation_data(foundation)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	save_settings()
	settings_changed.emit()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	save_settings()
	settings_changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	save_settings()
	settings_changed.emit()


func set_vibration_enabled(value: bool) -> void:
	vibration_enabled = value
	save_settings()
	settings_changed.emit()


func set_graphics_quality(value: String) -> void:
	if not _VALID_GRAPHICS_QUALITIES.has(value):
		push_warning("SettingsManager: unknown graphics_quality '%s', ignoring" % value)
		return
	graphics_quality = value
	save_settings()
	settings_changed.emit()


func set_control_sensitivity(value: float) -> void:
	control_sensitivity = clampf(value, _MIN_SENSITIVITY, _MAX_SENSITIVITY)
	save_settings()
	settings_changed.emit()
