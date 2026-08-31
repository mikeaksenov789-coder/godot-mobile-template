extends Control


func _ready() -> void:
	print("Godot Mobile Template — Phase 1 skeleton booted OK.")
	print("Physics engine: ", ProjectSettings.get_setting("physics/3d/physics_engine"))

	GameManager.state_changed.connect(_on_game_manager_state_changed)
	var transitioned := GameManager.transition_to(GameManager.State.MAIN_MENU)
	print("GameManager Boot -> MainMenu transition ok: ", transitioned)


func _on_game_manager_state_changed(previous_state: GameManager.State, new_state: GameManager.State) -> void:
	print("GameManager state changed: %s -> %s" % [
		GameManager.State.find_key(previous_state), GameManager.State.find_key(new_state),
	])
