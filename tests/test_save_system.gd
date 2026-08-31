extends "res://tests/test_case.gd"
## Tests the live SaveSystem autoload against an isolated test save path
## (never the real user://save.dat), cleaned before every test.

var _save: Node
var _test_dir: String = "user://test_save_system"


func setup() -> void:
	_save = root.get_node("SaveSystem")
	DirAccess.make_dir_recursive_absolute(_test_dir)
	_clear_test_dir()
	_save.save_path = _test_dir + "/save.dat"


func _clear_test_dir() -> void:
	var dir := DirAccess.open(_test_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _has_corrupt_backup() -> bool:
	var dir := DirAccess.open(_test_dir)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.contains(".corrupt."):
			dir.list_dir_end()
			return true
		file_name = dir.get_next()
	dir.list_dir_end()
	return false


## JSON has no int type — everything round-trips as float. Normalizing the
## expected value through the same round trip is what makes an equality
## assertion on save/load output honest instead of fighting that quirk.
func _json_roundtrip(value: Dictionary) -> Dictionary:
	var json := JSON.new()
	json.parse(JSON.stringify(value))
	return json.get_data()


func test_save_then_load_round_trips_equal() -> void:
	var payload := {"score": 42, "level": 3, "name": "phase1", "tags": ["a", "b"]}
	assert_true(_save.set_game_payload(payload), "set_game_payload should succeed")
	var reloaded: Dictionary = _save.get_game_payload()
	assert_eq(reloaded, _json_roundtrip(payload))


func test_foundation_and_game_payload_are_separate() -> void:
	var foundation_data := {"settings": {"volume": 0.5}}
	var game_data := {"score": 7}
	_save.set_foundation_data(foundation_data)
	_save.set_game_payload(game_data)

	var envelope: Dictionary = _save.read_save()
	assert_eq(envelope.get("foundation"), _json_roundtrip(foundation_data))
	assert_eq(envelope.get("game"), _json_roundtrip(game_data))


func test_missing_save_returns_defaults_without_error() -> void:
	assert_false(_save.has_save(), "no save should exist in a freshly cleared test dir")
	var envelope: Dictionary = _save.read_save()
	assert_eq(envelope.get("schema_version"), _save.CURRENT_SCHEMA_VERSION)
	assert_eq(envelope.get("game"), {})
	assert_eq(envelope.get("foundation"), {})


func test_corrupted_save_recovers_to_defaults_and_backs_up() -> void:
	var file := FileAccess.open(_save.save_path, FileAccess.WRITE)
	file.store_string("{this is not valid json")
	file.close()

	# A lambda captures outer locals by value, not by reference — a plain
	# `var recovered_reason := ""` reassigned inside the callback would
	# never be visible out here (confirmed against this engine build).
	# Appending to a shared Array works, since Array is a reference type.
	var recovered_reasons: Array = []
	var callback := func(reason): recovered_reasons.append(reason)
	_save.load_recovered.connect(callback)
	var envelope: Dictionary = _save.read_save()
	_save.load_recovered.disconnect(callback)

	assert_eq(envelope.get("game"), {}, "a corrupted save must fall back to a fresh envelope")
	assert_eq(recovered_reasons.size(), 1, "load_recovered should fire exactly once")
	if recovered_reasons.size() == 1:
		assert_ne(recovered_reasons[0], "", "load_recovered should fire with a non-empty reason")
	assert_true(_has_corrupt_backup(), "a corrupted save must be backed up, not silently discarded")


func test_missing_schema_version_is_treated_as_corrupted() -> void:
	var file := FileAccess.open(_save.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"game": {"score": 1}}))
	file.close()

	var envelope: Dictionary = _save.read_save()
	assert_eq(envelope.get("schema_version"), _save.CURRENT_SCHEMA_VERSION)
	assert_eq(envelope.get("game"), {}, "a save with no schema_version can't be trusted, so it's discarded")
	assert_true(_has_corrupt_backup())


func test_schema_migration_v1_to_v2() -> void:
	var v1_envelope := {"schema_version": 1, "game": {"coins": 100}}
	var file := FileAccess.open(_save.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(v1_envelope))
	file.close()

	var migrated: Dictionary = _save.read_save()
	assert_eq(migrated.get("schema_version"), _save.CURRENT_SCHEMA_VERSION)
	assert_eq(migrated.get("foundation"), {}, "v1 -> v2 migration must add an empty foundation block")
	assert_eq(migrated.get("game"), _json_roundtrip({"coins": 100}),
		"v1 game payload must survive migration untouched")

	# The migration result must be persisted, not just returned in-memory —
	# a second read should already be at the current version.
	var reread: Dictionary = _save.read_save()
	assert_eq(reread.get("schema_version"), _save.CURRENT_SCHEMA_VERSION)
	assert_eq(reread.get("game"), _json_roundtrip({"coins": 100}))


func test_unsupported_future_schema_version_falls_back_to_defaults() -> void:
	var future_envelope := {"schema_version": 99, "game": {"score": 1}}
	var file := FileAccess.open(_save.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(future_envelope))
	file.close()

	var envelope: Dictionary = _save.read_save()
	assert_eq(envelope.get("schema_version"), _save.CURRENT_SCHEMA_VERSION)
	assert_eq(envelope.get("game"), {},
		"an unrecognised (e.g. newer-than-known) schema_version must not be guessed at")
	assert_true(_has_corrupt_backup())


func test_atomic_write_leaves_no_tmp_file_behind() -> void:
	_save.set_game_payload({"x": 1})
	assert_false(FileAccess.file_exists(_save.save_path + ".tmp"),
		"write_save must not leave its temp file behind after a successful rename")
