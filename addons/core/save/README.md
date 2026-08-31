# Foundation — Save

Implemented — Phase 1 (Core state & save).

- `save_system.gd` — versioned JSON save envelope (`schema_version` +
  separated `foundation`/`game` blocks), atomic write (temp file + rename),
  safe load (missing/corrupted/unrecognised-version saves all fall back to
  a fresh envelope, with corrupted files backed up rather than discarded),
  and a working v1→v2 migration as the concrete example. Autoload name:
  `SaveSystem`. Gameplay/UI code should use `get_game_payload()` /
  `set_game_payload()`, not the raw envelope.

Tests: `tests/test_save_system.gd`.
