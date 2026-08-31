extends RefCounted
## Minimal soft-assert test base class. No third-party test addon is used
## for this: Phase 1 needs exactly "run assertions headlessly in CI and
## fail the build on a red test", which this covers in ~60 lines without
## pinning an external dependency's version alongside the engine's.
##
## A suite does `extends "res://tests/test_case.gd"` (by path, not
## class_name — see tests/run_tests.gd for why), injects `root` (the
## running SceneTree's root, set by tests/run_tests.gd), and defines
## `test_*` methods plus an optional `setup()` re-run before each one.

var root: Node = null

var _failures: Array[String] = []


func reset() -> void:
	_failures = []


func get_failures() -> Array[String]:
	return _failures


## Override in a suite for per-test fixture setup (e.g. resetting a
## singleton's state). Called before every test_* method.
func setup() -> void:
	pass


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_failures.append("expected true but was false. %s" % message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_failures.append("expected false but was true. %s" % message)


func assert_eq(actual, expected, message: String = "") -> void:
	if actual != expected:
		_failures.append("expected <%s> but got <%s>. %s" % [expected, actual, message])


func assert_ne(actual, expected, message: String = "") -> void:
	if actual == expected:
		_failures.append("expected value to differ from <%s>. %s" % [expected, message])


func assert_not_null(value, message: String = "") -> void:
	if value == null:
		_failures.append("expected a non-null value. %s" % message)
