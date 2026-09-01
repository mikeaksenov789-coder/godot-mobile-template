extends SceneTree
## Headless scene-instantiation smoke test:
## `godot --headless --script res://tests/run_smoke_test.gd`
## Exits 0 if every discovered scene instantiated cleanly, 1 otherwise.
##
## Extracted out of tests/run_tests.gd in Phase 6 so the CI pipeline can
## run it as its own, separately-attributed stage, after the content
## validators (tools/validation/run_validation.gd) and the unit test
## suite — see ci/run_tests.sh for the combined ordering.
##
## Loads and instantiates every discovered scene under a temporary node,
## letting one frame pass so _ready() fully settles, then frees it. This
## catches a scene that fails to load/instantiate outright. It does NOT
## reliably catch a runtime script error mid-_ready() that doesn't null
## out the result (Phase 2's Array[String] bug did exactly this) — the CI
## workflow additionally greps this step's full output for "SCRIPT ERROR"
## as a second, complementary net (see docs/ARCHITECTURE.md).

## Roots recursively scanned for .tscn files — everything reusable a
## future phase might add lives under one of these. tests/fixtures/*.tscn
## are deliberately excluded: they're minimal test-only scenes, not
## template content worth re-verifying.
const SMOKE_TEST_ROOTS: Array[String] = [
	"res://addons/core",
	"res://scenes",
]


func _initialize() -> void:
	await process_frame

	var result: Dictionary = await _run_scene_smoke_tests()
	print("")
	print("Smoke test: %d scene(s), %d failed" % [result["total"], result["failed"]])
	quit(1 if result["failed"] > 0 else 0)


## Recursively collects every .tscn under SMOKE_TEST_ROOTS.
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


func _run_scene_smoke_tests() -> Dictionary:
	var scene_paths: Array[String] = []
	for scan_root in SMOKE_TEST_ROOTS:
		_find_scenes(scan_root, scene_paths)
	scene_paths.sort()

	print("== Scene instantiation smoke test (%d scenes) ==" % scene_paths.size())
	var passed := 0
	var failed := 0
	for scene_path in scene_paths:
		var packed = load(scene_path)
		if packed == null or not (packed is PackedScene):
			print("  FAIL  %s (failed to load as a PackedScene)" % scene_path)
			failed += 1
			continue

		var instance: Node = packed.instantiate()
		if instance == null:
			print("  FAIL  %s (instantiate() returned null)" % scene_path)
			failed += 1
			continue

		root.add_child(instance)
		await process_frame
		print("  PASS  %s" % scene_path)
		passed += 1
		instance.queue_free()
		await process_frame

	return {"passed": passed, "failed": failed, "total": scene_paths.size()}
