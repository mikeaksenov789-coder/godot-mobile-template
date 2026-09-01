extends Node
## Foundation top-level state machine. Owns the game's Boot/Menu/Loading/
## Playing/Paused/Result flow; nothing outside this script mutates
## `current_state` directly — call `transition_to()` and react to
## `state_changed` instead.
##
## Phase 1 implemented the approved chain Boot -> MainMenu -> Loading ->
## Playing <-> Paused -> Result, with Result as a dead end on purpose:
## retry/back-to-menu edges were deferred to the Result Flow system
## (Phase 3). Phase 3's ResultFlowController now drives the two edges out
## of Result added below — Retry and Next both re-enter through Loading
## (they're "leave Result to load a scene", differing only in which scene
## SceneRouter loads), Main Menu goes straight to MainMenu.

enum State {
	BOOT,
	MAIN_MENU,
	LOADING,
	PLAYING,
	PAUSED,
	RESULT,
}

const _TRANSITIONS: Dictionary = {
	State.BOOT: [State.MAIN_MENU],
	State.MAIN_MENU: [State.LOADING],
	State.LOADING: [State.PLAYING],
	State.PLAYING: [State.PAUSED, State.RESULT],
	State.PAUSED: [State.PLAYING],
	State.RESULT: [State.LOADING, State.MAIN_MENU],
}

signal state_changed(previous_state: State, new_state: State)

var current_state: State = State.BOOT


## Does not mutate state — safe to call for UI enable/disable checks.
func can_transition_to(next_state: State) -> bool:
	var allowed: Array = _TRANSITIONS.get(current_state, [])
	return allowed.has(next_state)


## Returns true and emits `state_changed` on success; returns false and
## leaves `current_state` untouched if the edge isn't in _TRANSITIONS.
func transition_to(next_state: State) -> bool:
	if not can_transition_to(next_state):
		push_warning("GameManager: rejected transition %s -> %s" % [
			State.find_key(current_state), State.find_key(next_state),
		])
		return false
	var previous_state := current_state
	current_state = next_state
	state_changed.emit(previous_state, current_state)
	return true
