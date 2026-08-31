extends CanvasLayer
## Foundation HUD root. Hosts the Safe-Area-wrapped content layer, the
## pause button, and the on-demand Settings/Pause screens. Purely
## structural — no gameplay-specific widgets live here; a real game's HUD
## content goes inside `content_root`, currently empty in the template.

const SETTINGS_SCREEN_SCENE := preload("res://addons/core/hud/settings_screen.tscn")
const PAUSE_OVERLAY_SCENE := preload("res://addons/core/hud/pause_overlay.tscn")

@onready var safe_area: Control = $SafeArea
@onready var content_root: Control = $SafeArea/Content
@onready var _pause_button: Button = $SafeArea/PauseButton

var _settings_screen: Control = null
var _pause_overlay: Control = null


func _ready() -> void:
	_pause_button.pressed.connect(_on_pause_button_pressed)
	PauseController.paused.connect(_on_game_paused)
	PauseController.resumed.connect(_on_game_resumed)


func _on_pause_button_pressed() -> void:
	PauseController.pause()


func _on_game_paused() -> void:
	if _pause_overlay == null:
		_pause_overlay = PAUSE_OVERLAY_SCENE.instantiate()
		_pause_overlay.resume_requested.connect(_on_resume_requested)
		_pause_overlay.settings_requested.connect(show_settings)
		add_child(_pause_overlay)


func _on_game_resumed() -> void:
	if _pause_overlay != null:
		_pause_overlay.queue_free()
		_pause_overlay = null


func _on_resume_requested() -> void:
	PauseController.resume()


func show_settings() -> void:
	if _settings_screen == null:
		_settings_screen = SETTINGS_SCREEN_SCENE.instantiate()
		_settings_screen.process_mode = Node.PROCESS_MODE_ALWAYS
		_settings_screen.closed.connect(hide_settings)
		add_child(_settings_screen)
	else:
		_settings_screen.refresh_from_settings()
		_settings_screen.show()


func hide_settings() -> void:
	if _settings_screen != null:
		_settings_screen.hide()
