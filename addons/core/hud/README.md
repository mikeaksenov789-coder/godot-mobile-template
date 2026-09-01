# Foundation — HUD

Implemented — Phase 2 (Input, HUD, pause & settings); extended in Phase 3
(Audio, haptics & result flow).

- `hud_layer.gd` (+ `.tscn`) — the HUD root (`CanvasLayer`): hosts
  `SafeArea`, the pause button, and lazily instantiates the Settings/
  Pause/Result screens on demand. `content_root` (`SafeArea/Content`) is
  intentionally empty — a real game's HUD content goes there; nothing
  gameplay-specific lives in this template. Result screen note: it's
  shown/updated via a direct `display_result(payload)` call, not a
  self-connected signal — a screen created reactively on the first
  `result_shown` emission would connect to that signal too late to
  receive the very payload that created it.
- `safe_area.gd` — insets its content by the device safe area, read from
  `DisplayServer` at runtime (`compute_insets()` is a pure function, unit
  tested with synthetic notch geometry — a headless CI runner never sees
  a real one).
- `settings_screen.gd` (+ `.tscn`) — the six required controls (Master/
  Music/SFX volume, Vibration, Graphics LOW/HIGH, Control sensitivity),
  reading/writing `SettingsManager`.
- `pause_overlay.gd` (+ `.tscn`) — shown while `PauseController` is
  paused; stays interactive via `process_mode = ALWAYS`.
- `theme/hud_theme.tres` — the one Theme resource every widget here draws
  from. Restyling this file restyles the whole HUD without touching any
  script — this is what "HUD must be theme-driven" means in practice.
- `widgets/` — generic, reusable controls (`labeled_slider`,
  `labeled_toggle`, `labeled_option`): a label plus one input control,
  theme-driven, with a `set_*_silent()` method to initialize from stored
  state without re-triggering a save. Used to build the Settings screen;
  reusable for any future labeled HUD control.

Tests: `tests/test_safe_area.gd`. Settings persistence is tested through
`SettingsManager` (`tests/test_settings_manager.gd`), not the screen
scene directly — the screen is a thin view over it.
