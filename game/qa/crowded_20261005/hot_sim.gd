extends "res://qa/crowded_20261005/profiled_sim.gd"
var hotspots: Dictionary={}
func _hot(key: String, start: int) -> void:
	var entry: Dictionary=hotspots.get(key,{"calls":0,"us":0})
	entry.calls+=1; entry.us+=Time.get_ticks_usec()-start
	hotspots[key]=entry
func apply_hit(e: Dictionary, damage: float, element: String, source: int=-1, critical: bool=false) -> float:
	var start:=Time.get_ticks_usec(); var result: float=super.apply_hit(e,damage,element,source,critical); _hot("apply_hit_inclusive",start); return result
func splash_damage(e: Dictionary, damage: float, radius: float, hero: Dictionary={}) -> void:
	var start:=Time.get_ticks_usec(); super.splash_damage(e,damage,radius,hero); _hot("splash_inclusive",start)
func _nearest_enemy_after(e: Dictionary, excluded: Array, hero: Dictionary={}, max_distance: float=INF) -> Dictionary:
	var start:=Time.get_ticks_usec(); var result: Dictionary=super._nearest_enemy_after(e,excluded,hero,max_distance); _hot("chain_find",start); return result
func terrain_line_blocked(a: Vector2,b: Vector2,radius: float=5.0) -> bool:
	var start:=Time.get_ticks_usec(); var result: bool=super.terrain_line_blocked(a,b,radius); _hot("terrain_line",start); return result
func _emit_hit_feedback(e: Dictionary, value: int, element: String, source: int=-1, critical: bool=false) -> void:
	var start:=Time.get_ticks_usec(); super._emit_hit_feedback(e,value,element,source,critical); _hot("hit_feedback",start)
func is_in_attack_range(hero: Dictionary, point: Vector2) -> bool:
	var start:=Time.get_ticks_usec(); var result: bool=super.is_in_attack_range(hero,point); _hot("attack_range",start); return result
func enemy_candidates_in_rect(area: Rect2) -> Array[Dictionary]:
	var start:=Time.get_ticks_usec(); var result: Array[Dictionary]=super.enemy_candidates_in_rect(area); _hot("bucket_query",start); return result
