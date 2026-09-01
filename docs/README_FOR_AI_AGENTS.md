# Notes for an AI agent extending this template

This is the implementation-ready production handoff protocol for any AI
agent (or human) taking a real game from this template to a shipped
Android build. `CLAUDE.md`'s "PERMANENT PRODUCTION HANDOFF PROTOCOL"
section is the always-loaded summary of the rules this document expands
on — read both, but this document is the one with exact commands,
exact inputs, and exact workflows. It incorporates what Phase 8's
dry-run clone (a real end-to-end test of everything in this document,
run before this document itself was finalized) actually proved and
actually caught.

## 1. The one rule that matters most

**Foundation vs. Gameplay vs. Presentation stays separated.** `addons/core/`
is shared infrastructure that every cloned game depends on — it does not
change per game. `game/` and `presentation/` are fully replaceable per
game. Never let gameplay logic read/write scene visuals directly, and never
let a Foundation system reach into `game/`. If a change to `addons/core/`
seems required by a specific game's needs, that is a signal to stop and
reconsider the API rather than special-case it.

## 2. The three boundaries, exactly

- **Foundation — `addons/core/`.** Shared, game-agnostic infrastructure:
  state/save, input, HUD shell, settings, audio/haptics plumbing, result
  flow, performance, pooling, analytics/ads interfaces. Stays
  byte-identical across every clone unless a Foundation upgrade is its
  own explicitly approved task. Nothing in here ever imports from
  `game/` or `presentation/`.
