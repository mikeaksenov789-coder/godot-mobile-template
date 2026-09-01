# Foundation — Object/VFX Pooling

Implemented — Phase 4 (Performance & pooling).

- `pool_manager.gd` (autoload `PoolManager`) — generic object pooling
  keyed by an arbitrary string pool key. `register_pool(key, scene,
  initial_size, max_size)` prewarms `initial_size` instances up front;
  `acquire()`/`release()` reuse those instances instead of any hot-loop
  `instantiate()`/`free()`. `acquire()` grows the pool on demand past
  its prewarm size (firing `pool_grew`) up to `max_size` (0 = unbounded),
  returning `null` once at capacity rather than silently over-allocating.
  Re-registering an existing key is a no-op — first registration wins.
  An acquired instance is made visible; a released one is hidden and
  returned to the available list (a released instance not currently in
  use, or a release against an unregistered key, is a safe no-op).
- `vfx_bank.gd` — a plain `Resource` (no `class_name`, loaded by path)
  mapping a `vfx_id: String` to a `PackedScene`, so a game can ship its
  own VFX bank without touching `VFXPool` itself.
  `default_vfx_bank.tres` is an empty bank wired up by default; Phase 4
  ships no final VFX art, so there is nothing to register yet.
- `vfx_pool.gd` (autoload `VFXPool`) — `play(vfx_id, transform)` looks
  `vfx_id` up in the current bank, lazily registers a `PoolManager` pool
  for it on first use, acquires a pooled `GPUParticles3D`-based instance,
  positions it at `transform`, and starts it emitting. `_process()`
  tracks each active effect's elapsed time against its `lifetime` (plus
  a small buffer) and releases it back to the pool once finished — no
  effect is ever freed, only recycled. `set_bank()` swaps banks (e.g.
  between games); a missing bank or unknown `vfx_id` fails `play()`
  gracefully (`false`, no active effect), it never errors.

Tests: `tests/test_pool_manager.gd`, `tests/test_vfx_pool.gd`.
