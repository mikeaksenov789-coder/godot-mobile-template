extends "res://tests/test_case.gd"
## Tests the live AudioManager autoload. Uses a short synthetic silent WAV
## (there is no real game audio asset in this template) so play_music()/
## play_sfx()/play_ui() have something valid to actually play headlessly.

var _am: Node
var _settings: Node
var _save: Node
var _test_dir: String = "user://test_audio_manager"


func setup() -> void:
	_am = root.get_node("AudioManager")
	_settings = root.get_node("SettingsManager")
	_save = root.get_node("SaveSystem")

	DirAccess.make_dir_recursive_absolute(_test_dir)
	_clear_test_dir()
	_save.save_path = _test_dir + "/save.dat"
	_settings.load_settings()  # -> defaults from the now-empty test dir

	_am.stop_music()


func _clear_test_dir() -> void:
	var dir := DirAccess.open(_test_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _make_silent_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var samples := PackedByteArray()
	samples.resize(22050 * 2)  # ~1 second of silence
	stream.data = samples
	return stream


func test_music_sfx_ui_buses_exist_and_route_to_master() -> void:
	for bus_name in ["Master", "Music", "SFX", "UI"]:
		assert_true(AudioServer.get_bus_index(bus_name) >= 0, "%s bus should exist" % bus_name)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("Music")), "Master")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")), "Master")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("UI")), "Master")


func test_play_music_starts_playback() -> void:
	assert_false(_am.is_music_playing())
	_am.play_music(_make_silent_stream())
	assert_true(_am.is_music_playing())


func test_play_sfx_returns_a_playing_player_on_sfx_bus() -> void:
	var player: AudioStreamPlayer = _am.play_sfx(_make_silent_stream())
	assert_not_null(player)
	if player != null:
		assert_true(player.playing)
		assert_eq(player.bus, "SFX")


func test_play_ui_returns_a_playing_player_on_ui_bus() -> void:
	var player: AudioStreamPlayer = _am.play_ui(_make_silent_stream())
	assert_not_null(player)
	if player != null:
		assert_true(player.playing)
		assert_eq(player.bus, "UI")


func test_play_sfx_with_null_stream_returns_null_without_error() -> void:
	var player: AudioStreamPlayer = _am.play_sfx(null)
	assert_eq(player, null)


func test_pooled_sfx_players_are_reused_not_grown() -> void:
	var stream := _make_silent_stream()
	var pool_size: int = _am._sfx_pool.size()
	var initial_ids: Array = []
	for p in _am._sfx_pool:
		p.stop()
		initial_ids.append(p.get_instance_id())

	for i in range(pool_size + 3):
		var played: AudioStreamPlayer = _am.play_sfx(stream)
		assert_true(initial_ids.has(played.get_instance_id()),
			"play_sfx must reuse a pool player, never create a new one")

	assert_eq(_am._sfx_pool.size(), pool_size, "the pool must not grow")


func test_volume_settings_drive_bus_volumes() -> void:
	_settings.set_master_volume(0.5)
	var master_idx := AudioServer.get_bus_index("Master")
	assert_true(is_equal_approx(AudioServer.get_bus_volume_db(master_idx), linear_to_db(0.5)))

	_settings.set_music_volume(0.25)
	var music_idx := AudioServer.get_bus_index("Music")
	assert_true(is_equal_approx(AudioServer.get_bus_volume_db(music_idx), linear_to_db(0.25)))


func test_zero_volume_mutes_the_bus() -> void:
	_settings.set_sfx_volume(0.0)
	var sfx_idx := AudioServer.get_bus_index("SFX")
	assert_true(AudioServer.is_bus_mute(sfx_idx))

	_settings.set_sfx_volume(0.8)
	assert_false(AudioServer.is_bus_mute(sfx_idx))


func test_ui_bus_follows_sfx_volume_setting() -> void:
	# There is no dedicated "UI volume" setting (Phase 2's six settings
	# don't include one) — the UI bus mirrors SFX by design.
	_settings.set_sfx_volume(0.3)
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var ui_idx := AudioServer.get_bus_index("UI")
	assert_true(is_equal_approx(AudioServer.get_bus_volume_db(sfx_idx), AudioServer.get_bus_volume_db(ui_idx)))
