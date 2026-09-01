extends Control
## Reusable result screen — shows Retry/Main Menu/Next depending on which
## scene paths the result payload provided, and drives them through
## ResultFlowController. No score/stars/etc. here: that's a real game's
## own presentation. HUDLayer owns creating/showing this and calls
## display_result() directly (not a self-connected signal — see
## docs/ARCHITECTURE.md for why that ordering matters).

@onready var _title: Label = $Panel/VBox/Title
@onready var _retry_button: Button = $Panel/VBox/RetryButton
@onready var _main_menu_button: Button = $Panel/VBox/MainMenuButton
@onready var _next_button: Button = $Panel/VBox/NextButton


func _ready() -> void:
	_retry_button.pressed.connect(_on_retry_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_next_button.pressed.connect(_on_next_pressed)


func display_result(payload: Dictionary) -> void:
	var outcome = payload.get("outcome", "")
	_title.text = "Victory!" if outcome == ResultFlowController.OUTCOME_VICTORY else "Failure"
	_retry_button.visible = payload.has("retry_scene_path")
	_main_menu_button.visible = payload.has("main_menu_scene_path")
	_next_button.visible = payload.has("next_scene_path")


func _on_retry_pressed() -> void:
	ResultFlowController.retry()


func _on_main_menu_pressed() -> void:
	ResultFlowController.main_menu()


func _on_next_pressed() -> void:
	ResultFlowController.next()
