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
	expect(gates.is_empty(), "chapter one fences are removed")
	var bush := feature(game.sim, "watch_block")
	expect(bush.is_empty() and not game.sim._terrain_blocks(Vector2(400, 180), 4.0), "removed bush leaves a walkable space")
	expect(feature(game.sim, "watch_low").is_empty() and game.sim.terrain_movement_scale(Vector2(765, 457)) >= 1.0, "removed swamp leaves normal movement")
	expect(feature(game.sim, "watch_high").is_empty(), "raised platform no longer covers the court")
	expect(feature(game.sim, "watch_device").is_empty(), "automatic mechanism no longer covers the court")
	await capture(game, "stage01-map-review")
	print("V57 MAP QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
