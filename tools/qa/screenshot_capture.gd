extends SceneTree
## Cloud CI screenshot QA: boots the real boot.tscn, drives GameManager/
## HUDLayer/ResultFlowController through five defined checkpoints, and
## saves a PNG of the actual rendered viewport at each one to
## res://screenshots/.
##
## Unlike every other tools/*.gd or tests/*.gd script in this repo, this
## one must NOT run under --headless: headless mode has no rendering
## context at all, so a screenshot taken there would be meaningless (or
## simply fail to produce real pixels). It is meant to be invoked as:
##   xvfb-run --auto-servernum godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script res://tools/qa/screenshot_capture.gd
## under a virtual X display (Xvfb) with Mesa's software (llvmpipe)
## OpenGL rasterizer — no real GPU and no local machine required, only a
## cloud CI runner. See docs/ARCHITECTURE.md Phase 7 for why
## GL Compatibility/OpenGL3 is forced here rather than the project's
## default Forward+ Mobile (Vulkan) renderer: Vulkan software
## rasterization (lavapipe) is a much less commonly pre-installed CI
## dependency than Mesa's OpenGL software path.
##
## Exits 1 if any checkpoint's PNG failed to save.

const OUTPUT_DIR := "res://screenshots"
const FRAME_SETTLE_COUNT := 5  # frames to let a UI change actually finish rendering before capture

var _captured: Array[String] = []
var _failed: Array[String] = []


func _initialize() -> void:
	await process_frame

	# Autoload global names (GameManager.foo(), PauseController.bar()) do
	# not resolve inside a --script bootstrap file — the same engine
	# quirk tests/run_tests.gd's own doc comment already documents (and
	# confirmed again empirically here: a bare `PauseController.pause()`
	# below fails with "Identifier not found" at compile time). Every
	# autoload is reached via `root.get_node("Name")` instead.
	var game_manager: Node = root.get_node("GameManager")
	var pause_controller: Node = root.get_node("PauseController")
	var result_flow: Node = root.get_node("ResultFlowController")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var boot_scene: PackedScene = load("res://scenes/boot.tscn")
	var boot_instance: Node = boot_scene.instantiate()
	root.add_child(boot_instance)
	await _settle()

	# 1. Boot / Main Menu — boot.gd's own _ready() already drove
	# GameManager Boot -> MainMenu synchronously, above.
	await _capture("01_boot_main_menu")

	# 2. Settings — HUDLayer.show_settings() is the same public entry
	# point the in-game pause overlay's Settings button calls.
	var hud: Node = boot_instance.get_node("HUD")
	hud.show_settings()
	await _settle()
	await _capture("02_settings")
	hud.hide_settings()
	await _settle()

	# 3. Pause — PauseController.pause() is what the HUD's pause button
	# calls; HUDLayer shows the overlay automatically via its own
	# PauseController.paused signal connection.
	pause_controller.pause()
	await _settle()
	await _capture("03_pause")
	pause_controller.resume()
	await _settle()

	# 4. Result: Victory — show_result() requires GameManager to be in
	# Playing, so drive it there first exactly like a real game would
	# leaving MainMenu/Loading to start a run.
	game_manager.transition_to(game_manager.State.LOADING)
	game_manager.transition_to(game_manager.State.PLAYING)
	result_flow.show_result({
		"outcome": result_flow.OUTCOME_VICTORY,
		"retry_scene_path": "res://tests/fixtures/dummy_scene_a.tscn",
		"main_menu_scene_path": "res://tests/fixtures/dummy_scene_a.tscn",
	})
	await _settle()
	await _capture("04_result_victory")

	# 5. Result: Failure — Result only allows Loading/MainMenu as its
	# next edges, so route back through Loading -> Playing (what
	# ResultFlowController.retry()/next() do internally) before showing
	# a second result.
	game_manager.transition_to(game_manager.State.LOADING)
	game_manager.transition_to(game_manager.State.PLAYING)
	result_flow.show_result({
		"outcome": result_flow.OUTCOME_FAILURE,
		"main_menu_scene_path": "res://tests/fixtures/dummy_scene_a.tscn",
	})
	await _settle()
	await _capture("05_result_failure")

	print("")
	print("Screenshots captured: %d, failed: %d" % [_captured.size(), _failed.size()])
	for entry in _captured:
		print("  OK    %s" % entry)
	for entry in _failed:
		print("  FAIL  %s" % entry)
	quit(1 if not _failed.is_empty() else 0)


func _settle() -> void:
	for i in range(FRAME_SETTLE_COUNT):
		await process_frame


func _capture(checkpoint_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	var out_path := "%s/%s.png" % [OUTPUT_DIR, checkpoint_name]
	var err := image.save_png(out_path)
	if err == OK:
		_captured.append(checkpoint_name)
	else:
		_failed.append("%s (save_png error %d)" % [checkpoint_name, err])
