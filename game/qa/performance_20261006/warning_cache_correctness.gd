extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
const View=preload("res://scripts/battle_view.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize()->void: run.call_deferred()
func check(value: bool,label: String)->void:
	checks+=1
	if not value: failures.append(label)
func reference(sim,enemy: Dictionary)->Vector2:
	var source: Vector2=enemy.get("warning_origin",Vector2(enemy.pos)+Vector2(0,-12))
	var direction: Vector2=enemy.get("warning_direction",Vector2.LEFT)
	if direction.is_zero_approx(): direction=Vector2.LEFT
	var arena: Rect2=sim.ENDLESS_ARENA if sim.endless_mode else sim.MOVE_AREA
	var end:=source
	for index in 90:
		var next:=source+direction*(float(index+1)*18.0)
		if not arena.grow(8.0).has_point(next) or sim.terrain_line_blocked(source,next): break
		end=next
	return end
func run()->void:
	var sim=Sim.new(6106206,true)
	var squad: Array[String]=["traveler","hero_03","hero_13"]
	sim.reset_stage("stage_endless",squad,6106206)
	var view=View.new();view.sim=sim
	for step in 72:
		for position: Vector2 in [Vector2(1360,880),Vector2(470,300),Vector2(2310,300),Vector2(510,1380),Vector2(2200,1410)]:
			var enemy: Dictionary={"id":step,"pos":position,"warning_origin":position,"warning_direction":Vector2.from_angle(step*TAU/72)}
			var endpoint:=reference(sim,enemy)
			check(view.cached_attack_warning_end(enemy)==endpoint,"new endpoint %d/%s"%[step,position])
			check(view.cached_attack_warning_end(enemy)==endpoint,"cached endpoint %d/%s"%[step,position])
	var enemy: Dictionary={"id":600,"pos":Vector2(1000,700),"warning_origin":Vector2(1000,700),"warning_direction":Vector2.RIGHT}
	var mutations: Array[Dictionary]=[
		{"type":"door","hp":50.0,"area":Rect2(1180,620,70,160)},
		{"type":"door","hp":0.0,"area":Rect2(1180,620,70,160)},
		{"type":"blocked","area":Rect2(1350,620,70,160),"collision_shape":"ellipse"},
		{"type":"blocked","area":Rect2(1350,620,70,160),"collision_shape":"ellipse","collision_scale":[.6,.8],"collision_offset":[.2,.1]},
		{"type":"blocked","area":Rect2(1500,620,70,160)},
	]
	for mutation: Dictionary in mutations:
		sim.terrain_features.clear();sim.terrain_features.append(mutation);sim._rebuild_endless_blocker_index()
		check(view.cached_attack_warning_end(enemy)==reference(sim,enemy),"changed collision %s"%mutation)
		check(view.cached_attack_warning_end(enemy)==reference(sim,enemy),"changed cached collision")
		enemy.warning_origin+=Vector2(1,1)
		check(view.cached_attack_warning_end(enemy)==reference(sim,enemy),"origin invalidation")
		enemy.warning_direction=Vector2.LEFT if enemy.warning_direction==Vector2.RIGHT else Vector2.RIGHT
		check(view.cached_attack_warning_end(enemy)==reference(sim,enemy),"direction invalidation")
	sim.endless_mode=false;check(view.cached_attack_warning_end(enemy)==reference(sim,enemy),"arena invalidation")
	enemy.warning_direction=Vector2.ZERO;check(view.cached_attack_warning_end(enemy)==reference(sim,enemy),"zero direction")
	view.reset_transients();check(view.attack_warning_endpoints.is_empty(),"restart clears cache")
	check(view.cached_attack_warning_end(enemy)==reference(sim,enemy),"restart rebuild")
	for index in 300:
		enemy.id=index+1000;view.cached_attack_warning_end(enemy)
	check(view.attack_warning_endpoints.size()<=256,"stale cache bound")
	check(view.attack_warning_cache_hits>=360,"actual repeated queries hit cache")
	check(sim._card_evolution_level({"evolution_levels":[1,3,6,9]},99)==9,"legacy excessive purchase evolves at final phase")
	var result: Dictionary={"checks":checks,"failures":failures}
	var file:=FileAccess.open("res://../qa/performance-20261006/warning-cache-correctness.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify(result));view.free();quit(0 if failures.is_empty() else 1)
