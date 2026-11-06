extends SceneTree
## Real campaign data, real purchases, damage resolution and targeting geometry.
const Sim = preload("res://scripts/combat_simulation.gd")
const GroundProjection = preload("res://scripts/stage_projection.gd")
const Traveler = preload("res://scripts/traveler_elements.gd")
var checks := 0
var failures: Array[String] = []
var observations := {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("LEGACY PAD QA: " + label)

func _initialize() -> void:
	var removed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../qa/legacy_pad_cleanup_20261005/removed_terrain.json"))
	var sim = Sim.new(510052, true)
	for stage_index in range(1, 9):
		var stage_id := "stage_%02d" % stage_index
		sim.reset_stage(stage_id, ["traveler"], 510052 + stage_index)
		sim.state = "running"
		sim.battle_devices.gold = 10000
		for actor: Dictionary in sim.heroes:
			actor.deployed = false
		var hero: Dictionary = sim.heroes[0]
		hero.deployed = true
		hero.damage = 100.0
		hero.range = 200.0
		hero.element = ""
		hero.crit_chance = 0.0
		hero.cleave = false
		hero.attack_timer = 0.0
		var definition: Dictionary = sim.database.stages[stage_id]
		var legacy_count := 0
		for feature: Dictionary in definition.terrain:
			if str(feature.type) in ["attack_ground", "high_ground"]: legacy_count += 1
		check(legacy_count == 0, stage_id + " authored stage contains no old buff tiles")
		check(sim.terrain_features.size() == definition.terrain.size(), stage_id + " retains every non-buff terrain feature")
		for feature: Dictionary in sim.terrain_features:
			check(str(feature.type) not in ["attack_ground", "high_ground"], stage_id + " has no visible or functional legacy buff feature")
			if str(feature.type) == "low_ground":
				var point := _feature_center(feature)
				check(sim.terrain_movement_scale(point) <= float(feature.speed_scale), stage_id + " retains actual slow-ground movement")
			elif str(feature.type) == "blocked":
				check(sim._terrain_blocks(_feature_center(feature), 1.0), stage_id + " retains actual wall collision")
		var former_tiles: Array = removed.get(stage_id, [])
		check(not former_tiles.is_empty(), stage_id + " checks removed tiles from the previous real stage")
		for old: Dictionary in former_tiles:
			var raw: Array = old.rect
			var area := Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
			for point: Vector2 in [area.get_center(), area.position + Vector2(3,3), area.end - Vector2(3,3)]:
				check(is_equal_approx(sim.terrain_attack_scale(point), 1.0), stage_id + " old tile has no attack multiplier at " + str(point))
				check(is_equal_approx(sim.terrain_range_scale(point), 1.0), stage_id + " old tile has no range multiplier at " + str(point))
		# A stale imported campaign definition must not bring these pads back.
		var injected := definition.duplicate(true)
		injected.terrain.append({"id":"stale_attack", "type":"attack_ground", "rect":[520,340,60,40], "attack_bonus":10.0})
		injected.terrain.append({"id":"stale_range", "type":"high_ground", "rect":[640,340,60,40], "range_bonus":10.0})
		sim._load_terrain(injected)
		check(sim.terrain_features.size() == definition.terrain.size(), stage_id + " rejects stale legacy pads at the loading boundary")
		check(is_equal_approx(sim.terrain_attack_scale(Vector2(550,360)), 1.0), stage_id + " stale attack pad cannot affect combat")
		check(is_equal_approx(sim.terrain_range_scale(Vector2(670,360)), 1.0), stage_id + " stale range pad cannot affect targeting")
		# Prefer a former free-buff cell: it now requires a paid purchase.
		check(sim.battle_devices.select(sim, "power"), stage_id + " can select a purchased power tile")
		var power_point := _purchase_point(sim, former_tiles)
		hero.pos = power_point
		hero.target = power_point
		check(sim.battle_devices.place(sim, power_point), stage_id + " can purchase power on a cleared former buff cell")
		check(sim.battle_devices.gold == 9900, stage_id + " spends the actual power price")
		check(is_equal_approx(sim.displayed_attack_damage(hero), 135.0), stage_id + " purchased power changes actual HUD attack")
		var victim: Dictionary = sim.spawn_enemy(power_point + Vector2(-25,0), "grunt")
		victim.hp = 100000.0
		victim.max_hp = victim.hp
		victim.armor = 0.0
		victim.shield = 0.0
		victim.affixes = []
		victim.intrinsic_element = ""
		victim.aura = ""
		victim.aura_timer = 0.0
		victim.speed = 0.0
		victim.route_points = []
		sim._hero_tick()
		sim._pending_impact_tick(1.0)
		check(is_equal_approx(100000.0 - float(victim.hp), 135.0), stage_id + " purchased power changes actual resolved melee damage")
		var ability := Traveler.definition("hydro", false)
		sim._execute_ability_impact(hero, ability, victim.pos, false)
		var expected_skill := float(ability.power) + 135.0 * float(ability.attack_ratio)
		check(is_equal_approx(float(sim.skill_effects[-1].power), expected_skill), stage_id + " purchased power also changes actual skill power")
		sim._skill_effect_tick(0.001)
		check(is_equal_approx(100000.0 - float(victim.hp), 135.0 + expected_skill), stage_id + " purchased power affects actual skill damage")
		check(sim.battle_devices.select(sim, "range"), stage_id + " can select a purchased range tile")
		var range_point := _purchase_point(sim, former_tiles)
		hero.pos = range_point
		hero.target = range_point
		check(is_equal_approx(sim.displayed_attack_range(hero), 200.0), stage_id + " range starts at base before purchase")
		var base_radii: Vector2 = sim.attack_range_screen_radii(hero)
		var ground_center := GroundProjection.ground_center(hero.pos)
		var base_world := GroundProjection.ground_world_radii(hero.pos, base_radii)
		var extended_point := ground_center + Vector2(base_world.x * 1.20, 0)
		check(not sim.is_in_attack_range(hero, extended_point), stage_id + " unpurchased targeting rejects the extra range")
		check(sim.battle_devices.place(sim, range_point), stage_id + " can purchase a second independent range cell")
		check(sim.battle_devices.gold == 9780, stage_id + " spends the actual range price")
		check(is_equal_approx(sim.displayed_attack_range(hero), 260.0), stage_id + " purchased range changes actual HUD range")
		check(sim.is_in_attack_range(hero, extended_point), stage_id + " purchased range accepts the same real target")
		var new_world := GroundProjection.ground_world_radii(hero.pos, sim.attack_range_screen_radii(hero))
		check(not sim.is_in_attack_range(hero, ground_center + Vector2(new_world.x * 1.02,0)), stage_id + " purchased range still rejects beyond its ellipse")
		check(is_equal_approx(sim.displayed_attack_damage(hero), 100.0), stage_id + " separate range tile does not stack power")
		observations[stage_id] = {"removed":former_tiles.size(), "retained_terrain":sim.terrain_features.size(), "power_cell":str(power_point), "range_cell":str(range_point), "melee_damage":135.0, "skill_damage":expected_skill, "purchased_range":260.0}
	# Endless's existing four special areas are outside campaign-device scope.
	sim.reset_stage("stage_endless", ["traveler"], 510062)
	var endless_high := 0
	for feature: Dictionary in sim.terrain_features:
		if str(feature.type) == "high_ground": endless_high += 1
	check(endless_high == 4, "endless retains its four existing special areas")
	check(not sim.battle_devices.enabled, "campaign-device cleanup does not enable endless purchasing")
	var output_path := ProjectSettings.globalize_path("res://../qa/legacy_pad_cleanup_20261005/validation.json")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output_path = arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t"))
		output.close()
	print("LEGACY PAD CLEANUP QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _feature_center(feature: Dictionary) -> Vector2:
	var cells: Array = feature.get("grid_cells", [])
	return Rect2(cells[0]).get_center() if not cells.is_empty() else Rect2(feature.area).get_center()

func _purchase_point(sim, former_tiles: Array) -> Vector2:
	for old: Dictionary in former_tiles:
		var raw: Array = old.rect
		var center := Vector2(float(raw[0]) + float(raw[2]) * 0.5, float(raw[1]) + float(raw[3]) * 0.5)
		var cell: Rect2 = sim.battle_devices.cell_at(sim, center)
		if sim.battle_devices.placement_error(sim, cell.get_center()).is_empty(): return cell.get_center()
	for row in sim.GRID_ROWS:
		for col in sim.GRID_COLUMNS:
			var point: Vector2 = sim.GRID_ORIGIN + Vector2(col + 0.5,row + 0.5) * sim.GRID_CELL_SIZE
			if sim.battle_devices.placement_error(sim, point).is_empty(): return point
	check(false, sim.current_stage_id + " has a legal paid tile deployment cell")
	return Vector2.ZERO
