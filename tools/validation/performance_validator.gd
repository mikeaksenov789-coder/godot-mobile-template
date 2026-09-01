extends RefCounted
## Performance/content budget checks over an already-instantiated scene
## tree. Pure static functions over a Node — no filesystem access in the
## core checks — so they're unit testable against small synthetic
## fixtures; validate_scene_file() is a thin wrapper for scanning a real
## .tscn path. No `class_name`: called via `load(path).check_x(...)`
## (confirmed to work against this engine build without one).
##
## This does not run as a gate against real production content yet —
## game/ and presentation/ are still empty (Phase 4's own scope excludes
## gameplay/final art). It runs in CI as part of the normal test suite:
## tests/test_performance_validator.gd exercises it both against
## synthetic fixtures and against this repo's own real scenes.

const LIGHT_CLASSES := ["OmniLight3D", "SpotLight3D", "DirectionalLight3D"]
const MESH_REPETITION_THRESHOLD := 20
const PLACEHOLDER_MARKERS := ["placeholder", "greybox", "TODO_ART", "TEMP_ART"]


## Returns every Light3D-derived node in the tree if their count exceeds
## max_lights, or an empty array if the budget is respected.
static func check_light_budget(root: Node, max_lights: int) -> Array[Node]:
	var lights: Array[Node] = []
	_collect_by_class(root, LIGHT_CLASSES, lights)
	if lights.size() > max_lights:
		return lights
	return []


## Returns {mesh_instance_id (as String): count} for any Mesh resource
## used by more than MESH_REPETITION_THRESHOLD separate MeshInstance3D
## nodes — a signal that MultiMeshInstance3D should be used instead.
static func check_repeated_mesh_instances(root: Node) -> Dictionary:
	var mesh_instances: Array[Node] = []
	_collect_by_class(root, ["MeshInstance3D"], mesh_instances)

	var counts: Dictionary = {}
	for node in mesh_instances:
		var mesh: Mesh = node.mesh
		if mesh == null:
			continue
		var key := str(mesh.get_instance_id())
		counts[key] = counts.get(key, 0) + 1

	var offenders: Dictionary = {}
	for key in counts.keys():
		if counts[key] > MESH_REPETITION_THRESHOLD:
			offenders[key] = counts[key]
	return offenders


## Returns node paths (relative to root) whose name contains a
## placeholder/greybox marker — meant for production scenes (game/,
## presentation/) that should have real content by the time they ship.
static func check_placeholder_markers(root: Node) -> Array[String]:
	var flagged: Array[String] = []
	_scan_for_markers(root, root, flagged)
	return flagged


static func _scan_for_markers(node: Node, scan_root: Node, flagged: Array[String]) -> void:
	var haystack: String = node.name.to_lower()
	for marker in PLACEHOLDER_MARKERS:
		if haystack.contains(marker.to_lower()):
			flagged.append(str(scan_root.get_path_to(node)))
			break
	for child in node.get_children():
		_scan_for_markers(child, scan_root, flagged)


static func _collect_by_class(node: Node, class_names: Array, results: Array[Node]) -> void:
	for cls in class_names:
		if node.is_class(cls):
			results.append(node)
			break
	for child in node.get_children():
		_collect_by_class(child, class_names, results)


## Loads, instantiates, checks, and frees scene_path in one call — for
## scanning a real .tscn without the caller managing the instance.
static func validate_scene_file(scene_path: String, max_lights: int) -> Dictionary:
	var packed = load(scene_path)
	if packed == null or not (packed is PackedScene):
		return {"error": "failed to load %s as a PackedScene" % scene_path}

	var instance: Node = packed.instantiate()
	var result := {
		"scene_path": scene_path,
		"excessive_lights": check_light_budget(instance, max_lights).size(),
		"repeated_mesh_offenders": check_repeated_mesh_instances(instance),
		"placeholder_markers": check_placeholder_markers(instance),
	}
	instance.free()
	return result
