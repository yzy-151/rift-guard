extends "res://scripts/battle_view.gd"
var phase_us: Dictionary={}
var draw_total_us := 0
var reference_warnings := false
class ProfiledNumbers:
	extends "res://scripts/floating_damage_v3.gd"
	func draw(view)->void:
		var start:=Time.get_ticks_usec();super.draw(view);view.record("damage_numbers",start)
func _init()->void: damage_numbers=ProfiledNumbers.new()
func record(key: String,start: int)->void: phase_us[key]=int(phase_us.get(key,0))+Time.get_ticks_usec()-start
func _draw()->void:
	phase_us.clear();var start:=Time.get_ticks_usec();super._draw();draw_total_us=Time.get_ticks_usec()-start
func _draw_stage()->void:
	var start:=Time.get_ticks_usec();super._draw_stage();record("stage",start)
func _draw_enemy_telegraphs()->void:
	var start:=Time.get_ticks_usec();super._draw_enemy_telegraphs();record("telegraphs",start)
func _draw_projectile(shot: Dictionary)->void:
	var start:=Time.get_ticks_usec();super._draw_projectile(shot);record("friendly_projectiles",start)
func _draw_skill_zone(zone: Dictionary)->void:
	var start:=Time.get_ticks_usec();super._draw_skill_zone(zone);record("skill_zones",start)
func _draw_orbitals()->void:
	var start:=Time.get_ticks_usec();super._draw_orbitals();record("orbitals",start)
func _draw_enemy(enemy: Dictionary)->void:
	var start:=Time.get_ticks_usec();super._draw_enemy(enemy);record("enemies",start)
func _draw_hero(hero: Dictionary)->void:
	var start:=Time.get_ticks_usec();super._draw_hero(hero);record("heroes",start)
func _draw_effect(effect: Dictionary)->void:
	var start:=Time.get_ticks_usec();super._draw_effect(effect);record("generic_effects",start)
func draw_ellipse_shadow(point: Vector2,radius: float,color: Color)->void:
	var start:=Time.get_ticks_usec();super.draw_ellipse_shadow(point,radius,color);record("shadows",start)
func cached_attack_warning_end(enemy: Dictionary)->Vector2:
	if not reference_warnings:return super.cached_attack_warning_end(enemy)
	var source: Vector2=enemy.get("warning_origin",Vector2(enemy.pos)+Vector2(0,-12))
	var direction: Vector2=enemy.get("warning_direction",Vector2.LEFT)
	if direction.is_zero_approx():direction=Vector2.LEFT
	var arena: Rect2=sim.ENDLESS_ARENA if sim.endless_mode else sim.MOVE_AREA
	var end:=source
	for index in 90:
		var next:=source+direction*(float(index+1)*18.0)
		if not arena.grow(8.0).has_point(next) or sim.terrain_line_blocked(source,next):break
		end=next
	return end
