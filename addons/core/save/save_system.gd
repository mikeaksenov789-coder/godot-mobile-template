extends Node
## Foundation save/load. Owns the on-disk envelope format and versioned
## migrations. Gameplay/UI code should go through get_game_payload() /
## set_game_payload() rather than touching the envelope directly, so
## Foundation-level fields can never be clobbered by a game's save data.
##
## Method names are write_save()/read_save(), not save()/load(): naming a
## Node method `load` collides with GDScript's global load() builtin at
## call sites and fails to compile, even though it's technically a
## different symbol — confirmed against this exact engine build.

const CURRENT_SCHEMA_VERSION: int = 2

signal save_written(success: bool)
## Emitted whenever read_save() had to fall back to a fresh envelope —
## `reason` distinguishes a normal missing-save (first run) from an actual
## corruption or unrecognised-version problem.
signal load_recovered(reason: String)

var save_path: String = "user://save.dat"


func _default_envelope() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"foundation": {},
		"game": {},
	}


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Atomic write: the envelope is written to a temp file first, then renamed
## over the real save path — a crash mid-write can never leave a
## half-written save file behind.
func write_save(envelope: Dictionary) -> bool:
	var to_write: Dictionary = envelope.duplicate(true)
	to_write["schema_version"] = CURRENT_SCHEMA_VERSION

	var tmp_path := save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: could not open %s for write (%s)" % [
			tmp_path, error_string(FileAccess.get_open_error()),
		])
		save_written.emit(false)
		return false
	file.store_string(JSON.stringify(to_write, "\t"))
	file.close()

	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		push_error("SaveSystem: could not open save directory %s" % save_path.get_base_dir())
		save_written.emit(false)
		return false
	var err := dir.rename(tmp_path.get_file(), save_path.get_file())
	if err != OK:
		push_error("SaveSystem: atomic rename failed (%s)" % error_string(err))
		save_written.emit(false)
		return false

	save_written.emit(true)
	return true


## Never throws/crashes on a bad file — missing, corrupted, or
## unrecognisable-version saves all fall back to a fresh default envelope.
func read_save() -> Dictionary:
	if not has_save():
		return _default_envelope()

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		load_recovered.emit("open failed: %s" % error_string(FileAccess.get_open_error()))
		return _default_envelope()
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK or not (json.get_data() is Dictionary):
		_backup_corrupted_file()
		load_recovered.emit("corrupted save file")
		return _default_envelope()

	var envelope: Dictionary = json.get_data()
	if not envelope.has("schema_version"):
		_backup_corrupted_file()
		load_recovered.emit("corrupted save file (missing schema_version)")
		return _default_envelope()

	return _migrate(int(envelope.get("schema_version", 0)), envelope)


func _migrate(version: int, envelope: Dictionary) -> Dictionary:
	var original_version := version
	if version == 1:
		envelope = _migrate_v1_to_v2(envelope)
		version = 2
	if version != CURRENT_SCHEMA_VERSION:
		_backup_corrupted_file()
		load_recovered.emit("unsupported schema_version %d" % version)
		return _default_envelope()
	if version != original_version:
		# Persist the upgrade so future loads start at the current version
		# instead of re-migrating every time.
		write_save(envelope)
	return envelope


## v1 had no Foundation/game split — the whole file was gameplay data
## nested under "game". v2 adds the Foundation/game separation Phase 1
## requires.
func _migrate_v1_to_v2(v1: Dictionary) -> Dictionary:
	return {
		"schema_version": 2,
		"foundation": {},
		"game": v1.get("game", {}),
	}


func _backup_corrupted_file() -> void:
	if not has_save():
		return
	var backup_path := "%s.corrupt.%d" % [save_path, Time.get_unix_time_from_system()]
	var raw := FileAccess.get_file_as_bytes(save_path)
	var backup := FileAccess.open(backup_path, FileAccess.WRITE)
	if backup == null:
		push_error("SaveSystem: could not write corruption backup to %s" % backup_path)
		return
	backup.store_buffer(raw)
	backup.close()


func get_game_payload() -> Dictionary:
	return read_save().get("game", {})


func set_game_payload(payload: Dictionary) -> bool:
	var envelope := read_save()
	envelope["game"] = payload
	return write_save(envelope)


func get_foundation_data() -> Dictionary:
	return read_save().get("foundation", {})


func set_foundation_data(data: Dictionary) -> bool:
	var envelope := read_save()
	envelope["foundation"] = data
	return write_save(envelope)
