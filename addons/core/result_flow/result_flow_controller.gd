extends Node
## Foundation result flow. Accepts a generic result payload (outcome plus
## optional scene paths for Retry/Main Menu/Next) and drives GameManager +
## SceneRouter through it. This script has no idea what a "score" or
## "level" is — that presentation belongs to a real game's own content,
## layered on top via `result_shown`, never inside Foundation.
##
## Payload contract:
##   {
##     "outcome": "victory" | "failure",      # required
##     "retry_scene_path": String,             # optional — omit to hide Retry
##     "main_menu_scene_path": String,         # optional — omit to hide Main Menu
##     "next_scene_path": String,              # optional — omit to hide Next
##   }
## Retry and Next both transition GameManager Result -> Loading (leaving
## Result to load a scene); only which scene SceneRouter loads differs.
## Main Menu transitions Result -> MainMenu.

signal result_shown(payload: Dictionary)
signal retry_requested(scene_path: String)
signal next_requested(scene_path: String)
signal main_menu_requested(scene_path: String)
signal invalid_payload_rejected(reason: String)

const OUTCOME_VICTORY := "victory"
const OUTCOME_FAILURE := "failure"
const _VALID_OUTCOMES := [OUTCOME_VICTORY, OUTCOME_FAILURE]

var current_payload: Dictionary = {}


## Validates the payload and transitions GameManager Playing -> Result.
## Returns false (and emits invalid_payload_rejected) without changing
## any state if the payload or the current state doesn't allow it.
func show_result(payload: Dictionary) -> bool:
	var outcome = payload.get("outcome", null)
	if not _VALID_OUTCOMES.has(outcome):
		invalid_payload_rejected.emit("missing or unrecognised 'outcome': %s" % [outcome])
		return false

	if not GameManager.transition_to(GameManager.State.RESULT):
		invalid_payload_rejected.emit("GameManager rejected the transition to Result from state %s" % [
			GameManager.State.find_key(GameManager.current_state),
		])
		return false

	current_payload = payload
	result_shown.emit(payload)
	return true


func retry() -> bool:
	return _leave_result_for("retry_scene_path", GameManager.State.LOADING, retry_requested)


func next() -> bool:
	return _leave_result_for("next_scene_path", GameManager.State.LOADING, next_requested)


func main_menu() -> bool:
	return _leave_result_for("main_menu_scene_path", GameManager.State.MAIN_MENU, main_menu_requested)


func _leave_result_for(payload_key: String, target_state, request_signal: Signal) -> bool:
	if GameManager.current_state != GameManager.State.RESULT:
		return false
	var scene_path: String = current_payload.get(payload_key, "")
	if scene_path == "":
		return false
	if not GameManager.transition_to(target_state):
		return false
	request_signal.emit(scene_path)
	# The state machine has already left Result at this point — Foundation
	# has no way to know a scene path is broken until SceneRouter tries it,
	# so a routing failure is reported but does not roll back the state.
	return SceneRouter.goto_scene(scene_path)
