# Automated Validation Rules

Partially implemented — pulled forward into Phase 4 (Performance &
pooling) at the CTO's explicit request, ahead of its original Phase 7
(Automated validation & smoke test) slot.

- `performance_validator.gd` (`extends RefCounted`, no `class_name`,
  loaded by path like everything else in this codebase) — static,
  stateless checks against a scene tree:
  - `check_light_budget(scene_root, max_lights)` — flags every
    Omni/Spot/Directional light once the scene's total exceeds the
    budget (typically `PerformanceManager.get_max_active_lights()`).
  - `check_repeated_mesh_instances(scene_root)` — flags a shared
    `Mesh` resource reused past `MESH_REPETITION_THRESHOLD` times
    without instancing/batching, since that's a common accidental
    draw-call cost.
  - `check_placeholder_markers(scene_root)` — flags nodes whose name
    signals unfinished production content (e.g. `Placeholder_*`,
    `*Greybox*`), so a scene that still ships greybox geometry where
    production assets are expected gets caught rather than shipped
    silently.
  - `validate_scene_file(path, max_lights)` — loads a `.tscn` by path
    and runs all of the above against it, returning a result
    dictionary (or an `"error"` key if the file can't be loaded).
- None of this is enforced by the engine or wired into a CI gate yet —
  it's advisory tooling a scene author or a future automated step can
  run deliberately. Wiring these checks into CI as a required step
  (plus broader structural checks — draw-call estimation, missing
  texture/material references, cross-scene consistency) remains
  Phase 7's scope.

Tests: `tests/test_performance_validator.gd` (synthetic fixtures per
rule, plus one pass against this repo's own `scenes/boot.tscn`).
