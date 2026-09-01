extends Resource
## Maps semantic VFX ids to pooled particle scenes. A game supplies its
## own VFXBank (or extends this template's empty default) — Foundation
## knows nothing about what "explosion" or "hit_spark" should look like.
## No `class_name`: see docs/ARCHITECTURE.md on why cross-file types here
## are referenced by path/`load()` instead.

@export var entries: Dictionary = {}  # vfx_id (String) -> PackedScene


func get_scene(vfx_id: String) -> PackedScene:
	return entries.get(vfx_id, null)


func register(vfx_id: String, scene: PackedScene) -> void:
	entries[vfx_id] = scene


func has_vfx(vfx_id: String) -> bool:
	return entries.has(vfx_id)
