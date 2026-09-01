extends RefCounted
## Base Analytics backend contract. This file IS the safe default — every
## method is a no-op — so `AnalyticsService` works out of the box with zero
## configuration and zero real analytics SDK. A per-game backend overrides
## these three methods (`extends
## "res://addons/core/analytics/analytics_backend.gd"`, no `class_name` —
## see docs/ARCHITECTURE.md on why cross-file types here are referenced by
## path instead) and is swapped in via `AnalyticsService.set_backend()`;
## nothing calling `AnalyticsService.log_event()`/etc. ever needs to change.


func _log_event(_name: String, _params: Dictionary) -> void:
	pass


func _set_user_property(_name: String, _value) -> void:
	pass


func _screen_view(_name: String) -> void:
	pass
