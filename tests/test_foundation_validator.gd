extends "res://tests/test_case.gd"
## Tests tools/validation/foundation_validator.gd — both against small
## synthetic fixtures (pass/fail cases for each rule) and against this
## repo's own real autoloads/theme, so the validator is actually
## exercised against real Foundation state, not just unit-tested in
## isolation.

var _validator
var _vfx_pool: Node


func setup() -> void:
	_validator = load("res://tools/validation/foundation_validator.gd")
	_vfx_pool = root.get_node("VFXPool")


func test_check_required_autoloads_against_real_root_finds_nothing_missing() -> void:
	var missing: Array[String] = _validator.check_required_autoloads(root)
	assert_true(missing.is_empty(), "every autoload project.godot registers should be present: %s" % [missing])


func test_check_required_autoloads_against_empty_root_flags_all() -> void:
	var empty_root := Node.new()
	var missing: Array[String] = _validator.check_required_autoloads(empty_root)
	assert_eq(missing.size(), _validator.REQUIRED_AUTOLOADS.size())
	empty_root.free()


func test_check_broken_references_flags_missing_ext_resource() -> void:
	var broken: Array[String] = _validator.check_broken_references(
		"res://tests/fixtures/broken_reference_scene.tscn"
	)
	assert_eq(broken.size(), 1)
	if broken.size() == 1:
		assert_eq(broken[0], "res://tests/fixtures/this_script_does_not_exist.gd")


func test_check_broken_references_passes_clean_scene() -> void:
	var broken: Array[String] = _validator.check_broken_references(
		"res://tests/fixtures/dummy_scene_a.tscn"
	)
	assert_true(broken.is_empty())


func test_check_broken_references_missing_file_returns_itself() -> void:
	var broken: Array[String] = _validator.check_broken_references(
		"res://tests/fixtures/does_not_exist_at_all.tscn"
	)
	assert_eq(broken.size(), 1)


func test_check_physics_layer_convention_passes_within_convention() -> void:
	var scene_root := Node3D.new()
	var body := StaticBody3D.new()
	body.collision_layer = 0b0000_0001  # layer 1 -- within the 8-bit convention
	body.collision_mask = 0b0000_0011   # layers 1-2
	scene_root.add_child(body)

	var flagged: Array[String] = _validator.check_physics_layer_convention(scene_root)
	assert_true(flagged.is_empty())
	scene_root.free()


func test_check_physics_layer_convention_flags_undocumented_layer_bit() -> void:
	var scene_root := Node3D.new()
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 10  # layer 11 -- outside the 8-bit convention
	scene_root.add_child(body)

	var flagged: Array[String] = _validator.check_physics_layer_convention(scene_root)
	assert_eq(flagged.size(), 1)
	scene_root.free()


func test_check_physics_layer_convention_flags_undocumented_mask_bit() -> void:
	var scene_root := Node3D.new()
	var area := Area3D.new()
	area.collision_mask = 1 << 12  # layer 13 -- outside the 8-bit convention
	scene_root.add_child(area)

	var flagged: Array[String] = _validator.check_physics_layer_convention(scene_root)
	assert_eq(flagged.size(), 1)
	scene_root.free()


func test_check_theme_resource_passes_against_real_hud_theme() -> void:
	var problems: Array[String] = _validator.check_theme_resource(
		"res://addons/core/hud/theme/hud_theme.tres"
	)
	assert_true(problems.is_empty(), "hud_theme.tres should already have Button/Panel styles: %s" % [problems])


func test_check_theme_resource_missing_file_reports_error() -> void:
	var problems: Array[String] = _validator.check_theme_resource(
		"res://addons/core/hud/theme/does_not_exist.tres"
	)
	assert_eq(problems.size(), 1)


func test_check_theme_resource_flags_an_empty_theme() -> void:
	var empty_theme := Theme.new()
	var problems: Array[String] = _validator._check_theme(empty_theme)
	assert_eq(problems.size(), 2, "an empty Theme is missing both the Button and Panel stylebox")


func test_check_bank_hooks_passes_with_real_root() -> void:
	var problems: Array[String] = _validator.check_bank_hooks(root)
	assert_true(problems.is_empty(), "the live VFXPool/audio buses should already be configured: %s" % [problems])


func test_check_bank_hooks_flags_a_missing_vfx_bank() -> void:
	var original_bank = _vfx_pool.bank
	_vfx_pool.bank = null

	var problems: Array[String] = _validator.check_bank_hooks(root)

	_vfx_pool.bank = original_bank
	assert_true(problems.has("VFXPool has no bank assigned"))


func test_validate_foundation_configuration_aggregates_every_check() -> void:
	var result: Dictionary = _validator.validate_foundation_configuration(root)
	assert_true(result.has("missing_autoloads"))
	assert_true(result.has("bank_hook_problems"))
	assert_true(result.has("theme_problems"))
	assert_true(result["missing_autoloads"].is_empty())
	assert_true(result["bank_hook_problems"].is_empty())
	assert_true(result["theme_problems"].is_empty())
