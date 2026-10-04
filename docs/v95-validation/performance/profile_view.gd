extends "res://scripts/battle_view.gd"
var draw_samples: Array[float] = []
var section_samples: Dictionary = {}
func measure(key: String, began: int) -> void:
 if not section_samples.has(key):section_samples[key]=[] as Array[float]
 section_samples[key].append(float(Time.get_ticks_usec()-began)/1000.0)
func _draw() -> void:
 var started := Time.get_ticks_usec()
 super._draw()
 draw_samples.append(float(Time.get_ticks_usec()-started)/1000.0)
func _draw_stage() -> void:
 var started := Time.get_ticks_usec()
 super._draw_stage()
 measure("stage",started)
func _draw_enemy(enemy: Dictionary) -> void:
 var started := Time.get_ticks_usec()
 super._draw_enemy(enemy)
 measure("enemy",started)
func _draw_hero(hero: Dictionary) -> void:
 var started := Time.get_ticks_usec()
 super._draw_hero(hero)
 measure("hero",started)
func _draw_enemy_telegraphs() -> void:
 var started := Time.get_ticks_usec()
 super._draw_enemy_telegraphs()
 measure("telegraphs",started)
