# Architecture

This repo is the **Master Godot 3D Mobile Template** — the reusable
foundation every future Android MVP is cloned from. The full approved
design (layering, cloud build architecture, repo structure, automation
matrix, phased implementation plan) was delivered to the CTO as
`Master_Godot_3D_Mobile_Template.docx` and approved before any
implementation started. This file tracks build-relevant specifics as they
land; it does not restate the full spec.

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
