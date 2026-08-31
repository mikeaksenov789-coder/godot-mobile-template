# Foundation — Settings & Pause

Implemented — Phase 2 (Input, HUD, pause & settings).

- `pause_controller.gd` (autoload `PauseController`) — the pause gate:
  sets `get_tree().paused` and emits `paused`/`resumed`. Knows nothing
  about gameplay or the HUD; `HUDLayer` reacts to its signals.
- `settings_manager.gd` (autoload `SettingsManager`) — the six required
  settings (Master/Music/SFX volume, Vibration, Graphics LOW/HIGH,
  Control sensitivity), persisted through `SaveSystem`'s **Foundation**
  block (`get_foundation_data()`/`set_foundation_data()`), never the
  per-game payload — settings apply across every game cloned from this
  template.

Tests: `tests/test_pause_controller.gd`, `tests/test_settings_manager.gd`.
