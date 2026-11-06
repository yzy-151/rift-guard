extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const Stage = preload("res://scripts/stage_projection.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim = Sim.new(9317, true)
	var squad: Array[String] = ["traveler", "hero_01", "hero_04"]
	sim.reset_stage("stage_01", squad, 9317)
	sim.terrain_features.clear()
	for index in range(1, sim.heroes.size()):
		sim.heroes[index].deployed = false
	var hero: Dictionary = sim.heroes[0]
	hero.deployed = true
	hero.heal_timer = 999.0
	var checks := 0
	for y in [140.0, 220.0, 360.0, 490.0, 540.0]:
		hero.pos = Vector2(640.0, y)
		var point := Vector2(425.0, y)
		if Stage.unproject(Stage.project(point)).distance_to(point) > 0.01:
			push_error("projection inverse mismatch at y=" + str(y))
			quit(1)
			return
		checks += 1
		var attack_radii: Vector2 = sim.attack_range_screen_radii(hero)
		var attack_center: Vector2 = Stage.ground_center(Vector2(hero.pos))
		var attack_world_radii: Vector2 = Stage.ground_world_radii(Vector2(hero.pos), attack_radii)
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var inside: Vector2 = attack_center + Vector2(direction) * attack_world_radii * 0.95
			var outside: Vector2 = attack_center + Vector2(direction) * attack_world_radii * 1.05
			if not sim.is_in_attack_range(hero, inside) or sim.is_in_attack_range(hero, outside):
				push_error("attack footprint mismatch at y=" + str(y))
				quit(1)
				return
			checks += 2
		for factor in [0.95, 1.05]:
			sim.enemies.clear()
			sim.enemy_lookup.clear()
			sim.projectiles.clear()
			hero.attack_timer = 0.0
			var before_shots := int(hero.shots)
			var target := attack_center + Vector2(attack_world_radii.x * factor, 0.0)
			sim.spawn_enemy(target, "grunt")
			sim._hero_tick()
			if (int(hero.shots) > before_shots) != (factor < 1.0):
				push_error("actual targeting differs from footprint at y=" + str(y))
				quit(1)
				return
			checks += 1
		var ability_radii: Vector2 = sim.ability_area_screen_radii(hero.pos, 180.0)
		var ability_world_radii := Stage.ground_world_radii(hero.pos, ability_radii)
		if not sim.is_in_ability_area(hero.pos, attack_center + Vector2(ability_world_radii.x * 0.95, 0), 180.0) or sim.is_in_ability_area(hero.pos, attack_center + Vector2(ability_world_radii.x * 1.05, 0), 180.0):
			push_error("ability footprint mismatch at y=" + str(y))
			quit(1)
			return
		checks += 2
	print("STAGE_PROJECTION_ALIGNMENT_OK checks=", checks)
	quit(0)
