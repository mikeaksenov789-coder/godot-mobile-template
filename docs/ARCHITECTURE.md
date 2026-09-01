# Architecture

This repo is the **Master Godot 3D Mobile Template** — the reusable
foundation every future Android MVP is cloned from. The full approved
design (layering, cloud build architecture, repo structure, automation
matrix, phased implementation plan) was delivered to the CTO as
`Master_Godot_3D_Mobile_Template.docx` and approved before any
implementation started. This file tracks build-relevant specifics as they
land; it does not restate the full spec.

## Current status: Phase 4 — Performance & Pooling

Implemented on top of the verified Phase 3 baseline (unchanged: Godot
4.7.2, Jolt, portrait Android, cloud build, state/save/input/HUD/pause/
settings/audio/haptics/result flow). No gameplay, no final art, no
Phase 5+ systems.

- `addons/core/performance/` (autoload `PerformanceManager`) — exactly
  two presets, LOW/HIGH. `apply_preset()` touches live `Viewport` state
  only (`scaling_3d_scale`, `positional_shadow_atlas_size`, `msaa_3d`);
  `set_preset()` additionally persists through
  `SettingsManager.set_graphics_quality()`, so LOW/HIGH survives a
  restart the same way every other setting does, and reapplies
  automatically on `settings_changed` (e.g. when the Settings screen's
  existing Graphics LOW/HIGH control changes it — Phase 2 already built
  that UI, Phase 4 just gave it a real backing system). Exposes advisory
  getters (`get_max_active_lights()`, `get_particle_amount_ratio()`,
  `shadows_enabled()`, `use_simplified_materials()`) for content and
  tooling to consult voluntarily.
- `addons/core/pooling/` (autoloads `PoolManager`, `VFXPool`, plus a
  `vfx_bank.gd` Resource type and an empty `default_vfx_bank.tres`) —
  generic acquire/release object pooling with prewarm and a capacity
  cap, and a `GPUParticles3D`-based VFX layer built on top of it
  (`play(vfx_id, transform)`), so no game-side hot loop needs to
  `instantiate()`/`free()` directly. No VFX art ships yet — the bank is
  empty on purpose (Phase 4 has no final art).
- `tools/validation/performance_validator.gd` — static scene-tree
  checks pulled forward from Phase 7 at the CTO's request: excessive
  light count against a budget, a single mesh resource repeated past a
  threshold (a common accidental draw-call cost), and node names
  signalling leftover placeholder/greybox content. Advisory only, not
  yet wired into a CI gate — see `tools/validation/README.md`.
- `boot.gd`/`boot.tscn` — now also print PerformanceManager/PoolManager/
  VFXPool readiness.
- `tests/` grew from 87 to 122 tests (12 to 16 suites); no new `.tscn`
  scenes this phase, so the smoke test still covers the same 9 scenes.

### Why performance budgets are advisory, not enforced

Godot has no engine-level hard cap on active lights or particle count —
nothing stops a scene from exceeding `PerformanceManager`'s numbers, the
engine will just render it, slowly. `get_max_active_lights()` etc. are
therefore a convention future content and `performance_validator.gd` opt
into voluntarily, not a runtime limiter. Actually gating content on these
budgets (failing a build, refusing to instantiate) is a bigger,
deliberate decision that belongs with the rest of Phase 7's CI wiring,
not smuggled into Phase 4.

### Why `PackedScene.pack()` for pooling/VFX test fixtures

`PoolManager`, `VFXPool`, and `performance_validator.gd`'s tests all need
throwaway scenes (a bare `Node3D`, a minimal `GPUParticles3D`) without
shipping placeholder `.tscn` files that would themselves look like
production content to `check_placeholder_markers()`. Building a node in
code and calling `PackedScene.pack(node)` produces a real, valid
`PackedScene` for `PoolManager.register_pool()`/`VFXPool.play()` to
instantiate from, entirely in memory — confirmed working against this
engine build, and it keeps every pooling/VFX test self-contained.

### A prewarm behavior worth flagging for future test-writers

