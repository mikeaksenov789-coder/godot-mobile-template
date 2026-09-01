extends Node
## Foundation VFX playback via pooled GPUParticles3D instances, built on
## PoolManager. A game supplies a VFXBank Resource (vfx_id -> PackedScene)
## via set_bank(); play(vfx_id, transform) acquires a pooled instance,
## positions it, restarts its particles, and auto-releases it back to the
## pool once its lifetime elapses — gameplay code never instances a
## GPUParticles3D itself.

const DEFAULT_BANK_PATH := "res://addons/core/pooling/default_vfx_bank.tres"

const _DEFAULT_POOL_SIZE := 4
const _DEFAULT_MAX_POOL_SIZE := 16

var bank: Resource = null

var _active: Dictionary = {}  # instance_id -> {vfx_id, instance, timer, lifetime}


func _ready() -> void:
	bank = load(DEFAULT_BANK_PATH)


func set_bank(new_bank: Resource) -> void:
	bank = new_bank


## Returns true if a pooled instance was found and started; false if
## vfx_id isn't registered in the current bank, or that VFX's pool is at
## capacity — either way, this never crashes on a missing/invalid id.
func play(vfx_id: String, at: Transform3D) -> bool:
	if bank == null:
		return false
	var scene: PackedScene = bank.get_scene(vfx_id)
	if scene == null:
		return false

	if not PoolManager.has_pool(vfx_id):
		PoolManager.register_pool(vfx_id, scene, _DEFAULT_POOL_SIZE, _DEFAULT_MAX_POOL_SIZE)

	var instance: Node = PoolManager.acquire(vfx_id)
	if instance == null:
		return false

	if instance is Node3D:
		instance.global_transform = at
	if instance is GPUParticles3D:
		instance.amount_ratio = PerformanceManager.get_particle_amount_ratio()
		instance.restart()
		instance.emitting = true

	_active[instance.get_instance_id()] = {
		"vfx_id": vfx_id,
		"instance": instance,
		"timer": 0.0,
		"lifetime": _estimate_lifetime(instance),
	}
	return true


func _estimate_lifetime(instance: Node) -> float:
	if instance is GPUParticles3D:
		return instance.lifetime + 0.2  # small buffer past the particle system's own lifetime
	return 1.0


func _process(delta: float) -> void:
	if _active.is_empty():
		return
	var finished: Array = []
	for id in _active.keys():
		var record: Dictionary = _active[id]
		record["timer"] += delta
		if record["timer"] >= record["lifetime"]:
			finished.append(id)
	for id in finished:
		var record: Dictionary = _active[id]
		var instance: Node = record["instance"]
		if instance is GPUParticles3D:
			instance.emitting = false
		PoolManager.release(record["vfx_id"], instance)
		_active.erase(id)


func active_count() -> int:
	return _active.size()
