# Godot Mobile Template

Master reusable Godot 4.x Android mobile-game template. Cloud-first build,
Jolt physics, git as the single source of truth. See
`docs/ARCHITECTURE.md` for current status and `docs/README_FOR_AI_AGENTS.md`
before extending this repo.

**Status: Phase 9 — AI Agent Production Handoff.** Foundation systems
through Phase 5 (state/save, input/HUD/pause/settings, audio/haptics/
result flow, performance/pooling, analytics/rewarded-ads interfaces) are
implemented and tested; Phase 6 hardened the cloud build pipeline
(automatic versioning, Gradle caching, environment validation, a
structurally-ready but unsigned release AAB path); Phase 7 finalized
automated content/configuration validation and added cloud-CI screenshot
QA (five checkpoints rendered under a virtual display, uploaded as PNG
artifacts on every build); Phase 8 proved the whole pipeline end to end
by actually cloning this template into a separate throwaway repository
with a minimal placeholder Gameplay/Presentation layer — zero CI fix
cycles needed, zero local-machine dependency; Phase 9 turned that proven
pipeline into `docs/README_FOR_AI_AGENTS.md`'s full production handoff
protocol (exact clone procedure, required inputs, visual/audio
integration workflows, MVP completion checklist). Still no gameplay, no
final art in this template itself — see `docs/ARCHITECTURE.md` for the
full phase history and `docs/README_FOR_AI_AGENTS.md` before starting a
real game from this template.
