# Foundation — Performance Presets

Implemented — Phase 4 (Performance & pooling).

- `performance_manager.gd` (autoload `PerformanceManager`) — exactly two
  presets, `PRESET_LOW` / `PRESET_HIGH`. `apply_preset()` sets live
  engine/viewport state only (`Viewport.scaling_3d_scale`,
  `Viewport.positional_shadow_atlas_size`, `Viewport.msaa_3d`);
  `set_preset()` additionally persists the choice through
  `SettingsManager.set_graphics_quality()` (and therefore `SaveSystem`),
  so the preset survives an app restart the same way every other setting
  does. Also listens to `SettingsManager.settings_changed` and
  re-applies whenever `graphics_quality` changes through any other path
  (e.g. the Settings screen), so `PerformanceManager` never needs to be
  called directly from UI code.
- Advisory budget getters — `get_render_scale()`,
  `get_max_active_lights()`, `get_particle_amount_ratio()`,
  `shadows_enabled()`, `use_simplified_materials()` — for content
  (gameplay scenes, VFX, validation tooling) to consult voluntarily.
  Godot has no engine-level hard cap on light or particle count, so
  these numbers are budgets by convention, not enforcement;
  `tools/validation/performance_validator.gd` is what actually checks a
  scene against them.
- An unrecognised preset string is rejected: `apply_preset()` falls back
  to `PRESET_HIGH` rather than leaving stale state, and `set_preset()`
  returns `false` and leaves both the applied preset and persisted
  settings untouched.

Tests: `tests/test_performance_manager.gd`.
