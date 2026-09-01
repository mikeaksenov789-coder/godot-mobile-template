# Godot Mobile Template

Master reusable Godot 4.x Android mobile-game template. Cloud-first build,
Jolt physics, git as the single source of truth. See
`docs/ARCHITECTURE.md` for current status and `docs/README_FOR_AI_AGENTS.md`
before extending this repo.

**Status: Phase 6 — Cloud Build Pipeline Hardening.** Foundation systems
through Phase 5 (state/save, input/HUD/pause/settings, audio/haptics/
result flow, performance/pooling, analytics/rewarded-ads interfaces) are
implemented and tested; Phase 6 hardened the cloud build pipeline itself
— automatic versioning, Gradle caching, environment validation, a
structurally-ready (but unsigned) release AAB path, and a clear
tests -> validators -> smoke test -> build -> upload CI order. Still no
gameplay, no final art — see `docs/ARCHITECTURE.md` for the full phase
history and `docs/README_FOR_AI_AGENTS.md` before extending this repo.
