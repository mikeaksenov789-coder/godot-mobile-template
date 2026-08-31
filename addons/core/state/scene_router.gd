extends Node
## Foundation scene-loading gateway. This is the ONLY place that swaps the
## active scene — gameplay/UI code calls `goto_scene(path)` instead of
## `get_tree().change_scene_to_file()` directly, so loading is always
## guarded (no overlapping/reentrant loads) and validated (bad paths fail
## safely instead of crashing the tree).
##
## The swap is synchronous. `is_loading` still matters: `add_child()` runs a
## new node's `_enter_tree()`/`_ready()` immediately, in the same call
## stack — if that node's own `_ready()` called `goto_scene()` again (e.g.
## a misbehaving scene), the guard rejects that reentrant call instead of
## trying to mutate the tree while it's mid-swap (which the engine itself
## would refuse: "Parent node is busy setting up children").

signal scene_load_started(path: String)
signal scene_load_finished(path: String)
signal scene_load_failed(path: String, reason: String)

var is_loading: bool = false

var _current_scene: Node = null


func _ready() -> void:
	# Adopt whatever run/main_scene the engine already booted (boot.tscn)
	# so the first goto_scene() call replaces it correctly instead of
	# leaving two top-level scenes attached.
	_current_scene = get_tree().current_scene


func goto_scene(path: String) -> bool:
	if is_loading:
		push_warning("SceneRouter: goto_scene(%s) rejected — a load is already in progress." % path)
		return false
	if not ResourceLoader.exists(path):
		scene_load_failed.emit(path, "resource does not exist: %s" % path)
		return false
	var resource: Resource = ResourceLoader.load(path)
	if not (resource is PackedScene):
		scene_load_failed.emit(path, "resource is not a PackedScene: %s" % path)
		return false

	is_loading = true
	scene_load_started.emit(path)

	var packed_scene: PackedScene = resource
	var instance: Node = packed_scene.instantiate()
	var previous_scene := _current_scene

	get_tree().root.add_child(instance)
	get_tree().current_scene = instance
	_current_scene = instance

	if previous_scene != null and is_instance_valid(previous_scene):
		previous_scene.queue_free()

	is_loading = false
	scene_load_finished.emit(path)
	return true


func get_current_scene() -> Node:
	return _current_scene
