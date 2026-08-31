extends HBoxContainer
## Reusable HUD widget: a label + toggle switch. Generic — the Settings
## screen uses it for Vibration, but any on/off HUD control can reuse it.

signal toggled(pressed: bool)

@export var label_text: String = "":
	set(v):
		label_text = v
		if is_instance_valid(_label):
			_label.text = v

@onready var _label: Label = $Label
@onready var _check: CheckButton = $CheckButton


func _ready() -> void:
	_label.text = label_text
	_check.toggled.connect(_on_check_toggled)


## Sets the displayed state without emitting `toggled` — for initializing
## the widget from stored settings.
func set_pressed_silent(pressed: bool) -> void:
	_check.set_pressed_no_signal(pressed)


func is_pressed() -> bool:
	return _check.button_pressed


func _on_check_toggled(pressed: bool) -> void:
	toggled.emit(pressed)
