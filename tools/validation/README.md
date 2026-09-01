# Automated Validation Rules

Partially implemented — pulled forward into Phase 4 (Performance &
pooling) at the CTO's explicit request, ahead of its original Phase 7
(Automated validation & smoke test) slot. Wired into CI as its own gate
in Phase 6 (Cloud build pipeline hardening).

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
- `run_validation.gd` — `godot --headless --script
  res://tools/validation/run_validation.gd`. Runs `validate_scene_file()`
  against every real `.tscn` under `addons/core/` and `scenes/` (the same
  roots `tests/run_smoke_test.gd` scans) and fails (exit 1) if any scene
  is flagged. `ci/run_tests.sh` runs this as its own stage, between the
  unit test suite and the scene smoke test — always clean today since
  `game/`/`presentation/` are still empty, but it's the real gate future
  gameplay/art content has to pass in CI, not just advisory tooling
  someone might remember to run by hand.
- Broader structural checks — draw-call estimation, missing
  texture/material reference scanning, cross-scene consistency — remain
  Phase 7's scope.

Tests: `tests/test_performance_validator.gd` (synthetic fixtures per
rule, plus one pass against this repo's own `scenes/boot.tscn`).
