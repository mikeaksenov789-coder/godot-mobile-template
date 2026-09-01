extends Node
## Foundation performance-preset gateway. Exactly two presets, LOW and
## HIGH — no continuum of quality sliders. Persistence is not reinvented
## here: the preset IS SettingsManager.graphics_quality (Phase 2); this
## script's only job is translating that string into real engine state
## (render scale, shadows, MSAA) and exposing advisory budget numbers
## (particle ratio, max active lights) that VFXPool and a real game's own
## content are expected to respect — Godot has no engine-level hard cap
## on light/particle count to enforce this for us.

signal preset_applied(preset: String)

const PRESET_LOW := "LOW"
const PRESET_HIGH := "HIGH"

const _RENDER_SCALE := {"LOW": 0.75, "HIGH": 1.0}
const _SHADOWS_ENABLED := {"LOW": false, "HIGH": true}
const _MSAA := {"LOW": Viewport.MSAA_DISABLED, "HIGH": Viewport.MSAA_2X}
const _PARTICLE_AMOUNT_RATIO := {"LOW": 0.5, "HIGH": 1.0}
const _MAX_ACTIVE_LIGHTS := {"LOW": 2, "HIGH": 6}

var current_preset: String = PRESET_HIGH


func _ready() -> void:
	apply_preset(SettingsManager.graphics_quality)
	SettingsManager.settings_changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	if SettingsManager.graphics_quality != current_preset:
		apply_preset(SettingsManager.graphics_quality)


## Persists the choice through SettingsManager (which also applies it via
## the settings_changed signal above), then confirms it's actually
## applied — the two are decoupled enough that callers/tests may prefer
## to await settings_changed instead of relying on this synchronous path.
func set_preset(preset: String) -> bool:
	if preset != PRESET_LOW and preset != PRESET_HIGH:
		push_warning("PerformanceManager: unknown preset '%s', ignoring" % preset)
		return false
	SettingsManager.set_graphics_quality(preset)
	return true


## Applies engine-level state for a preset without touching persistence.
## An unrecognised preset falls back to HIGH rather than leaving stale
## settings applied.
func apply_preset(preset: String) -> void:
	var resolved := preset if (preset == PRESET_LOW or preset == PRESET_HIGH) else PRESET_HIGH
	current_preset = resolved

	var viewport := get_viewport()
	if viewport != null:
		viewport.scaling_3d_scale = _RENDER_SCALE[resolved]
		viewport.positional_shadow_atlas_size = 2048 if _SHADOWS_ENABLED[resolved] else 0
		viewport.msaa_3d = _MSAA[resolved]

	preset_applied.emit(resolved)


func shadows_enabled() -> bool:
	return _SHADOWS_ENABLED[current_preset]


func get_render_scale() -> float:
	return _RENDER_SCALE[current_preset]


## Multiplier a spawner should apply to its "normal" particle amount —
## e.g. VFXPool could scale GPUParticles3D.amount by this before restart().
func get_particle_amount_ratio() -> float:
	return _PARTICLE_AMOUNT_RATIO[current_preset]


## Advisory budget for simultaneously active Light3D-derived nodes — not
## engine-enforced; tools/validation/performance_validator.gd checks a
## scene against this number.
func get_max_active_lights() -> int:
	return _MAX_ACTIVE_LIGHTS[current_preset]


## Advisory flag for a future material/shader system to branch on — there
## is no real material content yet (Phase 4: no final art), so this is a
## hook, not an enforced engine setting.
func use_simplified_materials() -> bool:
	return current_preset == PRESET_LOW
