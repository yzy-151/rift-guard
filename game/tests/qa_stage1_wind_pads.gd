extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const Stage = preload("res://scripts/stage_projection.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim = Sim.new(9182, true)
	var squad: Array[String] = ["traveler", "hero_03", "hero_08"]
	sim.reset_stage("stage_01", squad, 9182)
	var pads: Array = sim.terrain_features.filter(func(feature: Dictionary) -> bool: return str(feature.get("type", "")) == "attack_ground")
	if pads.size() != 2:
		push_error("Stage 1 should have exactly two wind pads")
		quit(1)
		return
	var hero: Dictionary = sim.heroes[0]
	hero.pos = Vector2(370, 370)
	var normal_damage := sim.displayed_attack_damage(hero)
	var normal_range := sim.displayed_attack_range(hero)
	var normal_radius: Vector2 = sim.attack_range_screen_radii(hero)
	for pad: Dictionary in pads:
		var area: Rect2 = pad.area
		if str(pad.get("collision_shape", "")) != "ellipse":
			push_error("Wind pad visual and trigger shapes differ")
			quit(1)
			return
		hero.pos = area.get_center()
		if not is_equal_approx(sim.displayed_attack_damage(hero), normal_damage * 1.30):
			push_error("Wind pad attack bonus differs from its label")
			quit(1)
			return
		if not is_equal_approx(sim.displayed_attack_range(hero), normal_range * 1.12):
			push_error("Wind pad range bonus differs from its label")
			quit(1)
			return
		var expected_radius := (42.0 + float(hero.range) * 0.62 * Stage.depth_scale(hero.pos)) * 1.12
		if not is_equal_approx(sim.attack_range_screen_radii(hero).x, expected_radius):
			push_error("Wind pad range outline differs from targeting radius")
			quit(1)
			return
		if sim._terrain_blocks(hero.pos, 4.0):
			push_error("Wind pad is drawn on blocked terrain")
			quit(1)
			return
		hero.pos = area.position + Vector2(2.0, 2.0)
		if not sim.terrain_feature_at(hero.pos, "attack_ground").is_empty():
			push_error("Wind pad rectangular corner should not trigger its bonus")
			quit(1)
			return
		hero.pos = area.get_center() + Vector2(area.size.x * 0.39, 0.0)
		if sim.terrain_feature_at(hero.pos, "attack_ground").is_empty():
			push_error("Wind pad visible interior should trigger its bonus")
			quit(1)
			return
	if normal_radius.x <= 0.0:
		push_error("Attack range is invalid")
		quit(1)
		return
	print("STAGE1_WIND_PADS_OK pads=2 damage=1.30 range=1.12 walkable=true")
	quit(0)
