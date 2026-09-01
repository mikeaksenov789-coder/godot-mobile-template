extends Control


func _ready() -> void:
	print("Godot Mobile Template — Phase 5 skeleton booted OK.")
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
	print("AudioManager buses: Master=%d Music=%d SFX=%d UI=%d" % [
		AudioServer.get_bus_index("Master"), AudioServer.get_bus_index("Music"),
		AudioServer.get_bus_index("SFX"), AudioServer.get_bus_index("UI"),
	])
	print("HapticsManager ready, trigger_count=", HapticsManager.trigger_count)
	print("ResultFlowController ready, current_payload=", ResultFlowController.current_payload)
	print("PerformanceManager preset=%s render_scale=%.2f shadows=%s max_lights=%d" % [
		PerformanceManager.current_preset, PerformanceManager.get_render_scale(),
		PerformanceManager.shadows_enabled(), PerformanceManager.get_max_active_lights(),
	])
	print("PoolManager ready, VFXPool bank loaded=", VFXPool.bank != null)
	print("AnalyticsService ready, last_event=", AnalyticsService.last_event_name)
	print("AdsService ready, rewarded_ready(demo)=", AdsService.is_rewarded_ready("demo"))


func _on_game_manager_state_changed(previous_state: GameManager.State, new_state: GameManager.State) -> void:
	print("GameManager state changed: %s -> %s" % [
		GameManager.State.find_key(previous_state), GameManager.State.find_key(new_state),
	])
