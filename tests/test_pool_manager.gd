extends "res://tests/test_case.gd"
## Tests the live PoolManager autoload with small synthetic PackedScenes
## built at runtime (PackedScene.pack()) — no fixture .tscn needed.

var _pm: Node


func setup() -> void:
	_pm = root.get_node("PoolManager")


func _make_pooled_scene() -> PackedScene:
	var node := Node3D.new()
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()
	return packed


func test_acquire_before_register_returns_null() -> void:
	var instance: Node = _pm.acquire("unregistered_pool_%d" % Time.get_ticks_usec())
	assert_eq(instance, null)


func test_register_pool_prewarms_available_instances() -> void:
	var pool_key := "prewarm_%d" % Time.get_ticks_usec()
	_pm.register_pool(pool_key, _make_pooled_scene(), 3, 0)
	assert_eq(_pm.get_pool_size(pool_key), 3)
	assert_eq(_pm.get_available_count(pool_key), 3)
	assert_eq(_pm.get_in_use_count(pool_key), 0)


func test_registering_the_same_pool_key_twice_is_a_no_op() -> void:
	var pool_key := "double_register_%d" % Time.get_ticks_usec()
	_pm.register_pool(pool_key, _make_pooled_scene(), 2, 0)
	_pm.register_pool(pool_key, _make_pooled_scene(), 5, 0)  # different scene/size, should be ignored
	assert_eq(_pm.get_pool_size(pool_key), 2)


func test_acquire_reuses_a_released_instance() -> void:
	var pool_key := "reuse_%d" % Time.get_ticks_usec()
	_pm.register_pool(pool_key, _make_pooled_scene(), 1, 0)

	var first: Node = _pm.acquire(pool_key)
	assert_not_null(first)
	_pm.release(pool_key, first)

	var second: Node = _pm.acquire(pool_key)
	assert_eq(second, first, "releasing then acquiring again must return the same instance, not a new one")
	assert_eq(_pm.get_pool_size(pool_key), 1, "reuse must not grow the pool")


func test_acquire_beyond_prewarm_grows_the_pool() -> void:
	var pool_key := "grow_%d" % Time.get_ticks_usec()
	_pm.register_pool(pool_key, _make_pooled_scene(), 1, 0)

	var grown_events: Array = []
	var callback := func(key, new_size): grown_events.append([key, new_size])
	_pm.pool_grew.connect(callback)

	var a: Node = _pm.acquire(pool_key)
	var b: Node = _pm.acquire(pool_key)  # pool only had 1 prewarmed — must grow
	_pm.pool_grew.disconnect(callback)

	assert_not_null(a)
	assert_not_null(b)
	assert_ne(a, b)
	assert_eq(_pm.get_pool_size(pool_key), 2)
	assert_eq(grown_events.size(), 1, "pool_grew should fire exactly once for the one instance that had to be created")


func test_capacity_is_respected_when_max_size_is_set() -> void:
	var pool_key := "capacity_%d" % Time.get_ticks_usec()
	_pm.register_pool(pool_key, _make_pooled_scene(), 0, 2)  # max 2, nothing prewarmed

	var a: Node = _pm.acquire(pool_key)
	var b: Node = _pm.acquire(pool_key)
	var c: Node = _pm.acquire(pool_key)  # over capacity

	assert_not_null(a)
	assert_not_null(b)
	assert_eq(c, null, "acquire() beyond max_size must return null, not silently grow past capacity")
	assert_eq(_pm.get_in_use_count(pool_key), 2)


func test_capacity_frees_up_after_release() -> void:
	var pool_key := "capacity_release_%d" % Time.get_ticks_usec()
	_pm.register_pool(pool_key, _make_pooled_scene(), 0, 1)

	var a: Node = _pm.acquire(pool_key)
	assert_eq(_pm.acquire(pool_key), null, "at capacity, a second acquire must fail")

	_pm.release(pool_key, a)
	var b: Node = _pm.acquire(pool_key)
	assert_eq(b, a, "after release, capacity should allow the same slot to be reacquired")


func test_release_of_instance_not_in_use_is_a_safe_no_op() -> void:
	var pool_key := "safe_release_%d" % Time.get_ticks_usec()
	_pm.register_pool(pool_key, _make_pooled_scene(), 1, 0)

	var stray := Node3D.new()
	_pm.release(pool_key, stray)  # never acquired — must not crash or corrupt the pool
	assert_eq(_pm.get_available_count(pool_key), 1, "releasing an unrelated node must not add it to the pool")
	stray.free()


func test_release_for_unregistered_pool_is_a_safe_no_op() -> void:
	var stray := Node3D.new()
	_pm.release("no_such_pool_%d" % Time.get_ticks_usec(), stray)  # must not crash
	stray.free()


func test_acquired_instance_becomes_visible_and_released_instance_hides() -> void:
	var pool_key := "visibility_%d" % Time.get_ticks_usec()
	_pm.register_pool(pool_key, _make_pooled_scene(), 1, 0)

	var instance: Node3D = _pm.acquire(pool_key)
	assert_true(instance.visible, "an acquired instance should be visible")

	_pm.release(pool_key, instance)
	assert_false(instance.visible, "a released instance should be hidden again")
