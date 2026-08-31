# Architecture

This repo is the **Master Godot 3D Mobile Template** — the reusable
foundation every future Android MVP is cloned from. The full approved
design (layering, cloud build architecture, repo structure, automation
matrix, phased implementation plan) was delivered to the CTO as
`Master_Godot_3D_Mobile_Template.docx` and approved before any
implementation started. This file tracks build-relevant specifics as they
land; it does not restate the full spec.

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
