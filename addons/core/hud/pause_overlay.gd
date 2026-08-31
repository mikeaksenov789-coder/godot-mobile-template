extends Control
## Shown by HUDLayer when PauseController pauses. Must keep processing
## while the tree is paused (process_mode ALWAYS), or its own Resume
## button would freeze along with everything else.

signal resume_requested
signal settings_requested

@onready var _resume_button: Button = $Panel/VBox/ResumeButton
@onready var _settings_button: Button = $Panel/VBox/SettingsButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_button.pressed.connect(_on_resume_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()