`VFXPool.play()` registers its `PoolManager` pool (prewarm size 4, cap
16) lazily, on first use per `vfx_id` — not at boot. The first `play()`
call for a given effect therefore prewarms *all 4* instances at once,
not just the one being played. A test that plays one effect, lets it
finish, and then asserts exactly one instance is back in the "available"
pool will get 4, not 1 — this genuinely is how the pool is meant to
behave (prewarm-then-reuse), so the correct assertion compares against
`PoolManager.get_pool_size()` rather than a hardcoded `1`.

## Current status: Phase 3 — Audio, Haptics & Result Flow

Implemented on top of the verified Phase 2 baseline (unchanged: Godot
4.7.2, Jolt, portrait Android, cloud build, state/save/input/HUD/pause/
settings):

- `addons/core/audio/` (autoload `AudioManager`) — Master/Music/SFX/UI
  buses (`default_bus_layout.tres`, generated with `AudioServer` itself
  rather than hand-written — see below), a single music player, and
  pooled SFX/UI players (idle-preferred, least-recently-used reused
  otherwise — the pool never grows). Bus volumes mirror SettingsManager;
  UI has no dedicated setting so it follows `sfx_volume`.
- `addons/core/haptics/` (autoload `HapticsManager`) — five semantic
  calls (`light`/`medium`/`heavy`/`success`/`failure`), gated by
  `vibration_enabled`.
- `addons/core/result_flow/` (autoload `ResultFlowController` + reusable
  `result_screen.tscn`) — a generic result payload
  (`{"outcome": ..., "retry_scene_path": ..., ...}`) drives GameManager
  Playing -> Result, and Retry/Next/Main Menu back out through
  SceneRouter. No score/level/gameplay concept anywhere in Foundation.
- `addons/core/state/game_manager.gd` — Result gained its two Phase-3
  edges (`Result -> Loading` for Retry/Next, `Result -> MainMenu`),
  exactly as Phase 1's own comments said it would; the Phase 1 test that
  asserted Result was a dead end was updated to assert the new, narrower
  set of allowed edges instead of being deleted.
- `boot.gd`/`boot.tscn` — now also print Audio/Haptics/ResultFlow
  readiness.
- `tests/` grew from 60 to 87 tests (9 to 12 suites), plus a new
  **scene-instantiation smoke test** (see below) that isn't a suite —
  it recursively discovers and instantiates every `.tscn` under
  `addons/core/` and `scenes/`, so a new scene is covered automatically
  without editing a list.

### Why the smoke test needed a second, CI-shell-level net

GDScript has no try/catch and no error-count API a script can query.
Phase 2 shipped a real bug — an untyped array literal where
`LabeledOption.set_options()` expected `Array[String]` — that printed
`SCRIPT ERROR` and aborted just that `_ready()` call, without
`instantiate()` returning null and without failing any test's assertions.
The smoke test in `tests/run_tests.gd` (`_run_scene_smoke_tests`) still
catches a scene that fails to *load* or *instantiate* outright, but that
exact class of "silently half-initialized" bug needed a second net:
`ci/run_tests.sh` runs the whole suite, then greps its captured output
for the literal string `"SCRIPT ERROR"` and fails the step if found —
specifically that string, not bare `"ERROR:"`, because normal engine
shutdown prints benign lines like `"ERROR: N resources still in use at
exit"` that would otherwise false-positive on every run.

### Why the bus layout is generated, not hand-written

