extends Node
## Test fixture only. Calls SceneRouter.goto_scene() reentrantly from
## _ready() — which fires synchronously inside the outer goto_scene()'s
## add_child() call — to verify the loading guard rejects the overlap.

var reentrant_call_result: Variant = null


func _ready() -> void:
	reentrant_call_result = SceneRouter.goto_scene("res://tests/fixtures/dummy_scene_b.tscn")
