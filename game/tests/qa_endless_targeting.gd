extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")

func _initialize() -> void:
	var sim = Sim.new(8123, true)
	sim.reset_stage("stage_endless", ["traveler"], 8123)
	sim.start()
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	var hero: Dictionary = sim.heroes[0]
	hero.pos = sim.ENDLESS_ARENA.get_center()
	hero.target = hero.pos
	hero.attack_timer = 0.0
	hero.block = 0
	hero.range = 500.0
	var enemy: Dictionary = sim.spawn_enemy(hero.pos + Vector2(95, 0), "grunt")
	var shots_before: int = sim.shots_fired
	sim._hero_tick()
	assert(sim.shots_fired == shots_before + 1, "Hero must attack an in-range target")
	print("TARGETING PASS: in-range enemy attacked")
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	sim.spawn_enemy(hero.pos + Vector2(1100, 0), "grunt")
	hero.attack_timer = 0.0
	shots_before = sim.shots_fired
	sim._hero_tick()
	assert(sim.shots_fired == shots_before, "Hero must not attack an out-of-range target")
	print("TARGETING PASS: out-of-range enemy ignored")
	quit()