`AudioBusLayout .tres` is a plain enough format to guess at, but Phase 0
and Phase 2 both turned up engine details that didn't match assumption
(export option keys, `DisplayServer`'s real header path). Rather than risk
a third one, `default_bus_layout.tres` was produced by actually calling
`AudioServer.add_bus()`/`set_bus_name()`/`set_bus_send()` against this
exact 4.7.2 binary, then `AudioServer.generate_bus_layout()` +
`ResourceSaver.save()` — the file committed to the repo is that generated
output verbatim, not a hand-typed guess.

## Current status: Phase 2 — Input, HUD, Pause & Settings

Implemented on top of the verified Phase 1 baseline (unchanged: Godot
4.7.2, Jolt, portrait Android, cloud build, GameManager/SceneRouter/
SaveSystem):

- `addons/core/input/` (autoload `InputManager`) — normalizes raw touch
  into tap/hold/drag/swipe/pinch gestures and resolves them through a
  swappable `InputProfile` Resource into `action_triggered`. A reusable
  `VirtualJoystick` control demonstrates the "virtual controls feed the
  same InputManager stream" pattern.
- `addons/core/hud/` — `HUDLayer` (CanvasLayer root: SafeArea + pause
  button + on-demand Settings/Pause screens), `SafeArea` (reads the real
  device safe area from `DisplayServer`, pure-function inset math so it's
  unit testable without a real notch), a Settings screen built from three
  generic, theme-driven widgets (`labeled_slider`, `labeled_toggle`,
  `labeled_option`), and one Theme resource every one of them draws from.
- `addons/core/settings/` (autoloads `PauseController`, `SettingsManager`)
  — pausing is just `get_tree().paused` plus signals; settings are the six
  required controls (Master/Music/SFX volume, Vibration, Graphics LOW/
  HIGH, Control sensitivity), persisted through SaveSystem's **Foundation**
  block (never the per-game payload — this is exactly what that Phase 1
  separation was for).
- `boot.gd` now also prints SettingsManager/InputManager/PauseController
  readiness, and `boot.tscn` instantiates `HUDLayer`, so the pause button
  and Settings screen are reachable at runtime, not just under test.
- `tests/` grew from 3 suites (18 tests) to 9 suites (60 tests) — gesture
  recognition, InputProfile mapping, the virtual joystick, Safe Area inset
  math, pause/resume, and settings persistence (including LOW/HIGH and a
  corrupted-save fallback).

### Why HUD is theme-driven

Every widget under `addons/core/hud/` (and `settings_screen.tscn`,
`pause_overlay.tscn`) references `theme/hud_theme.tres` for its Button/
Panel/Label styling — none of them hardcode a color or style box in the
script. A future game reskins the whole HUD by replacing that one Theme
resource; nothing in `input_manager.gd`, `settings_manager.gd`, or
`pause_controller.gd` needs to change, or even knows the Theme exists.

### Two more engine quirks found this phase, both confirmed against 4.7.2

- An untyped `Array` literal (e.g. `[a, b]`) does not satisfy a parameter
  typed `Array[String]`, even when every element actually is a String —
  the literal must be assigned to an explicitly `Array[String]`-typed
  variable first. Caught in `settings_screen.gd` calling
  `LabeledOption.set_options()` — passed local tests (which never
  instantiate the actual scene) but failed at scene `_ready()`, which is
  why Phase 2's verification included directly instantiating
  `settings_screen.tscn`/`pause_overlay.tscn`/`hud_layer.tscn` headlessly,
  not just running the unit test suite.
- `DisplayServer`'s safe-area API lives at
  `servers/display/display_server.h` in the engine source, not
  `servers/display_server.h` — `get_display_safe_area() -> Rect2i`
  defaults to `screen_get_usable_rect()` on platforms without a real
  cutout (safe everywhere, not just Android), which is what makes
  `SafeArea` a no-op in headless CI rather than an error.

## Current status: Phase 1 — Core State & Save

Implemented on top of the Phase 0 baseline (unchanged: Godot 4.7.2, Jolt,
portrait Android, cloud build):

- `addons/core/state/game_manager.gd` (autoload `GameManager`) — the
  top-level FSM: `Boot -> MainMenu -> Loading -> Playing <-> Paused ->
  Result`. `Result` is a dead end in Phase 1 on purpose; retry/back-to-menu
  edges belong to Result Flow (Phase 3).
- `addons/core/state/scene_router.gd` (autoload `SceneRouter`) — the only
  sanctioned way to swap the active scene (`goto_scene(path)`), with a
  guard against overlapping/reentrant loads and validation of the target
  resource before touching the tree.
- `addons/core/save/save_system.gd` (autoload `SaveSystem`) — a versioned
  JSON save envelope (`schema_version` + separated `foundation`/`game`
  blocks), atomic write, safe load (missing/corrupted/unrecognised-version
  all fall back to a fresh envelope; corrupted files are backed up, not
  discarded), and a working v1→v2 migration.
- `scenes/boot.gd` now drives `GameManager` through `Boot -> MainMenu` on
  boot, so the state machine is exercised at runtime, not just in tests.
- `tests/` — a minimal custom headless test runner (no third-party test
  addon; see "Why a custom test runner" below) covering all three systems.
  Wired into CI as a required step ahead of the Android build.

See each of `addons/core/state/README.md` and `addons/core/save/README.md`
for the file-level summary.

## Why a custom test runner, not GUT/gdUnit4

Pulling in a third-party test addon means pinning ITS version compatibility
against the exact engine version too, and vendoring/updating it over time.
Phase 1 only needs "run assertions headlessly in CI, fail the build on
red" — `tests/test_case.gd` (~60 lines) covers that without an extra
dependency. Revisit if test needs grow past what soft-assert `assert_*`
calls comfortably express.

Two non-obvious things the runner and suites work around, both confirmed
against the exact pinned 4.7.2 engine build:

- A node's `get_tree()` returns null until one frame after the runner's
  custom `SceneTree._initialize()` starts (autoloads call `get_tree()`
  internally, e.g. SceneRouter) — the runner yields one `process_frame`
  before running anything, and again between every test (so a previous
  test's `queue_free()`'d scene is actually gone before the next test adds
  a same-named node under `root`).
- Global `class_name` lookups (e.g. `extends TestCase`) aren't resolved on
  a fresh checkout with no `.godot/` cache — exactly the state every CI
  run starts from — so suites `extends "res://tests/test_case.gd"` by path
  instead.

## Current status: Phase 0 — Skeleton

Implemented in this phase:

- A bare Godot 4.7.2 project (`project.godot`) with:
  - `physics/3d/physics_engine = "Jolt Physics"` (built-in, no GDExtension)
  - Portrait orientation (`window/handheld/orientation = 1`)
  - Mobile rendering method (`rendering/renderer/rendering_method = "mobile"`)
- One boot scene (`scenes/boot.tscn`) that boots, prints a readiness line,
  and does nothing else — no gameplay, no art.
- An Android export preset (`export_presets.cfg`) producing a **debug**
  APK, signed with Godot's own auto-managed debug key (no secrets needed).
- A cloud build pipeline (`.github/workflows/android-build.yml`) that runs
  entirely on GitHub Actions, in a container pinned by image digest
  (`ci/Dockerfile` documents the pin), and uploads the built APK as a
  downloadable workflow artifact. No local PC involvement.
- The full target folder structure (`addons/core/*`, `game/`,
  `presentation/`, `tools/`, `docs/`) created empty with per-folder
  `README.md` stubs stating which later phase owns them. Nothing inside
  those folders is implemented yet — see each stub for its phase.

## Why `barichello/godot-ci`, pinned by digest

Building a from-scratch Godot+Android SDK/NDK Docker image is real
infrastructure work with little payoff versus the actively-maintained
community image already built for exactly this purpose. To avoid the
"pinned container" requirement silently degrading if the `4.7.2` tag were
ever republished, the workflow pins the exact image **digest** (see
`ci/Dockerfile`), not the tag. Bumping the engine version later is a
one-line change plus re-resolving the digest.

## Why debug-only in Phase 0

A release build needs a signing keystore. Keystore custody/rotation is
explicitly a human decision (not something to fabricate a placeholder for),
so release export is deferred until that's provisioned. Debug export needs
no such secret — Godot manages its own debug key automatically — which is
why Phase 0's APK is a debug build.

## Physics engine value, verified

`physics/3d/physics_engine = "Jolt Physics"` is not a guess: the exact
registered server name was confirmed against the Godot 4.7.2 engine binary
itself (`strings` on the official release binary shows `Jolt Physics` and
`GodotPhysics3D` as the two registered 3D physics server names), and the
project was boot-tested locally against that same binary with the setting
in place — `ProjectSettings.get_setting("physics/3d/physics_engine")`
round-trips correctly and the engine boots with zero physics-related
errors or fallback warnings.
