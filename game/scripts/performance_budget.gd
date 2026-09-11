extends RefCounted

const MAX_ENEMIES := 420
const MAX_PROJECTILES := 720
const MAX_EFFECTS := 320
const MAX_DAMAGE_NUMBERS := 120

var quality_scale := 1.0
var last_frame_ms := 0.0
var overload_frames := 0

func sample(frame_ms: float, enemy_count: int, projectile_count: int) -> void:
	last_frame_ms = frame_ms
	var overloaded := frame_ms > 22.0 or enemy_count > MAX_ENEMIES * 0.82 or projectile_count > MAX_PROJECTILES * 0.82
	overload_frames = mini(120, overload_frames + 1) if overloaded else maxi(0, overload_frames - 2)
	quality_scale = 0.58 if overload_frames > 45 else (0.78 if overload_frames > 15 else 1.0)

func effect_cap() -> int:
	return maxi(96, roundi(MAX_EFFECTS * quality_scale))

func allow_projectile(current: int) -> bool:
	return current < MAX_PROJECTILES

func allow_enemy(current: int, boss: bool = false) -> bool:
	return boss or current < MAX_ENEMIES

func quality_for_load(enemy_count: int, projectile_count: int, effect_count: int = 0) -> float:
	var pressure := maxf(float(enemy_count) / MAX_ENEMIES, float(projectile_count) / MAX_PROJECTILES)
	pressure = maxf(pressure, float(effect_count) / MAX_EFFECTS)
	return 0.58 if pressure >= 0.92 else (0.78 if pressure >= 0.72 else 1.0)

func can_spawn_cosmetic(kind: String, current: int) -> bool:
	if kind in ["boss_phase", "boss_move", "enemy_warning", "ultimate_impact", "skill_impact", "synced_impact", "shield_break", "terrain_break"]:
		return true
	return current < effect_cap()

func snapshot() -> Dictionary:
	return {"frame_ms":last_frame_ms,"quality":quality_scale,"overload_frames":overload_frames,"limits":{"enemies":MAX_ENEMIES,"projectiles":MAX_PROJECTILES,"effects":MAX_EFFECTS}}
