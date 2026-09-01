# Notes for an AI agent extending this template

## The one rule that matters most

**Foundation vs. Gameplay vs. Presentation stays separated.** `addons/core/`
is shared infrastructure that every cloned game depends on — it does not
change per game. `game/` and `presentation/` are fully replaceable per
game. Never let gameplay logic read/write scene visuals directly, and never
let a Foundation system reach into `game/`. If a change to `addons/core/`
seems required by a specific game's needs, that is a signal to stop and
reconsider the API rather than special-case it.

## Where things are (or will be)

| Path | Owns | Status |
|---|---|---|
| `project.godot`, `export_presets.cfg` | Engine/Android/Jolt config | Done (Phase 0) |
| `scenes/boot.tscn` | Boot entry point | Done (Phase 0-4), placeholder content only — drives GameManager Boot -> MainMenu and instantiates HUDLayer |
| `addons/core/state/` | GameManager (FSM), SceneRouter | Done (Phase 1); Result edges added Phase 3 |
| `addons/core/save/` | SaveSystem (versioned, atomic, migrating) | Done (Phase 1) |
| `addons/core/input/` | InputManager (gestures), InputProfile, VirtualJoystick | Done (Phase 2) |
| `addons/core/hud/` | HUDLayer, SafeArea, Settings screen, reusable widgets, Theme | Done (Phase 2); Result screen added Phase 3 |
| `addons/core/settings/` | PauseController, SettingsManager | Done (Phase 2) |
| `addons/core/audio/` | AudioManager, bus layout | Done (Phase 3) |
| `addons/core/haptics/` | HapticsManager | Done (Phase 3) |
| `addons/core/result_flow/` | ResultFlowController, result screen | Done (Phase 3) |
| `addons/core/performance/` | PerformanceManager (LOW/HIGH presets) | Done (Phase 4) |
| `addons/core/pooling/` | PoolManager, VFXPool, VFXBank | Done (Phase 4) |
| `addons/core/{analytics,ads}/` | Remaining Foundation systems | Empty, see each folder's `README.md` for its phase |
| `tests/` | Headless test suite (custom runner, no third-party addon) + scene smoke test | Done (Phase 1-4) — 16 suites, 122 tests, + auto-discovering smoke test over every `.tscn` under `addons/core/` and `scenes/` (9 scenes) |
| `game/` | Per-game gameplay logic | Empty — do not populate before an actual MVP is approved |
| `presentation/` | Per-game art/VFX/audio | Empty — do not populate before an actual MVP is approved |
| `ci/` | Build environment + export/test scripts | Debug Android export only (Phase 0); `ci/run_tests.sh` gates it (Phase 1, hardened Phase 3) |
| `tools/validation/` | Automated validation rule definitions | Advisory checks implemented (Phase 4, pulled forward); not yet CI-gated — broader validation still Phase 7 |
| `docs/ARCHITECTURE.md` | Build-relevant architecture notes | Living document |

## Before doing new work here

1. Check `docs/ARCHITECTURE.md` for current phase status.
2. Do not implement a phase out of order — later phases assume earlier ones
   are in place (e.g. gameplay code assumes Foundation's state/save/input
   systems exist; don't invent ad hoc versions of them inside `game/`).
3. Do not add gameplay or production art to this repo directly — this repo
   is the template. A real MVP is a **clone** of this repo with `game/`,
   `presentation/`, and the scene content replaced; `addons/core/` should
   stay byte-identical to the template unless a deliberate Foundation
   upgrade is being merged in.
4. Any change to the pinned build image (`ci/Dockerfile`) or Godot version
   must keep `project.godot`'s physics/rendering settings and
   `export_presets.cfg` in sync with whatever that Godot version actually
   expects — verify against the engine's own source for that exact tag
   rather than assuming settings carry over unchanged between versions.
5. Never commit a keystore, keystore password, or any other signing
   secret. Release signing is CI-secret-injected only (see
   `docs/ARCHITECTURE.md`).
6. `tests/run_tests.gd` now includes a scene-instantiation smoke test that
   auto-discovers and instantiates every `.tscn` under `addons/core/` and
   `scenes/` — a new/moved scene is covered automatically, nothing to add
   to a list. It still can't catch everything: GDScript has no try/catch,
   so a runtime type error mid-`_ready()` (Phase 2's `Array[String]` bug)
   prints `SCRIPT ERROR` and aborts just that function without failing
   the smoke test or any assertion. `ci/run_tests.sh` greps the whole
   test run's output for `"SCRIPT ERROR"` as the actual safety net for
   that class of bug — if you ever run the test suite by calling
   `godot --headless --script res://tests/run_tests.gd` directly instead
   of `bash ci/run_tests.sh`, re-check the output for that string
   yourself; a clean exit code alone is not enough.
