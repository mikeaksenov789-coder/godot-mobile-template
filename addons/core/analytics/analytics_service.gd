extends Node
## Foundation analytics gateway. Ships with a safe no-op backend
## (`analytics_backend.gd`) by default — no real analytics SDK, no
## credentials. Gameplay/UI code only ever calls the three generic methods
## below; a per-game backend is swapped in via `set_backend()` without any
## caller changing.
##
## Also wires itself into existing Foundation flows (app boot, GameManager
## state transitions, pause/resume, result shown/retry/next/main menu) in
## its own _ready(), so every future game gets baseline analytics coverage
## automatically — none of those systems know analytics exists.
##
## `last_*`/`event_log` exist because there is no real backend to observe
## in tests or headless CI, mirroring HapticsManager's testable-without-a-
## device pattern (see addons/core/haptics/README.md).

signal event_logged(name: String, params: Dictionary)
signal user_property_set(name: String, value)
signal screen_viewed(name: String)

const EVENT_LOG_CAP := 200

var last_event_name: String = ""
var last_event_params: Dictionary = {}
var last_user_property_name: String = ""
var last_user_property_value = null
var last_screen_name: String = ""
var event_log: Array[Dictionary] = []

var _backend


func _ready() -> void:
	_backend = load("res://addons/core/analytics/analytics_backend.gd").new()

	GameManager.state_changed.connect(_on_state_changed)
	PauseController.paused.connect(_on_paused)
	PauseController.resumed.connect(_on_resumed)
	ResultFlowController.result_shown.connect(_on_result_shown)
	ResultFlowController.retry_requested.connect(_on_retry_requested)
	ResultFlowController.next_requested.connect(_on_next_requested)
	ResultFlowController.main_menu_requested.connect(_on_main_menu_requested)

	log_event("app_boot")


func set_backend(backend) -> void:
	_backend = backend


## Returns false without calling the backend for an empty/invalid name —
## the whole point of a generic API is that a typo or missing name fails
## quietly rather than crashing the caller.
func log_event(event_name: String, params: Dictionary = {}) -> bool:
	if event_name == "":
		return false
	last_event_name = event_name
	last_event_params = params
	_record_log("event", {"name": event_name, "params": params})
	_backend._log_event(event_name, params)
	event_logged.emit(event_name, params)
	return true


func set_user_property(property_name: String, value) -> bool:
	if property_name == "":
		return false
	last_user_property_name = property_name
	last_user_property_value = value
	_record_log("user_property", {"name": property_name, "value": value})
	_backend._set_user_property(property_name, value)
	user_property_set.emit(property_name, value)
	return true


func screen_view(screen_name: String) -> bool:
	if screen_name == "":
		return false
	last_screen_name = screen_name
	_record_log("screen_view", {"name": screen_name})
	_backend._screen_view(screen_name)
	screen_viewed.emit(screen_name)
	return true


func _record_log(kind: String, data: Dictionary) -> void:
	var entry := {"type": kind}
	for key in data:
		entry[key] = data[key]
	event_log.append(entry)
	if event_log.size() > EVENT_LOG_CAP:
		event_log.pop_front()


func _on_state_changed(_previous_state, new_state) -> void:
	screen_view(GameManager.State.find_key(new_state))


func _on_paused() -> void:
	log_event("game_paused")


func _on_resumed() -> void:
	log_event("game_resumed")


func _on_result_shown(payload: Dictionary) -> void:
	log_event("result_shown", {"outcome": payload.get("outcome", "")})


func _on_retry_requested(scene_path: String) -> void:
	log_event("retry", {"scene_path": scene_path})


func _on_next_requested(scene_path: String) -> void:
	log_event("next", {"scene_path": scene_path})


func _on_main_menu_requested(scene_path: String) -> void:
	log_event("main_menu", {"scene_path": scene_path})
