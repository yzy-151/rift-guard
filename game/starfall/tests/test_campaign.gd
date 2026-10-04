extends SceneTree
const Sim = preload("res://starfall/simulation.gd")
# Deterministic gameplay smoke: default stats, only public player inputs.
# The agent walks for pickups, rotates the squad, selects offered upgrades and dodges.
func _initialize() -> void:
	var failures: int = 0
	for seed_value in [11, 22, 33]:
		var sim = Sim.new()
		sim.start("campaign", ["traveler", "hero_03", "hero_08"], seed_value)
		var casts: int = 0
		for i in range(27000):
			if sim.phase == "lost" or sim.phase == "won":
				break
			if sim.phase == "upgrade":
				var choice: String = sim.upgrade_choices[0].id
				for pref in ["multishot", "power", "haste", "magnet", "core_repair", "lifesteal", "regen"]:
					var found: bool = false
					for option in sim.upgrade_choices:
						if option.id == pref:
							choice = option.id
							found = true
							break
					if found:
						break
				sim.choose_upgrade(choice)
			var hero: Dictionary = sim.heroes[sim.selected]
			var target: Vector2 = sim.CORE
			var best: float = INF
			for enemy in sim.enemies:
				var score: float = enemy.pos.distance_to(hero.pos)
				if enemy.kind == "boss_01":
					score *= 0.4
				if score < best:
					best = score
					target = enemy.pos
			var walk_to: Vector2 = sim.CORE + Vector2.RIGHT.rotated(sim.time * 0.18) * 220.0
			for pickup in sim.pickups:
				if pickup.pos.distance_to(hero.pos) < 230.0:
					walk_to = pickup.pos
					break
			var movement: Vector2 = (walk_to - hero.pos).normalized()
			if i % 180 == 0:
				sim.select_hero((sim.selected + 1) % 3)
			if sim.cast("q", target):
				casts += 1
			sim.cast("e", target)
			for field in sim.hazards:
				if field.owner == "enemy" and field.remaining < 0.25 and field.pos.distance_to(hero.pos) < field.radius + 45:
					sim.dash((hero.pos - field.pos).normalized())
			sim.step(1.0 / 60.0, movement, target)
			sim.drain_events()
		print("BALANCE seed=%d phase=%s time=%.1f wave=%d kills=%d level=%d core=%.1f hp=%s casts=%d" % [seed_value, sim.phase, sim.time, sim.wave, sim.kills, sim.level, sim.core_hp, str(sim.heroes.map(func(h): return round(h.hp))), casts])
		if sim.phase != "won" or sim.wave != 9 or sim.core_hp <= 0.0:
			printerr("FAIL: default-health campaign did not complete for seed %d" % seed_value)
			failures += 1
	if failures == 0:
		print("PASS: three default-health campaigns completed with public inputs")
	quit(0 if failures == 0 else 1)

