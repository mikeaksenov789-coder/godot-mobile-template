extends Control


func _ready() -> void:
	print("Godot Mobile Template — Phase 2 skeleton booted OK.")
	print("Physics engine: ", ProjectSettings.get_setting("physics/3d/physics_engine"))

	GameManager.state_changed.connect(_on_game_manager_state_changed)
	var transitioned := GameManager.transition_to(GameManager.State.MAIN_MENU)
	print("GameManager Boot -> MainMenu transition ok: ", transitioned)

	print("SettingsManager loaded: master=%.2f music=%.2f sfx=%.2f vibration=%s graphics=%s sensitivity=%.2f" % [
		SettingsManager.master_volume, SettingsManager.music_volume, SettingsManager.sfx_volume,
		SettingsManager.vibration_enabled, SettingsManager.graphics_quality, SettingsManager.control_sensitivity,
	])
	print("InputManager profile loaded: ", InputManager.profile != null)
	print("PauseController ready, is_paused=", PauseController.is_paused)


func _on_game_manager_state_changed(previous_state: GameManager.State, new_state: GameManager.State) -> void:
	print("GameManager state changed: %s -> %s" % [
		GameManager.State.find_key(previous_state), GameManager.State.find_key(new_state),
	])
