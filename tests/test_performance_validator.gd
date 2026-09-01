extends "res://tests/test_case.gd"
## Tests tools/validation/performance_validator.gd — both against small
## synthetic in-memory scene trees (pass/fail cases for each rule) and
## against this repo's own real scenes, so the validator is actually
## exercised in CI, not just unit-tested in isolation.

var _validator
var _perf: Node


func setup() -> void:
	_validator = load("res://tools/validation/performance_validator.gd")
	_perf = root.get_node("PerformanceManager")


func _make_root() -> Node3D:
	var root_node := Node3D.new()
	return root_node


func test_light_budget_passes_when_within_budget() -> void:
	var scene_root := _make_root()
	scene_root.add_child(OmniLight3D.new())
	scene_root.add_child(OmniLight3D.new())

	var result: Array = _validator.check_light_budget(scene_root, 3)
	assert_true(result.is_empty(), "2 lights against a budget of 3 should not be flagged")
	scene_root.free()


func test_light_budget_flags_every_light_when_exceeded() -> void:
	var scene_root := _make_root()
	for i in range(5):
		scene_root.add_child(OmniLight3D.new())

	var result: Array = _validator.check_light_budget(scene_root, 3)
	assert_eq(result.size(), 5, "an over-budget scene should report every light, not just the excess")
	scene_root.free()


func test_light_budget_counts_mixed_light_types() -> void:
	var scene_root := _make_root()
	scene_root.add_child(OmniLight3D.new())
	scene_root.add_child(SpotLight3D.new())
	scene_root.add_child(DirectionalLight3D.new())

	var result: Array = _validator.check_light_budget(scene_root, 2)
	assert_eq(result.size(), 3, "Omni/Spot/Directional lights must all count toward the same budget")
	scene_root.free()


func test_repeated_mesh_instances_passes_under_threshold() -> void:
	var scene_root := _make_root()
	var mesh := BoxMesh.new()
	for i in range(5):
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		scene_root.add_child(mi)

	var offenders: Dictionary = _validator.check_repeated_mesh_instances(scene_root)
	assert_true(offenders.is_empty(), "5 shared-mesh instances is well under the repetition threshold")
	scene_root.free()


func test_repeated_mesh_instances_flags_over_threshold() -> void:
	var scene_root := _make_root()
	var mesh := BoxMesh.new()
	var threshold: int = _validator.MESH_REPETITION_THRESHOLD
	for i in range(threshold + 5):
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		scene_root.add_child(mi)

	var offenders: Dictionary = _validator.check_repeated_mesh_instances(scene_root)
	assert_eq(offenders.size(), 1, "all instances share one mesh, so exactly one offending mesh should be reported")
	if offenders.size() == 1:
		assert_eq(offenders.values()[0], threshold + 5)
	scene_root.free()


func test_repeated_mesh_instances_does_not_conflate_different_meshes() -> void:
	var scene_root := _make_root()
	var mesh_a := BoxMesh.new()
	var mesh_b := SphereMesh.new()
	var threshold: int = _validator.MESH_REPETITION_THRESHOLD
	for i in range(threshold + 1):
		var mi_a := MeshInstance3D.new()
		mi_a.mesh = mesh_a
		scene_root.add_child(mi_a)
	for i in range(3):
		var mi_b := MeshInstance3D.new()
		mi_b.mesh = mesh_b
		scene_root.add_child(mi_b)

	var offenders: Dictionary = _validator.check_repeated_mesh_instances(scene_root)
	assert_eq(offenders.size(), 1, "only the over-threshold mesh should be flagged, not the under-threshold one")
	scene_root.free()


func test_placeholder_markers_flags_named_nodes() -> void:
	var scene_root := _make_root()
	var rock := Node3D.new()
	rock.name = "Placeholder_Rock"
	scene_root.add_child(rock)
	var greybox := Node3D.new()
	greybox.name = "GreyboxWall"
	scene_root.add_child(greybox)

	var flagged: Array[String] = _validator.check_placeholder_markers(scene_root)
	assert_eq(flagged.size(), 2)
	scene_root.free()


func test_placeholder_markers_passes_clean_tree() -> void:
	var scene_root := _make_root()
	var prop := Node3D.new()
	prop.name = "StoneWall"
	scene_root.add_child(prop)

	var flagged: Array[String] = _validator.check_placeholder_markers(scene_root)
	assert_true(flagged.is_empty())
	scene_root.free()


func test_validate_scene_file_missing_file_returns_error() -> void:
	var result: Dictionary = _validator.validate_scene_file("res://tools/validation/does_not_exist.tscn", 6)
	assert_true(result.has("error"))


func test_validate_scene_file_against_real_boot_scene_is_clean() -> void:
	# This repo's own boot.tscn has no lights, no repeated meshes, and no
	# placeholder-named nodes — running the validator against it exercises
	# the file-loading path against real project content, in CI, not just
	# synthetic fixtures.
	var result: Dictionary = _validator.validate_scene_file("res://scenes/boot.tscn", _perf.get_max_active_lights())
	assert_false(result.has("error"))
	assert_eq(result.get("excessive_lights"), 0)
	assert_true(result.get("repeated_mesh_offenders", {}).is_empty())
	assert_true(result.get("placeholder_markers", []).is_empty())
