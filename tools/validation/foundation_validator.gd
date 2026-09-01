extends RefCounted
## Foundation-configuration and content-reference validators — a
## different concern from performance_validator.gd's rendering-budget
## checks. Static, stateless functions over either an already-booted
## SceneTree's root (autoload/bank checks) or a real file path
## (reference/theme checks). No `class_name`: called via
## `load(path).check_x(...)`, same as every other file here — see
## docs/ARCHITECTURE.md.

## Every autoload project.godot registers, in the order Phase 0-6
## established. A future phase adding a new Foundation autoload must add
## it here too, or this check silently stops covering it.
const REQUIRED_AUTOLOADS: Array[String] = [
	"GameManager", "SceneRouter", "SaveSystem", "SettingsManager",
	"PauseController", "InputManager", "AudioManager", "HapticsManager",
	"ResultFlowController", "PerformanceManager", "PoolManager", "VFXPool",
	"AnalyticsService", "AdsService",
]

## Physics layer convention: this template reserves collision bits 0-7
## (Godot layers 1-8) for whatever a future game documents them as; no
## gameplay ships real physics content yet, so nothing currently uses
## any of them. A CollisionObject using bit 8+ (layer 9+) on either
## collision_layer or collision_mask is flagged as undocumented — bits
## nobody has assigned a meaning to yet shouldn't quietly end up load-
## bearing in a shipped scene.
const ALLOWED_PHYSICS_LAYER_MASK := 0xFF


## Returns the names of any REQUIRED_AUTOLOADS missing as a direct child
## of `root` (the running SceneTree's root/Window).
static func check_required_autoloads(root: Node) -> Array[String]:
	var missing: Array[String] = []
	for autoload_name in REQUIRED_AUTOLOADS:
		if root.get_node_or_null(autoload_name) == null:
			missing.append(autoload_name)
	return missing


## Returns every res://-prefixed ext_resource path referenced by
## scene_path that does not actually resolve — a broken reference Godot
## itself would otherwise only surface as a runtime load error (or, for
## a sub-resource nested deep enough, not at all until something tries
## to use it). Reads the .tscn as text rather than instantiating it, so
## it works even when the top-level scene itself fails to load.
static func check_broken_references(scene_path: String) -> Array[String]:
	if not FileAccess.file_exists(scene_path):
		return [scene_path]
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return [scene_path]
	var text := file.get_as_text()
	file.close()

	var broken: Array[String] = []
	var regex := RegEx.new()
	regex.compile("path=\"(res://[^\"]+)\"")
	for regex_match in regex.search_all(text):
		var ref_path: String = regex_match.get_string(1)
		if not ResourceLoader.exists(ref_path):
			broken.append(ref_path)
	return broken


## Flags CollisionObject2D/3D nodes whose collision_layer or
## collision_mask sets a bit outside ALLOWED_PHYSICS_LAYER_MASK. Returns
## node paths relative to scene_root.
static func check_physics_layer_convention(scene_root: Node) -> Array[String]:
	var flagged: Array[String] = []
	_scan_physics_layers(scene_root, scene_root, flagged)
	return flagged


static func _scan_physics_layers(node: Node, scan_root: Node, flagged: Array[String]) -> void:
	if node is CollisionObject3D or node is CollisionObject2D:
		var layer: int = node.get("collision_layer")
		var mask: int = node.get("collision_mask")
		if (layer & ~ALLOWED_PHYSICS_LAYER_MASK) != 0 or (mask & ~ALLOWED_PHYSICS_LAYER_MASK) != 0:
			flagged.append(str(scan_root.get_path_to(node)))
	for child in node.get_children():
		_scan_physics_layers(child, scan_root, flagged)


## Pure check over an already-loaded Theme — split out from
## check_theme_resource() so it's testable against an in-memory Theme
## without a fixture file on disk.
static func _check_theme(theme: Theme) -> Array[String]:
	var problems: Array[String] = []
	if theme.get_stylebox_list("Button").is_empty():
		problems.append("Theme has no Button stylebox")
	if theme.get_stylebox_list("Panel").is_empty():
		problems.append("Theme has no Panel stylebox")
	return problems


## Returns problems with the theme resource at theme_path: missing file,
## fails to load as a Theme, or missing an expected Button/Panel style —
## the minimum a HUD screen actually draws with (see hud_theme.tres).
static func check_theme_resource(theme_path: String) -> Array[String]:
	if not ResourceLoader.exists(theme_path):
		return ["theme file not found: %s" % theme_path]
	var theme = load(theme_path)
	if theme == null or not (theme is Theme):
		return ["failed to load as a Theme: %s" % theme_path]
	return _check_theme(theme)


## Returns problems with the VFX/Audio bank hooks a real game is
## expected to wire up: VFXPool has no bank assigned, or one of the
## Foundation audio buses (see addons/core/audio/) is missing.
static func check_bank_hooks(root: Node) -> Array[String]:
	var problems: Array[String] = []

	var vfx_pool := root.get_node_or_null("VFXPool")
	if vfx_pool == null or vfx_pool.get("bank") == null:
		problems.append("VFXPool has no bank assigned")

	for bus_name in ["Master", "Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			problems.append("Audio bus missing: %s" % bus_name)

	return problems


## Aggregates the root-level (not per-scene) Foundation checks into one
## result dictionary — the "invalid Foundation configuration" gate.
static func validate_foundation_configuration(root: Node) -> Dictionary:
	return {
		"missing_autoloads": check_required_autoloads(root),
		"bank_hook_problems": check_bank_hooks(root),
		"theme_problems": check_theme_resource("res://addons/core/hud/theme/hud_theme.tres"),
	}
