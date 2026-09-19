extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const Hud = preload("res://scripts/battle_hud.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim = Sim.new(137, true)
	var failures: Array[String] = []
	for stage_number in range(1, 9):
		var stage_id := "stage_%02d" % stage_number
		sim.reset_stage(stage_id, ["traveler"], 137)
		var occupied: Dictionary = {}
		for feature: Dictionary in sim.terrain_features:
			var kind := str(feature.get("type", ""))
			if kind in ["attack_ground", "high_ground"] and (stage_number != 1 or kind == "attack_ground"):
				var cells: Array = feature.get("grid_cells", [])
				if cells.size() != 1 or cells[0].size != Vector2(120, 80):
					failures.append("%s %s is not one 2x2 tile" % [stage_id, kind])
			for cell: Rect2 in feature.get("grid_cells", []):
				for y in range(int(cell.size.y / 40.0)):
					for x in range(int(cell.size.x / 60.0)):
						var key := "%d:%d" % [roundi((cell.position.x - 40.0) / 60.0) + x, roundi((cell.position.y - 140.0) / 40.0) + y]
						if occupied.has(key):
							failures.append("%s overlapping terrain %s" % [stage_id, key])
						occupied[key] = kind
		sim.reset_stage("stage_03", ["traveler"], 137)
	for feature: Dictionary in sim.terrain_features:
		var kind := str(feature.get("type", ""))
		var position: Vector2 = feature.area.get_center()
		if kind == "attack_ground" and not is_equal_approx(sim.terrain_attack_scale(position), 2.0):
			failures.append("attack tile does not double attack")
		if kind == "low_ground" and not is_equal_approx(sim.terrain_movement_scale(position), 0.30):
			failures.append("swamp does not slow by 70 percent")
		if kind == "high_ground":
			var hero: Dictionary = sim.heroes[0].duplicate(true)
			hero.pos = position
			var boosted: float = sim.attack_range_screen_radii(hero).x
			feature.range_bonus = 0.0
			var base: float = sim.attack_range_screen_radii(hero).x
			feature.range_bonus = 1.0
			if not is_equal_approx(boosted, base * 2.0):
				failures.append("high ground does not double range")
	var hud = Hud.new()
	root.add_child(hud)
	await process_frame
	var panel = hud.reward_panel
	sim.rewards.offered.append({"name": "心之钢"})
	panel.show()
	panel.show_target_picker(0, sim)
	if not panel.target_overlay.visible or panel.target_overlay.color.a < 0.99 or panel.target_overlay.z_index <= 3:
		failures.append("target overlay does not hide the cards")
	if panel.target_buttons[0].text != "" or not panel.target_previews[0].transparent_background or panel.target_previews[0].source_texture == null:
		failures.append("target choice is not an animated character preview")
	if failures.is_empty():
		print("REWARD TERRAIN PASS: target picker and tile effects")
	else:
		for failure: String in failures:
			push_error(failure)
		print("REWARD TERRAIN FAIL: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
