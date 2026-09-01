# Foundation — Result Flow

Implemented — Phase 3 (Audio, haptics & result flow).

- `result_flow_controller.gd` (autoload `ResultFlowController`) — accepts
  a generic result payload (`{"outcome": "victory"|"failure", ...optional
  scene paths}`), drives `GameManager` Playing -> Result, and Retry/Next
  (-> Loading) / Main Menu (-> MainMenu) back out through `SceneRouter`.
  Has no concept of score, level, or any other gameplay-specific field —
  see the payload contract documented at the top of the script.
- `result_screen.gd` (+ `.tscn`) — the reusable result screen: shows
  Retry/Main Menu/Next only for the scene paths actually present in the
  payload, theme-driven via `hud_theme.tres`. Owned/shown by `HUDLayer`
  (`addons/core/hud/hud_layer.gd`) in reaction to `result_shown`, the same
  lazy-instantiate pattern as the Settings/Pause screens.

`GameManager`'s transition table (`addons/core/state/game_manager.gd`)
gained the two edges out of Result this phase was always going to add:
`Result -> Loading` (Retry/Next) and `Result -> MainMenu`.

Tests: `tests/test_result_flow_controller.gd`, plus
`tests/test_game_manager.gd`'s updated Result-state test.
