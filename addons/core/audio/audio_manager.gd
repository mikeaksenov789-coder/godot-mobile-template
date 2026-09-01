extends Node
## Foundation audio gateway. Owns the Music/SFX/UI bus volumes (mirroring
## SettingsManager — there is no dedicated "UI volume" setting, so the UI
## bus follows sfx_volume by design) and a small pool of reusable
## AudioStreamPlayer nodes per bus. Gameplay/UI code calls play_sfx()/
## play_ui()/play_music(); nothing outside this script instances an
## AudioStreamPlayer.

const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const UI_BUS := "UI"

const SFX_POOL_SIZE := 8
const UI_POOL_SIZE := 4

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)

	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_pool.append(player)

	for i in range(UI_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = UI_BUS
		add_child(player)
		_ui_pool.append(player)

	apply_volume_settings()
	SettingsManager.settings_changed.connect(apply_volume_settings)


func apply_volume_settings() -> void:
	_apply_bus_volume(MASTER_BUS, SettingsManager.master_volume)
	_apply_bus_volume(MUSIC_BUS, SettingsManager.music_volume)
	_apply_bus_volume(SFX_BUS, SettingsManager.sfx_volume)
	_apply_bus_volume(UI_BUS, SettingsManager.sfx_volume)


func _apply_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	AudioServer.set_bus_mute(bus_idx, linear_volume <= 0.0)
	if linear_volume > 0.0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_volume))


func play_music(stream: AudioStream) -> void:
	if stream == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func is_music_playing() -> bool:
	return _music_player.playing


func play_sfx(stream: AudioStream) -> AudioStreamPlayer:
	return _play_pooled(_sfx_pool, stream)


func play_ui(stream: AudioStream) -> AudioStreamPlayer:
	return _play_pooled(_ui_pool, stream)


func _play_pooled(pool: Array[AudioStreamPlayer], stream: AudioStream) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player := _pick_pool_player(pool)
	player.stream = stream
	player.play()
	return player


## Prefers an idle player; if every player in the pool is busy, reuses the
## least-recently-used one (rotating it to the back) rather than growing
## the pool — a rapid burst cuts off the oldest overlapping sound instead
## of accumulating unbounded players.
func _pick_pool_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for player in pool:
		if not player.playing:
			return player
	var oldest: AudioStreamPlayer = pool[0]
	pool.append(pool.pop_front())
	return oldest
