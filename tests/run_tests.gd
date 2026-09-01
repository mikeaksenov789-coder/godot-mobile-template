extends SceneTree
## Headless test runner: `godot --headless --script res://tests/run_tests.gd`
## Exits 0 if every test passed, 1 otherwise — wired into CI as a required
## step that gates the Android build.
##
## No autoload global-name access here (e.g. `GameManager.foo()`) — that
## binding only resolves inside normal project scripts, not in the
## --script bootstrap file itself (confirmed against this engine build).
## Suites instead reach singletons via `root.get_node("Name")`, using the
## injected `root` reference.
##
## Suites are also loaded/extended by string path (`extends
## "res://tests/test_case.gd"`), not by `class_name` — global class names
## aren't resolved yet on a fresh checkout with no .godot/ cache, which is
## exactly the state every CI run starts from (confirmed against this
## engine build).

const SUITE_SCRIPTS: Array[String] = [
	"res://tests/test_game_manager.gd",
	"res://tests/test_scene_router.gd",
	"res://tests/test_save_system.gd",
	"res://tests/test_input_manager.gd",
	"res://tests/test_input_profile.gd",
	"res://tests/test_virtual_joystick.gd",
	"res://tests/test_safe_area.gd",
	"res://tests/test_pause_controller.gd",
	"res://tests/test_settings_manager.gd",
	"res://tests/test_audio_manager.gd",
	"res://tests/test_haptics_manager.gd",
	"res://tests/test_result_flow_controller.gd",
]

## Roots recursively scanned for .tscn files by the scene-instantiation
## smoke test — everything reusable a future phase might add lives under
## one of these. tests/fixtures/*.tscn are deliberately excluded: they're
## minimal test-only scenes, not template content worth re-verifying.
const SMOKE_TEST_ROOTS: Array[String] = [
	"res://addons/core",
	"res://scenes",
]


func _initialize() -> void:
	# A node's get_tree() returns null until one frame after this custom
	# SceneTree's _initialize() starts — confirmed against this engine
	# build. Autoloads (SceneRouter) call get_tree() internally, so tests
	# must not run before this yields once.
	await process_frame

	var total_tests := 0
	var total_failed_tests := 0
	var total_failed_assertions := 0

	for suite_path in SUITE_SCRIPTS:
		var suite_script: GDScript = load(suite_path)
		var suite = suite_script.new()
		suite.root = root

		var test_names: Array[String] = []
		for method_info in suite.get_method_list():
			var method_name: String = method_info["name"]
			if method_name.begins_with("test_"):
				test_names.append(method_name)
		test_names.sort()

		print("== %s (%d tests) ==" % [suite_path.get_file(), test_names.size()])
		for test_name in test_names:
			suite.reset()
			suite.setup()
			suite.callv(test_name, [])
			# queue_free() (SceneRouter's previous-scene cleanup) only
			# actually removes the node at end of frame — without this,
			# stale nodes pile up under root and the next test's
			# add_child() silently auto-renames around the collision.
			await process_frame
			total_tests += 1

			var failures = suite.get_failures()
			if failures.is_empty():
				print("  PASS  %s" % test_name)
			else:
				total_failed_tests += 1
				total_failed_assertions += failures.size()
				print("  FAIL  %s" % test_name)
				for failure in failures:
					print("        - %s" % failure)

	print("")
	print("Suites: %d, tests: %d, failed tests: %d, failed assertions: %d" % [
		SUITE_SCRIPTS.size(), total_tests, total_failed_tests, total_failed_assertions,
	])

	var smoke_result: Dictionary = await _run_scene_smoke_tests()
	total_failed_tests += smoke_result["failed"]

	print("")
	print("Overall: %d failed test(s)" % total_failed_tests)
	quit(1 if total_failed_tests > 0 else 0)


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


## Loads and instantiates every discovered scene under a temporary node,
## letting one frame pass so _ready() fully settles, then frees it. This
## catches a scene that fails to load/instantiate outright. It does NOT
## reliably catch a runtime script error mid-_ready() that doesn't null
## out the result (Phase 2's Array[String] bug did exactly this) — the CI
## workflow additionally greps this step's full output for "SCRIPT ERROR"
## as a second, complementary net (see docs/ARCHITECTURE.md).
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
