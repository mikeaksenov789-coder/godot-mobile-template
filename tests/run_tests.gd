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
	quit(1 if total_failed_tests > 0 else 0)
