# Godot Mobile Template

Master reusable Godot 4.x Android mobile-game template. Cloud-first build,
Jolt physics, git as the single source of truth. See
`docs/ARCHITECTURE.md` for current status and `docs/README_FOR_AI_AGENTS.md`
before extending this repo.

**Status: Phase 7 — Automated Validation & Screenshot QA.** Foundation
systems through Phase 5 (state/save, input/HUD/pause/settings, audio/
haptics/result flow, performance/pooling, analytics/rewarded-ads
interfaces) are implemented and tested; Phase 6 hardened the cloud build
pipeline (automatic versioning, Gradle caching, environment validation, a
structurally-ready but unsigned release AAB path); Phase 7 finalized
automated content/configuration validation (broken references, required
autoloads, physics layer convention, HUD theme, VFX/audio bank hooks) and
added cloud-CI screenshot QA — five checkpoints (Boot/Main Menu,
Settings, Pause, Result Victory, Result Failure) rendered under a virtual
display and uploaded as PNG artifacts on every build. Still no gameplay,
no final art — see `docs/ARCHITECTURE.md` for the full phase history and
`docs/README_FOR_AI_AGENTS.md` before extending this repo.
