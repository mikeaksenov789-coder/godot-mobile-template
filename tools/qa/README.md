# Automated Screenshot QA

Implemented — Phase 7 (Automated validation & screenshot QA).

- `screenshot_capture.gd` — `godot --path . --rendering-method
  gl_compatibility --rendering-driver opengl3 --script
  res://tools/qa/screenshot_capture.gd`, run under a virtual X display
  (Xvfb). Unlike every other `tools/*.gd`/`tests/*.gd` script in this
  repo, this one must **not** run under `--headless`: headless mode has
  no rendering context, so a screenshot taken there would be blank or
  fail outright. Boots the real `scenes/boot.tscn`, drives
  GameManager/HUDLayer/ResultFlowController through five checkpoints,
  and saves a PNG of the actual rendered viewport at each one to
  `res://screenshots/` (gitignored — a CI/local output directory, not a
  repository asset):
  1. `01_boot_main_menu` — the app straight after boot.
  2. `02_settings` — `HUDLayer.show_settings()`.
  3. `03_pause` — `PauseController.pause()`.
  4. `04_result_victory` — `ResultFlowController.show_result({"outcome":
     "victory", ...})`.
  5. `05_result_failure` — the same, `"outcome": "failure"`.

  Every checkpoint is reached the same way a real player would (the
  same public methods the HUD's own buttons call), not by reaching into
  private state. `--script` bootstrap files can't reference autoload
  globals directly (`GameManager.foo()` fails to compile there — the
  same engine quirk `tests/run_tests.gd` documents), so this script
  reaches every autoload via `root.get_node("Name")`, confirmed the hard
  way: an early local dry-run hit exactly that compile error.
- `ci/capture_screenshots.sh` installs Xvfb and a Mesa software OpenGL
  renderer if the pinned `godot-ci` image doesn't already have them (it
  is built for headless export, not visual rendering, so neither is
  guaranteed), then runs the capture script under `xvfb-run`. Verified
  end-to-end in this sandbox before ever reaching CI: Mesa's llvmpipe
  software rasterizer produced five real, correctly-rendered 1080x2340
  PNGs (not blank frames) — see `docs/ARCHITECTURE.md` Phase 7 for why
  `gl_compatibility`/`opengl3` is forced rather than the project's
  default Forward+ Mobile (Vulkan) renderer.
- Wired into CI as its own job (`Screenshot QA`, parallel with the
  Android builds, gated only on the test suite passing) that uploads the
  five PNGs as a workflow artifact — no local machine involved.

No test suite: this is a QA/visual-inspection tool, not something with a
pass/fail assertion surface beyond "did every checkpoint actually
produce a PNG," which `ci/capture_screenshots.sh` itself checks
(`screenshot_capture.gd` exits 1 if any `save_png()` call fails).
