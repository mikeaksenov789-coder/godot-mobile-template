# Automated Validation Rules

Implemented — pulled forward into Phase 4 (Performance & pooling) at the
CTO's explicit request, wired into CI as its own gate in Phase 6 (Cloud
build pipeline hardening), and finalized with a second validator plus
broader checks in Phase 7 (Automated validation & screenshot QA).

- `performance_validator.gd` (`extends RefCounted`, no `class_name`,
  loaded by path like everything else in this codebase) — static,
  stateless rendering-budget checks against a scene tree:
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
- `foundation_validator.gd` (Phase 7, same no-`class_name` pattern) —
  static checks for a different concern: Foundation configuration and
  content references, not rendering cost.
  - `check_required_autoloads(root)` — flags any autoload
    `project.godot` registers that isn't actually present under the
    running tree's root.
  - `check_broken_references(scene_path)` — reads a `.tscn` as text and
    flags every `res://` `ext_resource` path that doesn't resolve, a
    broken reference Godot itself only otherwise surfaces as a runtime
    load error (or, for a deeply-nested sub-resource, not at all until
    something tries to use it).
  - `check_physics_layer_convention(scene_root)` — flags any
    `CollisionObject2D`/`3D` node using a `collision_layer`/
    `collision_mask` bit outside layers 1-8, this template's reserved
    convention (see `docs/ARCHITECTURE.md` Phase 7 — no gameplay ships
    real physics content yet, so this always passes today, but the
    convention exists for whichever phase adds the first one).
  - `check_theme_resource(theme_path)` — flags a missing/unloadable HUD
    theme, or one missing the Button/Panel styles every current HUD
    screen actually draws with.
  - `check_bank_hooks(root)` — flags a `VFXPool` with no bank assigned,
    or a missing Master/Music/SFX/UI audio bus.
  - `validate_foundation_configuration(root)` — aggregates the three
    root-level checks above (autoloads, bank hooks, theme) into one
    result dictionary; the "invalid Foundation configuration" gate.
- `run_validation.gd` — `godot --headless --script
  res://tools/validation/run_validation.gd`. Runs every
  `performance_validator.gd` and per-scene `foundation_validator.gd`
  check against every real `.tscn` under `addons/core/` and `scenes/`
  (the same roots `tests/run_smoke_test.gd` scans), plus
  `validate_foundation_configuration()` once against the live root, and
  fails (exit 1) if anything is flagged. `ci/run_tests.sh` runs this as
  its own stage, between the unit test suite and the scene smoke test —
  always clean today since `game/`/`presentation/` are still empty, but
  it's the real gate future gameplay/art content has to pass in CI, not
  just advisory tooling someone might remember to run by hand.
- Broader structural checks — draw-call estimation, missing
  texture/material reference scanning beyond `ext_resource` paths,
  cross-scene consistency — remain out of scope; nothing further is
  currently planned to add them.

Tests: `tests/test_performance_validator.gd`, `tests/test_foundation_validator.gd`
(synthetic fixtures per rule, plus passes against this repo's own real
autoloads/theme/scenes).
