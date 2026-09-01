extends SceneTree
## Headless content-validation gate:
## `godot --headless --script res://tools/validation/run_validation.gd`
## Exits 0 if every real scene passes its performance/content budget, 1
## otherwise.
##
## This is deliberately a separate CI stage from tests/run_tests.gd
## (unit test behavior) and tests/run_smoke_test.gd (does a scene even
## instantiate) — it checks scene CONTENT against
## performance_validator.gd's budgets (excessive lights, un-batched
## repeated meshes, leftover placeholder/greybox naming). Today it always
## passes cleanly: game/ and presentation/ are still empty (no gameplay,
## no final art in this template), so there is nothing for it to flag —
## but it establishes the gate future content must pass, run on every CI
## build from Phase 6 onward rather than only inside
## tests/test_performance_validator.gd's own unit tests.

const SCAN_ROOTS: Array[String] = [
	"res://addons/core",
	"res://scenes",
]


func _initialize() -> void:
	await process_frame

	var validator = load("res://tools/validation/performance_validator.gd")
	var perf: Node = root.get_node("PerformanceManager")
	var max_lights: int = perf.get_max_active_lights()

	var scene_paths: Array[String] = []
	for scan_root in SCAN_ROOTS:
		_find_scenes(scan_root, scene_paths)
	scene_paths.sort()

	print("== Content validation (%d scenes, max_lights=%d) ==" % [scene_paths.size(), max_lights])
	var failed := 0
	for scene_path in scene_paths:
		var result: Dictionary = validator.validate_scene_file(scene_path, max_lights)
		if result.has("error"):
			print("  FAIL  %s (%s)" % [scene_path, result["error"]])
			failed += 1
			continue

		var excessive_lights: int = result.get("excessive_lights", 0)
		var offenders: Dictionary = result.get("repeated_mesh_offenders", {})
		var placeholders: Array = result.get("placeholder_markers", [])

		if excessive_lights > 0 or not offenders.is_empty() or not placeholders.is_empty():
			failed += 1
			print("  FAIL  %s -- excessive_lights=%d repeated_mesh_offenders=%d placeholder_markers=%d" % [
				scene_path, excessive_lights, offenders.size(), placeholders.size(),
			])
			for marker_path in placeholders:
				print("        placeholder marker: %s" % marker_path)
		else:
			print("  PASS  %s" % scene_path)

	print("")
	print("Content validation: %d scene(s), %d failed" % [scene_paths.size(), failed])
	quit(1 if failed > 0 else 0)


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
