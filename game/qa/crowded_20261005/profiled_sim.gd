extends "res://scripts/combat_simulation.gd"
var timings: Dictionary = {}
func _record(key: String, started: int) -> void:
	if not timings.has(key): timings[key] = []
	timings[key].append((Time.get_ticks_usec() - started) / 1000.0)
func tick(dt: float) -> void:
	var started := Time.get_ticks_usec()
	super.tick(dt)
	_record("tick", started)
func _enemy_tick(dt: float) -> void:
	var started := Time.get_ticks_usec()
	super._enemy_tick(dt)
	_record("enemies", started)
func _projectile_tick(dt: float) -> void:
	var started := Time.get_ticks_usec()
	super._projectile_tick(dt)
	_record("hero_projectiles", started)
func _hero_tick() -> void:
	var started := Time.get_ticks_usec()
	super._hero_tick()
	_record("hero_attacks", started)
func _terrain_tick(dt: float) -> void:
	var started := Time.get_ticks_usec()
	super._terrain_tick(dt)
	_record("terrain", started)
func _skill_effect_tick(dt: float) -> void:
	var started := Time.get_ticks_usec()
	super._skill_effect_tick(dt)
	_record("skills", started)
func _enemy_projectile_tick(dt: float) -> void:
	var started := Time.get_ticks_usec()
	super._enemy_projectile_tick(dt)
	_record("enemy_projectiles", started)
func _pending_impact_tick(dt: float) -> void:
	var started := Time.get_ticks_usec()
	super._pending_impact_tick(dt)
	_record("pending_impacts", started)
func _support_tick(dt: float) -> void:
	var started := Time.get_ticks_usec()
	super._support_tick(dt)
	_record("supports", started)

# Stress fixture keeps its authored rate/piercing budget for before/after parity.
func _clamp_hero_attack_rate(_hero: Dictionary) -> void:
	pass
