# Foundation — Input

Implemented — Phase 2 (Input, HUD, pause & settings).

- `input_manager.gd` (autoload `InputManager`) — normalizes raw touch
  into tap/hold/drag/swipe/pinch gestures, and resolves them through the
  current `InputProfile` into `action_triggered(action_name, position)`.
  Real events arrive via `_input()`; the same `feed_touch_event()` /
  `advance_time()` entry points are what tests (and any future scripted
  input) use.
- `input_profile.gd` — the swappable gesture-to-action mapping Resource
  (no `class_name`; see `docs/ARCHITECTURE.md`). `default_input_profile.tres`
  is the out-of-the-box mapping `InputManager` loads on `_ready()`.
- `virtual_joystick.gd` (+ `.tscn`) — a reusable on-screen virtual control
  hook: emits `joystick_input(direction, strength)` while dragged. Visual
  placeholder only; logic is visual-agnostic and swappable.

Tests: `tests/test_input_manager.gd`, `tests/test_input_profile.gd`,
`tests/test_virtual_joystick.gd`.
