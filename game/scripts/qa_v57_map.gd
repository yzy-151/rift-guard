extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V57 MAP PASS: " + message)
	else:
		failures += 1
		push_error("V57 MAP FAIL: " + message)

func feature(sim, id: String) -> Dictionary:
	for item: Dictionary in sim.terrain_features:
		if str(item.get("id", "")) == id:
			return item
	return {}

func capture(game, name: String) -> void:
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	expect(image != null, name + " frame is available")
	if image == null:
		return
	if image.get_size() != Vector2i(1920, 1080):
		image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	var directory := ProjectSettings.globalize_path("res://../docs/v57-map-review")
	DirAccess.make_dir_recursive_absolute(directory)
	expect(image.save_png(directory.path_join(name + ".png")) == OK, name + " screenshot written")

func run(game) -> void:
	var squad: Array[String] = ["traveler", "hero_03", "hero_08"]
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	game.sim.reset_stage("stage_01", squad, 5701)
	game.sim.start()
	for hero: Dictionary in game.sim.heroes:
		hero.deployed = false
	game.refresh()
	game.battle.reduced_effects = true
	game.battle.advance(0.0)
	await game.get_tree().create_timer(0.25).timeout

	expect(feature(game.sim, "moving_platform").is_empty(), "floating platform removed from chapter one")
	var gates: Array = game.sim.terrain_features.filter(func(item: Dictionary) -> bool: return str(item.get("type", "")) == "shortcut")
	expect(gates.size() == 2, "chapter one contains exactly two destructible barricades")
	for gate: Dictionary in gates:
		expect(float(gate.get("hp", 0.0)) > 0.0, str(gate.get("id", "gate")) + " has durability")
		expect(game.sim._terrain_blocks(gate.area.get_center(), 6.0), str(gate.get("id", "gate")) + " blocks movement")
		var hp_before := float(gate.hp)
		game.sim.damage_terrain_shortcuts(gate.area.get_center(), 38.0, 25.0)
		expect(float(gate.hp) < hp_before, str(gate.get("id", "gate")) + " receives skill damage")
	var bush := feature(game.sim, "watch_block")
	expect(not bush.is_empty(), "irregular bush feature exists")
	expect(game.sim._terrain_blocks(bush.area.get_center(), 4.0), "colored bush center blocks movement")
	expect(not game.sim._terrain_blocks(bush.area.position + Vector2(2, 2), 0.0), "transparent bush corner stays walkable")
	var high := feature(game.sim, "watch_high")
	expect(not high.is_empty() and game.sim.terrain_attack_scale(high.area.get_center()) > 1.2, "high platform keeps range and attack benefit")
	await capture(game, "stage01-map-review")
	print("V57 MAP QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
