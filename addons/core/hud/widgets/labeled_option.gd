extends HBoxContainer
## Reusable HUD widget: a label + option dropdown over a caller-supplied
## list of string values. Generic — the Settings screen uses it for the
## LOW/HIGH graphics preset, but any small fixed-choice HUD control can
## reuse it.

signal option_selected(value: String)

@export var label_text: String = "":
	set(v):
		label_text = v
		if is_instance_valid(_label):
			_label.text = v

@onready var _label: Label = $Label
@onready var _option: OptionButton = $OptionButton

var _values: Array[String] = []


func _ready() -> void:
	_label.text = label_text
	_option.item_selected.connect(_on_item_selected)


func set_options(values: Array[String]) -> void:
	_values = values.duplicate()
	_option.clear()
	for value in _values:
		_option.add_item(value)


## Selects the displayed value without emitting option_selected — for
## initializing the widget from stored settings.
func select_value_silent(value: String) -> void:
	var index := _values.find(value)
	if index >= 0:
		_option.select(index)


func get_selected_value() -> String:
	var index: int = _option.selected
	if index >= 0 and index < _values.size():
		return _values[index]
	return ""


func _on_item_selected(index: int) -> void:
	if index >= 0 and index < _values.size():
		option_selected.emit(_values[index])
