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
| `scenes/boot.tscn` | Boot entry point | Done (Phase 0-6), placeholder content only — drives GameManager Boot -> MainMenu and instantiates HUDLayer |
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
| `addons/core/analytics/` | AnalyticsService (generic API + Foundation-flow hooks) | Done (Phase 5); no real analytics SDK integrated |
| `addons/core/ads/` | AdsService (rewarded only), AdsBackend, MockAdsBackend | Done (Phase 5); no real ad SDK integrated |
| `tests/` | Unit suites (`run_tests.gd`) + scene smoke test (`run_smoke_test.gd`, split out Phase 6) | Done (Phase 1-6) — 18 suites, 144 tests, + auto-discovering smoke test over every `.tscn` under `addons/core/` and `scenes/` (9 scenes) |
| `game/` | Per-game gameplay logic | Empty — do not populate before an actual MVP is approved |
| `presentation/` | Per-game art/VFX/audio | Empty — do not populate before an actual MVP is approved |
| `ci/` | Build environment + versioning/env-validation/export scripts | Debug APK + release AAB paths (release gated on a signing secret), automatic versioning, Gradle cache, environment validation (Phase 6) |
| `tools/validation/` | Content validation rules (`performance_validator.gd`) + CI gate (`run_validation.gd`) | Advisory checks implemented (Phase 4, pulled forward); runs as its own CI stage (Phase 6); broader validation (draw-call estimation, missing-reference scanning) still Phase 7 |
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
   secret. Release signing is CI-secret-injected only, via three repo
   secrets the release job reads and this repository never defines:
   `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`,
   `ANDROID_KEYSTORE_PASSWORD` (see `docs/ARCHITECTURE.md`,
   `ci/export_android_release.sh`).
6. `tests/run_smoke_test.gd` auto-discovers and instantiates every
   `.tscn` under `addons/core/` and `scenes/` — a new/moved scene is
   covered automatically, nothing to add to a list. It still can't catch
   everything: GDScript has no try/catch, so a runtime type error
   mid-`_ready()` (Phase 2's `Array[String]` bug) prints `SCRIPT ERROR`
   and aborts just that function without failing the smoke test or any
   assertion. `ci/run_tests.sh` greps the combined output of all three
   stages (unit tests, content validators, smoke test) for
   `"SCRIPT ERROR"` as the actual safety net for that class of bug — if
   you ever run one of `tests/run_tests.gd` /
   `tools/validation/run_validation.gd` / `tests/run_smoke_test.gd`
   directly with `godot --headless --script <path>` instead of
   `bash ci/run_tests.sh`, re-check the output for that string yourself;
   a clean exit code alone is not enough.
7. `ci/set_version.sh` patches `export_presets.cfg`'s `version/code`/
   `version/name` in place before every export — never hand-edit those
   two lines in `export_presets.cfg` expecting them to stick; they're
   overwritten by every CI build (see `docs/ARCHITECTURE.md` Phase 6).
