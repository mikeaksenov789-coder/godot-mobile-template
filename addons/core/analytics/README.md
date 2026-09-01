# Foundation — Analytics Interface

Implemented — Phase 5 (Analytics & rewarded ads interfaces).

- `analytics_backend.gd` — the base contract (`_log_event()`,
  `_set_user_property()`, `_screen_view()`), and also literally the safe
  default: every method is a no-op, so `AnalyticsService` works with zero
  configuration and zero real analytics SDK. A per-game backend overrides
  these three methods (`extends
  "res://addons/core/analytics/analytics_backend.gd"`, no `class_name` —
  see `docs/ARCHITECTURE.md`) and swaps in via `AnalyticsService.set_backend()`;
  no caller changes.
- `analytics_service.gd` (autoload `AnalyticsService`) — the generic API
  gameplay/UI ever calls: `log_event(name, params)`,
  `set_user_property(name, value)`, `screen_view(name)`. An empty name is
  rejected (returns `false`) rather than forwarded to the backend.
  `last_event_name`/`last_event_params`/`last_user_property_*`/
  `last_screen_name`/`event_log` exist purely for test/debug observability
  — there is no real backend to inspect otherwise, the same reasoning
  behind `HapticsManager`'s `last_triggered_kind`/`trigger_count`.
- Also wires itself into existing Foundation flows, entirely inside its
  own `_ready()` — no other system knows analytics exists:
  - **app boot** — logs `"app_boot"` once, in `_ready()` itself.
  - **screen/state transitions** — listens to `GameManager.state_changed`
    and calls `screen_view()` with the new state's name.
  - **pause/resume** — listens to `PauseController.paused`/`resumed` and
    logs `"game_paused"`/`"game_resumed"`.
  - **result shown** — listens to `ResultFlowController.result_shown` and
    logs `"result_shown"` with the outcome.
  - **retry / next / main menu** — listens to
    `ResultFlowController.retry_requested`/`next_requested`/
    `main_menu_requested` and logs the matching event with the scene path.

No real analytics SDK (Firebase or otherwise) is integrated, and no
credentials exist anywhere in this repo — that remains a later,
CTO-approved integration, plugged in purely by swapping the backend.

Tests: `tests/test_analytics_service.gd`.
