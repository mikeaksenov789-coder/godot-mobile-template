extends "res://tests/test_case.gd"
## Tests the live VFXPool autoload with a small synthetic GPUParticles3D
## PackedScene built at runtime — there is no shipped VFX asset yet
## (Phase 4: no final art), so a fixture is built in-process instead.
## Each test registers its VFX under a freshly generated id so pool state
## from one test can never leak into another via PoolManager's shared,
## singleton pool registry.

var _vfx: Node
var _pool: Node
var _bank
var _vfx_id: String


func setup() -> void:
	_vfx = root.get_node("VFXPool")
	_pool = root.get_node("PoolManager")
	_vfx_id = "test_burst_%d" % Time.get_ticks_usec()

	_bank = load("res://addons/core/pooling/vfx_bank.gd").new()
	_bank.register(_vfx_id, _make_particle_scene())
	_vfx.set_bank(_bank)
	_vfx._active = {}


func _make_particle_scene() -> PackedScene:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.amount = 8
	particles.lifetime = 0.05
	particles.one_shot = true
	particles.process_material = ParticleProcessMaterial.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.05, 0.05)
	particles.draw_pass_1 = mesh

	var packed := PackedScene.new()
	packed.pack(particles)
	particles.free()
	return packed


func test_play_unknown_vfx_id_returns_false_without_error() -> void:
	var ok: bool = _vfx.play("does_not_exist", Transform3D())
	assert_false(ok)
	assert_eq(_vfx.active_count(), 0)


func test_play_with_no_bank_set_returns_false() -> void:
	_vfx.set_bank(null)
	var ok: bool = _vfx.play(_vfx_id, Transform3D())
	assert_false(ok)


func test_play_registered_vfx_acquires_and_starts_a_pooled_instance() -> void:
	var at := Transform3D(Basis(), Vector3(1, 2, 3))
	var ok: bool = _vfx.play(_vfx_id, at)
	assert_true(ok)
	assert_eq(_vfx.active_count(), 1)
	assert_true(_pool.has_pool(_vfx_id))
	assert_eq(_pool.get_in_use_count(_vfx_id), 1)


func test_play_positions_the_instance_at_the_given_transform() -> void:
	var at := Transform3D(Basis(), Vector3(5, 6, 7))
	_vfx.play(_vfx_id, at)
	var record = _vfx._active.values()[0]
	var instance: Node3D = record["instance"]
	assert_true(instance.global_position.is_equal_approx(Vector3(5, 6, 7)))


func test_repeated_play_reuses_pooled_instances_not_new_ones() -> void:
	var seen_ids: Dictionary = {}
	for i in range(6):
		_vfx.play(_vfx_id, Transform3D())
		for record in _vfx._active.values():
			seen_ids[record["instance"].get_instance_id()] = true
		# Force the active effect to finish immediately so the next play()
		# in this loop must reuse it rather than acquiring a fresh one.
		for record in _vfx._active.values():
			record["timer"] = record["lifetime"]
		_vfx._process(0.0)

	assert_true(seen_ids.size() <= _pool.get_pool_size(_vfx_id),
		"repeated play() must reuse pooled instances, not keep creating new ones")
	assert_true(_pool.get_pool_size(_vfx_id) <= 4,
		"the pool should have stayed small (VFXPool's default initial size), not grown to 6")


func test_process_releases_finished_effects_back_to_the_pool() -> void:
	_vfx.play(_vfx_id, Transform3D())
	assert_eq(_pool.get_in_use_count(_vfx_id), 1)

	# Advance past the particle system's own lifetime + VFXPool's buffer.
	_vfx._process(1.0)

	assert_eq(_vfx.active_count(), 0)
	assert_eq(_pool.get_in_use_count(_vfx_id), 0)
	# The first play() prewarms the whole pool (VFXPool's default initial
	# size), so releasing the single played instance leaves every prewarmed
	# instance available, not just the one that was played.
	assert_eq(_pool.get_available_count(_vfx_id), _pool.get_pool_size(_vfx_id))


func test_process_does_not_release_an_effect_before_its_lifetime_elapses() -> void:
	_vfx.play(_vfx_id, Transform3D())
	_vfx._process(0.001)  # far short of lifetime (0.05) + buffer
	assert_eq(_vfx.active_count(), 1, "an effect must stay active until its lifetime has actually elapsed")