- **Gameplay — `game/`.** Per-game logic, physics, level/entity
  structure, win/lose rules, controls. Calls Foundation only through its
  public API (`SceneRouter.goto_scene()`, `ResultFlowController.show_result()`,
  `AnalyticsService.log_event()`, etc. — never by reaching into a
  Foundation autoload's private state). Never hardcodes a concrete
  visual or audio asset; references `presentation/` resources by path
  instead — the exact boundary `tests/test_mvp_gameplay_integration.gd`
  (Phase 8's dry-run) exists to prove: swap the material a level
  references, and the Gameplay script never changes.
- **Presentation — `presentation/` (+ per-game `scenes/` content, HUD
  theme overrides).** Materials, models, VFX bank entries, audio bank
  entries, UI skin, animations — the concrete "what it looks/sounds
  like." Fully replaceable independently of Gameplay. This is where a
  CTO-supplied visual/audio package lands (see §6-7).
- **Supporting infrastructure — `tests/`, `tools/`, `ci/`, `docs/`,
  `.github/workflows/`.** Not part of the Foundation/Gameplay/
  Presentation split, but also not per-game content — this is the
  template's own build/test/QA machinery, shared unchanged across
  clones except for the narrow, well-defined extension points listed in
  §3. It is more valuable to a real game *un-modified* than customized:
  every fix already baked into it (Phase 6's `GRADLE_USER_HOME`/`$GITHUB_SHA`
  fixes, Phase 7's Xvfb/Mesa library list) is a bug a real game will not
  have to re-discover.
- **`scenes/boot.tscn`/`boot.gd`** sits at the Gameplay/Foundation seam:
  it is per-game content (a real MVP customizes its identity and, later,
  wires in a real main menu), but its *mechanism* — drive `GameManager`
  Boot → MainMenu, instantiate `HUDLayer`, leave the HUD's Settings/Pause
  entry points reachable — is exactly what `tools/qa/screenshot_capture.gd`'s
  five checkpoints depend on. Changing the label text is always safe;
  changing boot.gd to auto-advance away from MainMenu (e.g. straight into
  gameplay) will break the Settings/Pause screenshot checkpoints unless
  screenshot_capture.gd's own checkpoint logic is updated to match — treat
  that as a deliberate, coordinated change, not an incidental one.

## 3. What an AI agent may modify freely

- Everything under `game/` and `presentation/`.
- `scenes/` content (new scenes, boot.tscn's identity/label text and,
  deliberately and with the coordination noted in §2, its flow).
- `tests/test_*.gd` — add new suites for real gameplay/presentation
  code. Append (never remove or reorder existing entries in) `tests/run_tests.gd`'s
  `SUITE_SCRIPTS` and `tests/run_smoke_test.gd`'s `SMOKE_TEST_ROOTS` — both
  are plain arrays designed to be extended per clone (Phase 8 added
  `res://game`/`res://presentation` to the smoke roots and a new suite
  to `SUITE_SCRIPTS` this exact way).
- `project.godot`'s `config/name`/`config/description`, and
  `export_presets.cfg`'s `package/unique_name`/`package/name`/`export_path`
  (both presets) — the per-game identity fields. Never hand-edit
  `version/code`/`version/name`; `ci/set_version.sh` overwrites them
  every build (see §9 and `docs/ARCHITECTURE.md` Phase 6).
- The workflow's `EXPORT_NAME` env var (`.github/workflows/android-build.yml`),
  for artifact-naming identity only.
- `README.md`, and the `game/`/`presentation/` subdirectory `README.md`
  stubs, to describe what's actually been built.

## 4. What an AI agent must never modify without explicit CTO approval

- **`addons/core/` (Foundation), at all.** Any change here is a
  Foundation upgrade — its own explicitly approved task, never a side
  effect of a game task. Verify with `diff -rq` against the source
  template before every handoff (§5, step 4).
- **`tools/validation/`'s scan roots or core check logic.** Its
  `SCAN_ROOTS`/`REQUIRED_AUTOLOADS` intentionally do not cover `game/`/
  `presentation/` — extending them would make
  `check_placeholder_markers()` flag a real game's own intentionally-named
  placeholder content as a build failure. If a real game genuinely needs
  its own content validated, that is a scoped addition to propose to the
  CTO, not something to wire in silently.
- **`tools/qa/screenshot_capture.gd`'s five checkpoint definitions** —
  adding a sixth checkpoint for new gameplay screens is expected and
  welcome; silently changing what an existing checkpoint captures breaks
  the CTO's ability to compare builds over time.
- **`ci/*.sh`'s core mechanics** — the `GRADLE_USER_HOME` export, the
  advisory (non-fatal) Android SDK check, `$GITHUB_SHA`-based
  versioning, the Xvfb/Mesa package list. Every one of these exists
  because of a real CI failure diagnosed and fixed in Phases 6-7 (see
  `docs/ARCHITECTURE.md`) — touching them without first reading why
  risks silently reintroducing a bug that already cost a full CI cycle
  to find once.
- **`.github/workflows/android-build.yml`'s job structure** — job names,
  artifact names, the `needs:`/`if:` gating between jobs, the
  tests → validators → smoke test → build → upload order. Add steps
  within a job or a new parallel job if a real need arises; do not
  restructure what already works.
- **Signing secrets or credentials of any kind.** Never fabricate a
  keystore, API key, or credential. Release signing is CI-secret-injected
  only, via three repo secrets this repository never defines:
  `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`,
  `ANDROID_KEYSTORE_PASSWORD`.
- **The pinned Godot version or physics engine.** Godot 4.7.2 + built-in
  Jolt Physics stays the stack unless the CTO explicitly changes it.
- **Real ad/analytics SDK integration.** `AdsService`/`AnalyticsService`
  stay on their no-op/mock backends (`ads_backend.gd`,
  `analytics_backend.gd`) until the CTO explicitly approves swapping in
  a real SDK with real credentials.
- **Final production audio or visual art invented by the AI itself** —
  see §6-7 and the PERMANENT AUDIO ASSET RULE in `CLAUDE.md`.

## 5. Per-game startup procedure (exact commands)

This is what Phase 8 actually did, end to end, with zero local-machine
dependency. It assumes a GitHub MCP/tool surface equivalent to what this
session has; adjust tool names, not the sequence.

1. **The CTO creates the new repository.** Repo-creation is not
   available to the agent by default (`create_repository` returned a 403
   in Phase 8 — the GitHub App integration can only act on repos already
   granted to it). Ask the CTO to create a new **empty** repo (no
   README/.gitignore/license, so it stays truly empty) and tell you its
   owner/name, or to grant broader repo-creation access if they'd rather
   the agent create it directly.
2. **Attach and clone the new empty repo:**
   `add_repo` (owner, repo, access: push) → `git clone --depth 1 <new-repo-url> <local-dir>`.
3. **Import the full template history** (this is what makes it a real
   *clone*, not a fresh copy that loses provenance):
   ```
   cd <local-dir>
   git remote add template <path-or-url-to-godot-mobile-template>
   git fetch template main
   git checkout -b main template/main
   git remote remove template
   git push -u origin main
   ```
4. **Verify Foundation came through unchanged**, immediately, before any
   other work:
   ```
   diff -rq <path-to-source-template>/addons/core <local-dir>/addons/core
   ```
   This must report zero differences. Re-run it again right before every
   push for the rest of the task — it is the actual proof behind rule 1,
   not a one-time formality.
5. **Rename app identity** per §3's list (`project.godot`,
   `export_presets.cfg` both presets, workflow `EXPORT_NAME`) — proves
   genuine independence (a distinct Android package id), not just a
   content fork.
6. **Run the local baseline before adding any content:**
   `bash ci/run_tests.sh` (needs a local `godot` binary on PATH; if
   none is available, this step is skippable but the very next push's CI
   run becomes the first verification instead — expect to iterate).
   Confirm it's green against the freshly-cloned, identity-renamed repo
   before writing a single line of Gameplay or Presentation code.
7. **Proceed to the INPUT PACKAGE step (§6)** before implementing
   anything — do not start Gameplay/Presentation work without it.

## 6. Required handoff inputs for a new game (the INPUT PACKAGE)

Before implementation starts, the CTO supplies:

- **A game concept / design brief** — core loop, win/lose conditions,
  controls, the minimum needed to implement Gameplay meaningfully. No
  real game concept exists in the template or in Phase 8's dry-run; this
  has to come from the CTO.
- **A target visual reference package** — images, mockups, or a style
  reference for Presentation. Required before Presentation can be
  finalized; implement with clearly-marked neutral placeholders until it
  arrives (see §7), never invented final art.
- **Real audio files**, or an explicit sign-off to ship a specific
  milestone with TEMP placeholders — per the PERMANENT AUDIO ASSET RULE.
  AI-generated audio is never final production audio.
- **The new repo target** (owner/name of an existing empty repo per §5,
  or explicit instruction to request one be created).
- **Any monetization/analytics requirements**, understanding these stay
  on no-op/mock backends unless real SDK credentials are explicitly
  approved and supplied.
- **Physics/layer requirements**, if the game is physics-heavy — needed
  to extend the reserved collision-layer convention
  (`foundation_validator.gd`'s `check_physics_layer_convention()`,
  layers 1-8 reserved, see `docs/ARCHITECTURE.md` Phase 7) with what
  each layer actually means for this game.

If any of these are missing when a task starts, implement what's
possible with clearly-marked placeholders and explicitly flag exactly
what's blocking completion — never silently ship a placeholder as if it
were final, and never invent the missing input yourself.

## 7. Visual-package integration workflow

1. Receive the CTO-supplied target reference images.
2. Analyze them for palette, silhouette, material style, UI style, and
   layout — the things Presentation actually controls.
3. Rebuild `presentation/` to match: materials, models (or import
   CTO-supplied assets directly), the HUD theme (`hud_theme.tres` or a
   per-game equivalent), VFX bank entries. Gameplay code does not change
   for this — only the resource references Presentation supplies, the
   exact swap boundary `tests/test_mvp_gameplay_integration.gd` proves
   works.
4. Run the cloud build/test/screenshot pipeline (§9).
5. **Compare each screenshot checkpoint PNG against the corresponding
   target reference image.** This is a required step, not optional
   polish — see rule 6's pipeline order and rule 7's completion
   criteria. Iterate (fix Presentation, rebuild, re-screenshot) until
   each checkpoint is genuinely representative of the target reference,
   not a rough approximation and not a placeholder.
6. Never invent final visual design when target references are missing
   — implement functionally, mark placeholders clearly (e.g. a
   `Placeholder_`/`Greybox` naming convention, which
   `performance_validator.gd`'s `check_placeholder_markers()` already
   knows to flag in `addons/core/`/`scenes/` — extend that awareness
   into how you name placeholder content in `game/`/`presentation/`
   too, even though the validator itself doesn't scan those paths), and
   say explicitly that the visual package is still pending.

## 8. User-supplied audio workflow

Full rule: `CLAUDE.md`'s PERMANENT AUDIO ASSET RULE. Summary for this
document's context — when the CTO uploads audio:

1. Detect what each file is for (music, SFX, UI sound, ambience, etc.).
2. Convert/transcode, normalize, and trim silence if needed.
3. Loop music cleanly if it's meant to loop.
4. Import into Godot and connect it to the existing `AudioManager` (see
   `addons/core/audio/README.md`) — or, once it exists, an `AudioBank`
   (see the "Compliance status" note in `CLAUDE.md`: as of this writing,
   `AudioManager` still takes concrete `AudioStream` arguments directly
   rather than semantic IDs; closing that gap is its own scoped,
   CTO-approved task, not something to build silently mid-game-task).
5. If several candidates are supplied for the same purpose, pick the
   best technically suitable one and say explicitly which was used.
6. If a required sound is missing, use a neutral TEMP-marked placeholder
   — never a generated "final" substitute, and never a low-quality or
   unsettling AI-generated stand-in.

## 9. Cloud build / test / screenshot / APK workflow

Everything below runs in GitHub Actions, in the pinned `godot-ci`
container, on every push to `main` — no local machine involved at any
point (rule 8). Job names below match `.github/workflows/android-build.yml`
exactly.

- **`Automated Tests`** — `bash ci/run_tests.sh`: unit tests →
  content/foundation validators → scene smoke test, in that order, in
  one combined log. Gates every other job (`needs: run-tests`).
- **`Screenshot QA`** — `bash ci/capture_screenshots.sh`: boots
  `scenes/boot.tscn` under Xvfb + Mesa's software OpenGL renderer (real
  rendering, not `--headless` — see `docs/ARCHITECTURE.md` Phase 7) and
  captures a PNG at each defined checkpoint, uploaded as the
  `<EXPORT_NAME>-qa-screenshots` artifact.
- **`Android Debug Build`** — `ci/set_version.sh` (automatic
  `versionCode`/`versionName`) → `ci/export_android.sh`, uploaded as the
  `<EXPORT_NAME>-debug-apk` artifact. Runs on every push.
- **`Android Release Build (AAB)`** — same versioning, then
  `ci/export_android_release.sh`, uploaded as
  `<EXPORT_NAME>-release-aab`. Runs on tag pushes and manual dispatch,
  but every real step is gated on `ANDROID_KEYSTORE_BASE64` being
  configured — without it the job reports success with those steps
  skipped ("ready, blocked only by a missing secret"), never red, never
  silent.

**The required order for any real game task** (rule 6, verbatim):

```
INPUT PACKAGE
  → GAMEPLAY IMPLEMENTATION
  → PRESENTATION IMPLEMENTATION
  → CLOUD BUILD
  → TEST
  → SCREENSHOT CAPTURE
  → COMPARE AGAINST TARGET REFERENCES
  → FIX
  → APK
```

All artifacts (APK, AAB, screenshots) are retrieved from the GitHub
Actions run — via the API/MCP tools or the Actions UI — never by
building anything locally.

## 10. Failure-recovery workflow

1. **Read the actual job logs**, not just the conclusion. A green
   conclusion can still hide a real defect quietly degrading the build
   (Phase 6's Gradle cache silently caching nothing, and `versionName`
   silently falling back to `"unknown"`, were both discovered this way,
   on runs that had already gone green).
2. **Known, already-solved gotchas** — check these first before treating
   something as novel; each is documented in full in
   `docs/ARCHITECTURE.md`'s per-phase sections:
   - A `--script` bootstrap entry point (`godot --script <path>`, e.g.
     any `tests/*.gd`/`tools/*.gd` runner) cannot reference an autoload
     by its bare global name — `GameManager.foo()` fails to compile
     there. Use `root.get_node("Name")` instead. Normal scene/autoload
     scripts do not have this restriction.
   - GitHub Actions' `container:` jobs run every step with `HOME`
     redirected to `/github/home`, not the `godot-ci` image's own baked-in
     home — this is why export templates get explicitly `mv`'d into
     place, why the Android SDK path check in
     `ci/validate_environment.sh` is advisory rather than a hard
     assertion, and why `GRADLE_USER_HOME` is set explicitly rather than
     left to Gradle's own default resolution.
   - `actions/checkout`'s shallow clone is owned by a different
     filesystem user than the job's shell until checkout's own post-job
     step adds a `safe.directory` allowance — `git rev-parse` called
     mid-job (e.g. inside a versioning script) can silently fail before
     that happens. Prefer `$GITHUB_SHA`/other Actions-provided env vars
     over shelling out to `git` for anything that must work reliably
     mid-job.
   - Screenshot capture needs a real rendering context: Xvfb plus, at
     minimum, `libgl1-mesa-dri libglx-mesa0 libfontconfig1 libxcursor1
     libxi6 libxinerama1 libxrandr2` (the exact list `ci/capture_screenshots.sh`
     installs) — a `godot-ci` image built for headless export is not
     guaranteed to already have any of them. Never assume `--headless`
     works for a screenshot; it has no rendering context at all.
   - This template reserves collision bits 0-7 (layers 1-8) as its
     physics layer convention — using bit 8+ without first documenting
     what it means gets flagged by
     `foundation_validator.gd`'s `check_physics_layer_convention()`.
3. **Verify locally first when possible** — a local Xvfb/Mesa dry run of
   `ci/capture_screenshots.sh`, or a plain `bash ci/run_tests.sh`, before
   pushing catches real bugs (an autoload-global-name compile error, a
   wrong assertion) without spending a CI cycle. When no local Godot
   binary/Xvfb is available, say so explicitly rather than claiming
   local verification that didn't happen — the CI run becomes the first
   real verification instead.
4. **Fix, push, re-check — actually re-check, by reading the new run's
   logs, not by assuming the fix worked.** Repeat until every job is
   green. Never mark a task complete on a red CI run or a CI run whose
   logs weren't actually read.

## 11. Completion criteria for a real MVP

Do not declare a real game complete just because it compiles (rule 7).
Completion requires **all** of the following:

- [ ] Gameplay works — the core loop is actually playable, not just
      present in code.
- [ ] Physics works — collisions/movement behave as designed, using the
      documented layer convention.
- [ ] Controls work — input actually drives the gameplay as intended.
- [ ] Required screens work — main menu, settings, pause, and both
      result outcomes (or whatever the game's actual required-screen set
      is) all function.
- [ ] The target visual package is **actually implemented** — not a
      placeholder left in place after references arrived (rule 4).
- [ ] No shipping placeholders — no `TEMP`-marked audio, no
      `Placeholder_`/`Greybox`-named visuals, remaining in what would
      ship.
- [ ] Tests pass — the full suite, including any game-specific suites
      added under `tests/`.
- [ ] CI is green — every job, logs actually read, not just the
      conclusion.
- [ ] An APK is produced — the actual build artifact, downloaded/
      confirmed from the CI run.
- [ ] Screenshots have been visually checked against the target
      references (§7, §9) — not merely generated, actually compared.

## 12. Status table

| Path | Owns | Status |
|---|---|---|
| `project.godot`, `export_presets.cfg` | Engine/Android/Jolt config | Done (Phase 0); identity fields are the per-clone customization point (§3) |
| `scenes/boot.tscn` | Boot entry point | Done (Phase 0-7), placeholder content only — drives GameManager Boot -> MainMenu and instantiates HUDLayer; see §2 for its Gameplay/Foundation-seam status |
| `addons/core/state/` | GameManager (FSM), SceneRouter | Done (Phase 1); Result edges added Phase 3 |
| `addons/core/save/` | SaveSystem (versioned, atomic, migrating) | Done (Phase 1) |
| `addons/core/input/` | InputManager (gestures), InputProfile, VirtualJoystick | Done (Phase 2) |
| `addons/core/hud/` | HUDLayer, SafeArea, Settings screen, reusable widgets, Theme | Done (Phase 2); Result screen added Phase 3 |
| `addons/core/settings/` | PauseController, SettingsManager | Done (Phase 2) |
| `addons/core/audio/` | AudioManager, bus layout | Done (Phase 3); see §8 for the AudioBank gap |
| `addons/core/haptics/` | HapticsManager | Done (Phase 3) |
| `addons/core/result_flow/` | ResultFlowController, result screen | Done (Phase 3) |
| `addons/core/performance/` | PerformanceManager (LOW/HIGH presets) | Done (Phase 4) |
| `addons/core/pooling/` | PoolManager, VFXPool, VFXBank | Done (Phase 4) |
| `addons/core/analytics/` | AnalyticsService (generic API + Foundation-flow hooks) | Done (Phase 5); no real analytics SDK integrated |
| `addons/core/ads/` | AdsService (rewarded only), AdsBackend, MockAdsBackend | Done (Phase 5); no real ad SDK integrated |
| `tests/` | Unit suites (`run_tests.gd`) + scene smoke test (`run_smoke_test.gd`) | Done (Phase 1-7) — 19 suites, 158 tests, + auto-discovering smoke test over every `.tscn` under `addons/core/` and `scenes/` (9 scenes); append-only extension points, see §3 |
| `game/` | Per-game gameplay logic | Empty in the template. Phase 8's dry-run clone (a separate throwaway repo, not this one) proved the pattern with a minimal placeholder — see `docs/ARCHITECTURE.md` |
| `presentation/` | Per-game art/VFX/audio | Empty in the template, same Phase 8 note as above |
| `ci/` | Build environment + versioning/env-validation/export/QA scripts | Debug APK + release AAB paths (release gated on a signing secret), automatic versioning, Gradle cache, environment validation (Phase 6), screenshot capture (Phase 7) |
| `tools/validation/` | Content/Foundation validation rules (`performance_validator.gd`, `foundation_validator.gd`) + CI gate (`run_validation.gd`) | Done (Phase 4/6/7); see its own `README.md` for what each validator checks |
| `tools/qa/` | Screenshot QA (`screenshot_capture.gd`) | Done (Phase 7) — 5 checkpoints, own CI job, uploads PNG artifacts |
| `docs/ARCHITECTURE.md` | Build-relevant architecture notes, full phase-by-phase history | Living document |
| `docs/README_FOR_AI_AGENTS.md` | This document — the production handoff protocol | Finalized Phase 9 |

## 13. Known engine/CI gotchas — quick reference

(Full detail and root-cause writeups for every one of these live in
`docs/ARCHITECTURE.md`'s per-phase sections — this is a pointer list,
not the full explanation.)

1. Do not implement a phase/task out of order — later work assumes
   earlier Foundation systems exist; don't invent ad hoc versions of
   them inside `game/`.
2. Any change to the pinned build image (`ci/Dockerfile`) or Godot
   version must keep `project.godot`'s physics/rendering settings and
   `export_presets.cfg` in sync with whatever that Godot version
   actually expects — verify against the engine's own source for that
   exact tag, never assume settings carry over unchanged.
3. Never commit a keystore, keystore password, or any other signing
   secret (§4).
4. `ci/run_tests.sh` greps its combined output for the literal string
   `"SCRIPT ERROR"` as a safety net GDScript's lack of try/catch would
   otherwise leave open — a clean exit code alone is not enough if you
   ever run one of the three `--script` stages directly instead of
   through `ci/run_tests.sh`.
5. `ci/set_version.sh` overwrites `export_presets.cfg`'s `version/code`/
   `version/name` on every build — never hand-edit those two lines
   expecting them to stick.
6. The reserved physics layer convention (layers 1-8) — see §6, §10.
7. `--script` bootstrap files and bare autoload globals — see §10.
8. GitHub Actions `container:` jobs and `$HOME` redirection — see §10.
9. Screenshot capture needs Xvfb + specific Mesa/X11 libraries, never
   `--headless` — see §10.
