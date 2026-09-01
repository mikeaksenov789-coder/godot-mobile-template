# Foundation — Haptics

Implemented — Phase 3 (Audio, haptics & result flow).

- `haptics_manager.gd` (autoload `HapticsManager`) — five semantic calls
  (`light()`, `medium()`, `heavy()`, `success()`, `failure()`) wrapping
  `Input.vibrate_handheld()`, each with its own tuned duration. Gated by
  `SettingsManager.vibration_enabled`. There's no way to observe real
  device vibration headlessly, so `last_triggered_kind`/`trigger_count`/
  `haptic_triggered` exist specifically so the gating and dispatch logic
  stays testable without a device.

Tests: `tests/test_haptics_manager.gd`.
