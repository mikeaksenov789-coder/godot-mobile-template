extends "res://tests/test_case.gd"
## Tests the live SceneRouter autoload against small fixture scenes under
## tests/fixtures/ — no real menu/gameplay scenes exist yet (Phase 2+).

const FIXTURE_A := "res://tests/fixtures/dummy_scene_a.tscn"
const FIXTURE_B := "res://tests/fixtures/dummy_scene_b.tscn"
const FIXTURE_REENTRANT := "res://tests/fixtures/dummy_scene_reentrant.tscn"
const FIXTURE_MISSING := "res://tests/fixtures/does_not_exist.tscn"

var _router: Node


func setup() -> void:
	_router = root.get_node("SceneRouter")
	_router.is_loading = false


func test_goto_scene_swaps_current_scene() -> void:
	var ok: bool = _router.goto_scene(FIXTURE_A)
	assert_true(ok, "goto_scene should succeed for a valid fixture")
	assert_not_null(_router.get_current_scene())
	if _router.get_current_scene() != null:
		assert_eq(_router.get_current_scene().name, "DummySceneA")
	assert_false(_router.is_loading, "is_loading must be false once the swap has completed")


func test_goto_scene_replaces_previous_scene() -> void:
	_router.goto_scene(FIXTURE_A)
	var first_instance: Node = _router.get_current_scene()
	_router.goto_scene(FIXTURE_B)
	assert_eq(_router.get_current_scene().name, "DummySceneB")
	assert_true(first_instance.is_queued_for_deletion(),
		"the previous scene should be queued for deletion after a swap")


func test_goto_scene_rejects_missing_resource() -> void:
	var ok: bool = _router.goto_scene(FIXTURE_MISSING)
	assert_false(ok, "goto_scene must fail safely for a nonexistent path")
	assert_false(_router.is_loading, "a failed load must not leave the guard stuck on")


func test_loading_guard_rejects_reentrant_call() -> void:
	var ok: bool = _router.goto_scene(FIXTURE_REENTRANT)
	assert_true(ok, "the outer goto_scene call should still succeed")

	var current: Node = _router.get_current_scene()
	assert_not_null(current)
	if current != null:
		assert_eq(current.name, "DummySceneReentrant",
			"the reentrant inner call must not have won the swap")
		assert_eq(current.reentrant_call_result, false,
			"goto_scene called from within _ready() while loading must be rejected")
	assert_false(_router.is_loading, "guard must be clear after the outer call finishes")
