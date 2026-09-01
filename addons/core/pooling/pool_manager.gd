extends Node
## Foundation generic object pool. Register a pool by key with a
## PackedScene factory; acquire()/release() reuse instances instead of
## instantiate()/free() churn in a hot loop (projectiles, short-lived
## VFX, enemies). VFXPool (this same folder) is a specialised consumer of
## this same mechanism for GPUParticles3D specifically.

## Emitted when acquire() has to instantiate a new instance because the
## pool had nothing available — useful for spotting a pool whose initial
## size should be raised.
signal pool_grew(pool_key: String, new_size: int)

var _pools: Dictionary = {}  # pool_key -> {scene, available: Array, in_use: Array, max_size: int}


func has_pool(pool_key: String) -> bool:
	return _pools.has(pool_key)


## Creates an empty pool for `pool_key` if one doesn't already exist, and
## pre-warms it with `initial_size` instances up front so the first
## acquire() in a hot loop doesn't pay an instantiate() cost.
## max_size <= 0 means unbounded.
func register_pool(pool_key: String, scene: PackedScene, initial_size: int = 0, max_size: int = 0) -> void:
	if _pools.has(pool_key):
		return
	_pools[pool_key] = {"scene": scene, "available": [], "in_use": [], "max_size": max_size}
	for i in range(initial_size):
		_pools[pool_key]["available"].append(_instantiate_for(pool_key))


## Returns a reused (or freshly instantiated, if none were available)
## instance, or null if the pool is at its configured max_size.
func acquire(pool_key: String) -> Node:
	if not _pools.has(pool_key):
		push_warning("PoolManager: acquire() for unregistered pool '%s'" % pool_key)
		return null

	var pool: Dictionary = _pools[pool_key]
	var instance: Node

	if pool["available"].is_empty():
		var max_size: int = pool["max_size"]
		if max_size > 0 and pool["in_use"].size() >= max_size:
			return null
		instance = _instantiate_for(pool_key)
		pool_grew.emit(pool_key, pool["in_use"].size() + 1)
	else:
		instance = pool["available"].pop_back()

	_set_pooled_visible(instance, true)
	pool["in_use"].append(instance)
	return instance


## Returns `instance` to its pool for reuse. A no-op if `instance` isn't
## currently checked out of `pool_key` (already released, or never
## acquired from it) — release() is safe to call defensively.
func release(pool_key: String, instance: Node) -> void:
	if not _pools.has(pool_key):
		return
	var pool: Dictionary = _pools[pool_key]
	if not pool["in_use"].has(instance):
		return
	pool["in_use"].erase(instance)
	_set_pooled_visible(instance, false)
	pool["available"].append(instance)


func get_pool_size(pool_key: String) -> int:
	if not _pools.has(pool_key):
		return 0
	var pool: Dictionary = _pools[pool_key]
	return pool["available"].size() + pool["in_use"].size()


func get_in_use_count(pool_key: String) -> int:
	if not _pools.has(pool_key):
		return 0
	return _pools[pool_key]["in_use"].size()


func get_available_count(pool_key: String) -> int:
	if not _pools.has(pool_key):
		return 0
	return _pools[pool_key]["available"].size()


func _instantiate_for(pool_key: String) -> Node:
	var pool: Dictionary = _pools[pool_key]
	var instance: Node = pool["scene"].instantiate()
	add_child(instance)
	_set_pooled_visible(instance, false)
	return instance


## visible isn't a universal Node property (only CanvasItem/Node3D have
## it) — a pooled object doesn't have to be visual, so this guards rather
## than assuming.
func _set_pooled_visible(instance: Node, is_visible: bool) -> void:
	if instance is CanvasItem or instance is Node3D:
		instance.visible = is_visible
