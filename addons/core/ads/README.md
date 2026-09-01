# Foundation — Rewarded-Ad Interface

Implemented — Phase 5 (Analytics & rewarded ads interfaces). Rewarded
ads only — no interstitial/banner in this phase's scope.

- `ads_backend.gd` — the base contract (`_is_rewarded_ready()`,
  `_show_rewarded()`), and also the actual wired-in default:
  `AdsService` starts with exactly this file, so `is_rewarded_ready()` is
  always `false` and a show request always fails gracefully with "no ad
  backend configured" — no real SDK, no credentials, no network call. A
  per-game backend overrides both methods (`extends
  "res://addons/core/ads/ads_backend.gd"`, no `class_name`) and swaps in
  via `AdsService.set_backend()`.
- `mock_ads_backend.gd` — a separate, **opt-in** development/testing
  backend (not the default) that can simulate readiness and outcome via
  `simulate_ready`/`simulate_success`/`simulate_failure_reason`, so
  `show_rewarded()` has something to demonstrate end-to-end, and so tests
  can exercise the success/failure paths deterministically.
- `ads_service.gd` (autoload `AdsService`) — `is_rewarded_ready(placement_id)`
  and `show_rewarded(placement_id)`. Gameplay must check readiness before
  offering a reward and must never assume an ad is available; every
  rejection (unknown placement, active frequency cap, backend not ready)
  is a graceful `rewarded_ad_failed` signal, never a crash. The actual
  outcome of an accepted `show_rewarded()` call always arrives via
  `rewarded_ad_completed`/`rewarded_ad_failed`, since a real ad SDK is
  inherently asynchronous.
- Per-game configuration hooks: `configure_placements(ids)` (an empty set
  means "accept any non-empty placement id", so a game that hasn't
  configured placements yet still works during development),
  `set_frequency_cap(seconds)` (minimum time between successful shows of
  the same placement — `0` means no cap), and `set_backend()`.

No real ad SDK is integrated, and no credentials/placement secrets exist
anywhere in this repo.

Tests: `tests/test_ads_service.gd`.
