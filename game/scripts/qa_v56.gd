extends RefCounted

const STAGE_VISUAL = preload("res://data/stage_visual_profile.tres")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V56 PASS: " + message)
	else:
		failures += 1
		push_error("V56 FAIL: " + message)

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
	var directory := ProjectSettings.globalize_path("res://../docs/v56-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	expect(image.save_png(directory.path_join(name + ".png")) == OK, name + " screenshot written")

func run(game) -> void:
	expect(STAGE_VISUAL.chapter1_moving_platform != null and STAGE_VISUAL.chapter1_mechanism != null, "independent platform and mechanism placeholders are bound")
	var squad: Array[String] = ["traveler", "hero_03", "hero_08"]
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	game.sim.reset_stage("stage_01", squad, 5601)
	game.sim.start()
	for index in game.sim.heroes.size():
		game.sim.heroes[index].deployed = true
		game.sim.heroes[index].moving = false
	game.sim.heroes[0].pos = feature(game.sim, "watch_high").area.get_center()
	game.sim.heroes[1].pos = feature(game.sim, "watch_device").area.get_center() + Vector2(-70, 20)
	game.sim.heroes[2].pos = Vector2(285, 410)
	game.refresh()
	game.battle.advance(0.0)
	await game.get_tree().create_timer(0.35).timeout
	expect(game.battle._is_chapter_one_stage(), "only stage_01 enables Mondstadt rendering")
	expect(game.battle.material != null, "stage_01 blend shader is active")
	var swamp := feature(game.sim, "watch_low")
	expect(not swamp.is_empty() and game.sim.terrain_movement_scale(swamp.area.get_center()) < 0.8, "swamp slows ground movement")
	var gates: Array = game.sim.terrain_features.filter(func(item: Dictionary) -> bool: return str(item.get("type", "")) == "shortcut" and float(item.get("hp", 0.0)) > 0.0)
	expect(gates.size() == 2, "stage_01 has two skill-breakable gates")
	for gate: Dictionary in gates:
		expect(game.sim._terrain_blocks(gate.area.get_center(), 8.0), str(gate.get("label", "gate")) + " blocks heroes and ground enemies")
	var high_hero: Dictionary = game.sim.heroes[0].duplicate(true)
	high_hero.pos = feature(game.sim, "watch_high").area.get_center()
	var plain_hero: Dictionary = high_hero.duplicate(true)
	plain_hero.pos = Vector2(980, high_hero.pos.y)
	expect(game.sim.attack_range_screen_radii(high_hero).x > game.sim.attack_range_screen_radii(plain_hero).x * 1.20, "high ground materially increases attack range")
	var mechanism := feature(game.sim, "watch_device")
	expect(float(mechanism.get("radius", 0.0)) >= 800.0 and float(mechanism.get("interval", 0.0)) >= 5.0, "automatic mechanism is low-frequency and ultra-long-range")
	var moving := feature(game.sim, "moving_platform")
	game.sim.heroes[2].pos = moving.area.get_center()
	game.sim.heroes[2].target = game.sim.heroes[2].pos
	var rider_before: Vector2 = game.sim.heroes[2].pos
	game.sim._terrain_tick(0.25)
	expect(game.sim.heroes[2].pos.distance_to(rider_before) > 0.1, "moving platform carries its rider")
	await capture(game, "stage01-mondstadt-terrain")
	game.sim.reset_stage("stage_02", squad, 5602)
	game.sim.start()
	game.refresh()
	game.battle.advance(0.0)
	await game.get_tree().create_timer(0.2).timeout
	expect(not game.battle._is_chapter_one_stage() and game.battle.material == null, "stage_02 restores original black-red renderer")
	await capture(game, "stage02-original-grid")
	game.sim.reset_stage("stage_03", squad, 5603)
	game.battle.advance(0.0)
	expect(not game.battle._is_chapter_one_stage(), "stage_03 also keeps original renderer")
	print("V56 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)