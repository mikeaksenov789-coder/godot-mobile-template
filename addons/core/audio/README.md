# Foundation — Audio

Implemented — Phase 3 (Audio, haptics & result flow).

- `default_bus_layout.tres` — the Master/Music/SFX/UI bus layout, loaded
  automatically at boot via `project.godot`'s
  `audio/buses/default_bus_layout`. Generated with `AudioServer` itself
  (`add_bus`/`set_bus_name`/`set_bus_send` + `generate_bus_layout()` +
  `ResourceSaver.save()`) rather than hand-written, so the `.tres` format
  is guaranteed correct for this engine version.
- `audio_manager.gd` (autoload `AudioManager`) — `play_music()` (single
  dedicated player, replay-safe), `play_sfx()`/`play_ui()` (small pooled
  `AudioStreamPlayer` sets — idle player preferred, otherwise the
  least-recently-used one is reused rather than growing the pool), and
  bus volumes that mirror `SettingsManager` (Master/Music/SFX volume;
  there is no dedicated "UI volume" setting, so the UI bus follows
  `sfx_volume`). A bus volume of exactly 0 mutes that bus explicitly
  rather than relying on `-inf` dB.

Tests: `tests/test_audio_manager.gd`.
