# Foundation — State

Implemented — Phase 1 (Core state & save).

- `game_manager.gd` — the top-level finite-state machine (Boot / MainMenu /
  Loading / Playing / Paused / Result). Autoload name: `GameManager`.
- `scene_router.gd` — the single sanctioned entry point for swapping the
  active scene (`goto_scene(path)`), with a loading guard against
  overlapping/reentrant loads. Autoload name: `SceneRouter`.

Tests: `tests/test_game_manager.gd`, `tests/test_scene_router.gd`.

Still out of scope here (later phases): pause/settings UI wiring
(Phase 2), Result Flow retry/back-to-menu transitions (Phase 3).
