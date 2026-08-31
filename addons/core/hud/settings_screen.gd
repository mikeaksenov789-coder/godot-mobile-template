extends Control
## Settings screen — reads/writes the SettingsManager singleton through
## the six required controls (Master/Music/SFX volume, Vibration,
## Graphics LOW/HIGH, Control sensitivity). Foundation UI only: no
## gameplay knowledge, no game-specific visuals.

signal closed

@onready var _master: Control = $Panel/VBox/MasterVolume
@onready var _music: Control = $Panel/VBox/MusicVolume
@onready var _sfx: Control = $Panel/VBox/SfxVolume
@onready var _vibration: Control = $Panel/VBox/Vibration
@onready var _graphics: Control = $Panel/VBox/Graphics
@onready var _sensitivity: Control = $Panel/VBox/Sensitivity
@onready var _close_button: Button = $Panel/VBox/CloseButton


func _ready() -> void:
	_sensitivity.set_range(0.1, 3.0, 0.05)
	# Explicitly typed: an untyped array literal here doesn't satisfy
	# LabeledOption.set_options()'s Array[String] parameter, even though
	# both elements are strings (confirmed against this engine build).
	var graphics_options: Array[String] = [SettingsManager.GRAPHICS_LOW, SettingsManager.GRAPHICS_HIGH]
	_graphics.set_options(graphics_options)

	refresh_from_settings()

	_master.value_changed.connect(_on_master_changed)
	_music.value_changed.connect(_on_music_changed)
	_sfx.value_changed.connect(_on_sfx_changed)
	_vibration.toggled.connect(_on_vibration_toggled)
	_graphics.option_selected.connect(_on_graphics_selected)
	_sensitivity.value_changed.connect(_on_sensitivity_changed)
	_close_button.pressed.connect(_on_close_pressed)


## Re-reads SettingsManager's current values into the widgets without
## triggering their change signals — avoids a redundant re-save loop and
## is also how this screen initializes on open.
func refresh_from_settings() -> void:
	_master.set_value_silent(SettingsManager.master_volume)
	_music.set_value_silent(SettingsManager.music_volume)
	_sfx.set_value_silent(SettingsManager.sfx_volume)
	_vibration.set_pressed_silent(SettingsManager.vibration_enabled)
	_graphics.select_value_silent(SettingsManager.graphics_quality)
	_sensitivity.set_value_silent(SettingsManager.control_sensitivity)


func _on_master_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)


func _on_music_changed(value: float) -> void:
	SettingsManager.set_music_volume(value)


func _on_sfx_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value)


func _on_vibration_toggled(pressed: bool) -> void:
	SettingsManager.set_vibration_enabled(pressed)


func _on_graphics_selected(value: String) -> void:
	SettingsManager.set_graphics_quality(value)


func _on_sensitivity_changed(value: float) -> void:
	SettingsManager.set_control_sensitivity(value)


func _on_close_pressed() -> void:
	closed.emit()
