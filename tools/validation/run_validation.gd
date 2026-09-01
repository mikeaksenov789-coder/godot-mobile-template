extends SceneTree
## Headless content-validation gate:
## `godot --headless --script res://tools/validation/run_validation.gd`
## Exits 0 if every real scene and the Foundation's own configuration
## pass, 1 otherwise.
##
## This is deliberately a separate CI stage from tests/run_tests.gd
## (unit test behavior) and tests/run_smoke_test.gd (does a scene even
## instantiate) — it checks scene CONTENT and Foundation CONFIGURATION
## against performance_validator.gd (excessive lights, un-batched
## repeated meshes, leftover placeholder/greybox naming) and
## foundation_validator.gd (broken resource references, undocumented
## physics layer/mask bits, missing required autoloads, missing HUD
## theme styles, missing VFX/audio bank hooks). Today it always passes
## cleanly: game/ and presentation/ are still empty (no gameplay, no
## final art in this template), so there is nothing for the per-scene
## checks to flag — but it establishes the gate future content must
## pass, run on every CI build rather than only inside each validator's
## own unit tests.

const SCAN_ROOTS: Array[String] = [
	"res://addons/core",
	"res://scenes",
]


func _initialize() -> void:
	await process_frame

	var perf_validator = load("res://tools/validation/performance_validator.gd")
	var foundation_validator = load("res://tools/validation/foundation_validator.gd")
	var perf: Node = root.get_node("PerformanceManager")
	var max_lights: int = perf.get_max_active_lights()

	var scene_paths: Array[String] = []
	for scan_root in SCAN_ROOTS:
		_find_scenes(scan_root, scene_paths)
	scene_paths.sort()

	print("== Content validation (%d scenes, max_lights=%d) ==" % [scene_paths.size(), max_lights])
	var failed := 0
	for scene_path in scene_paths:
		var perf_result: Dictionary = perf_validator.validate_scene_file(scene_path, max_lights)
		if perf_result.has("error"):
			print("  FAIL  %s (%s)" % [scene_path, perf_result["error"]])
			failed += 1
			continue

		var excessive_lights: int = perf_result.get("excessive_lights", 0)
		var offenders: Dictionary = perf_result.get("repeated_mesh_offenders", {})
		var placeholders: Array = perf_result.get("placeholder_markers", [])
		var broken_refs: Array[String] = foundation_validator.check_broken_references(scene_path)

		var physics_flagged: Array[String] = []
		var packed = load(scene_path)
		if packed != null and packed is PackedScene:
			var instance: Node = packed.instantiate()
			physics_flagged = foundation_validator.check_physics_layer_convention(instance)
			instance.free()

		var scene_ok := (
			excessive_lights == 0 and offenders.is_empty() and placeholders.is_empty()
			and broken_refs.is_empty() and physics_flagged.is_empty()
		)
		if scene_ok:
			print("  PASS  %s" % scene_path)
		else:
			failed += 1
			print("  FAIL  %s -- excessive_lights=%d repeated_mesh_offenders=%d placeholder_markers=%d broken_refs=%d undocumented_physics_layers=%d" % [
				scene_path, excessive_lights, offenders.size(), placeholders.size(), broken_refs.size(), physics_flagged.size(),
			])
			for marker_path in placeholders:
				print("        placeholder marker: %s" % marker_path)
			for ref_path in broken_refs:
				print("        broken reference: %s" % ref_path)
			for node_path in physics_flagged:
				print("        undocumented physics layer/mask: %s" % node_path)

	print("")
	print("Content validation: %d scene(s), %d failed" % [scene_paths.size(), failed])

	print("")
	print("== Foundation configuration ==")
	var config_result: Dictionary = foundation_validator.validate_foundation_configuration(root)
	var config_failed := false
	for check_name in config_result:
		var problems: Array = config_result[check_name]
		if problems.is_empty():
			continue
		config_failed = true
		print("  FAIL  %s: %s" % [check_name, problems])
	if not config_failed:
		print("  PASS  autoloads, VFX/audio bank hooks, HUD theme")

	print("")
	print("Overall validation: %d scene failure(s), foundation config %s" % [
		failed, "FAILED" if config_failed else "OK",
	])
	quit(1 if (failed > 0 or config_failed) else 0)


## Recursively collects every .tscn under SCAN_ROOTS. Deliberately
## duplicated (not shared) with tests/run_smoke_test.gd's identical
## helper — this script and the smoke test are independent CI stages
## with different failure semantics, and this ~15-line helper is cheaper
## to keep local than to introduce a shared utility module for.
func _find_scenes(dir_path: String, results: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full_path := dir_path.path_join(entry)
			if dir.current_is_dir():
				_find_scenes(full_path, results)
			elif entry.ends_with(".tscn"):
				results.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
