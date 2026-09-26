extends "res://scripts/combat_simulation.gd"
# Deliberately uncached reference for the optimized hot queries.
func is_in_attack_range(hero: Dictionary, point: Vector2) -> bool:
	var delta := StageProjection.project(point)-(StageProjection.project(hero.pos)+Vector2(0,8))
	var r := attack_range_screen_radii(hero)
	return delta.x*delta.x/(r.x*r.x)+delta.y*delta.y/(r.y*r.y)<=1.0
func _nearest_enemy_after(origin: Dictionary, excluded: Array, source_hero: Dictionary={}, max_distance: float=INF) -> Dictionary:
	var best: Dictionary={}
	var distance:=max_distance*max_distance
	for e: Dictionary in enemies:
		if e.hp<=0 or e.id in excluded: continue
		if not source_hero.is_empty() and not is_in_attack_range(source_hero,e.pos): continue
		var d:=Vector2(e.pos).distance_squared_to(origin.pos)
		if d<distance or (d==distance and best.is_empty()):
			best=e
			distance=d
	return best
