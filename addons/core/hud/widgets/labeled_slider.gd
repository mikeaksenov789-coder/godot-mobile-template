extends HBoxContainer
## Reusable HUD widget: a label + slider. Generic, not settings-specific —
## the Settings screen uses it for volume/sensitivity, but any HUD screen
## needing a labeled numeric picker can reuse it.

signal value_changed(value: float)

@export var label_text: String = "":
	set(v):
		label_text = v
		if is_instance_valid(_label):
			_label.text = v

@onready var _label: Label = $Label
@onready var _slider: HSlider = $HSlider


func _ready() -> void:
	_label.text = label_text
	_slider.value_changed.connect(_on_slider_value_changed)


func set_range(min_value: float, max_value: float, step: float) -> void:
	_slider.min_value = min_value
	_slider.max_value = max_value
	_slider.step = step


## Sets the displayed value without emitting value_changed — for
## initializing the widget from stored settings.
func set_value_silent(value: float) -> void:
	_slider.set_block_signals(true)
	_slider.value = value
	_slider.set_block_signals(false)


func get_value() -> float:
	return _slider.value


func _on_slider_value_changed(new_value: float) -> void:
	value_changed.emit(new_value)
