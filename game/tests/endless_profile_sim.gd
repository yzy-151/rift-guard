extends "res://scripts/combat_simulation.gd"
var timings: Dictionary = {}
func _enemy_tick(dt: float) -> void:
	var start := Time.get_ticks_usec()
	super._enemy_tick(dt)
	timings["_enemy_tick"] = int(timings.get("_enemy_tick",0))+Time.get_ticks_usec()-start
func _terrain_tick(dt: float) -> void:
	var start := Time.get_ticks_usec()
	super._terrain_tick(dt)
	timings["_terrain_tick"] = int(timings.get("_terrain_tick",0))+Time.get_ticks_usec()-start
func _projectile_tick(dt: float) -> void:
	var start := Time.get_ticks_usec()
	super._projectile_tick(dt)
	timings["_projectile_tick"] = int(timings.get("_projectile_tick",0))+Time.get_ticks_usec()-start
func _orbital_tick(dt: float) -> void:
	var start := Time.get_ticks_usec()
	super._orbital_tick(dt)
	timings["_orbital_tick"] = int(timings.get("_orbital_tick",0))+Time.get_ticks_usec()-start
func _skill_effect_tick(dt: float) -> void:
	var start := Time.get_ticks_usec()
	super._skill_effect_tick(dt)
	timings["_skill_effect_tick"] = int(timings.get("_skill_effect_tick",0))+Time.get_ticks_usec()-start
func _pending_impact_tick(dt: float) -> void:
	var start := Time.get_ticks_usec()
	super._pending_impact_tick(dt)
	timings["_pending_impact_tick"] = int(timings.get("_pending_impact_tick",0))+Time.get_ticks_usec()-start
func _support_tick(dt: float) -> void:
	var start := Time.get_ticks_usec()
	super._support_tick(dt)
	timings["_support_tick"] = int(timings.get("_support_tick",0))+Time.get_ticks_usec()-start
func _enemy_projectile_tick(dt: float) -> void:
	var start := Time.get_ticks_usec()
	super._enemy_projectile_tick(dt)
	timings["_enemy_projectile_tick"] = int(timings.get("_enemy_projectile_tick",0))+Time.get_ticks_usec()-start
func _enemy_hazard_tick(dt: float) -> void:
	var start := Time.get_ticks_usec()
	super._enemy_hazard_tick(dt)
	timings["_enemy_hazard_tick"] = int(timings.get("_enemy_hazard_tick",0))+Time.get_ticks_usec()-start
func _hero_tick() -> void:
	var start := Time.get_ticks_usec()
	super._hero_tick()
	timings["_hero_tick"] = int(timings.get("_hero_tick",0))+Time.get_ticks_usec()-start
