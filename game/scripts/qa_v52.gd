extends RefCounted

const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V52 PASS: " + message)
	else:
		failures += 1
		push_error("V52 FAIL: " + message)

func run(game) -> void:
	expect(UI_LAYOUT.battle_boss_panel_rect.size.x <= 560.0, "boss panel is compact")
	expect(UI_LAYOUT.battle_boss_panel_rect.position.x == 360.0, "boss panel is centered in the battle viewport")
	expect(UI_LAYOUT.battle_boss_bar_rect.size.y <= 9.0, "boss health fill stays slim")
	print("V52 BOSS BAR RUNTIME: size=%s minimum=%s" % [game.hud.boss_hp_bar.size, game.hud.boss_hp_bar.get_combined_minimum_size()])
	expect(game.hud.boss_hp_bar.size.y <= 10.0, "boss health bar remains slim at runtime")
	expect(ResourceLoader.exists("res://assets/sfx/combat_attack.wav"), "attack audio is packaged")
	expect(ResourceLoader.exists("res://assets/sfx/combat_hit.wav"), "hit audio is packaged")
	expect(not ResourceLoader.exists("res://assets/characters/furina/furina-chibi-v1.png"), "obsolete Furina runtime art is removed")

	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	var squad: Array[String] = ["traveler", "hero_03", "hero_08"]
	game.sim.reset_stage("stage_08", squad, 5201)
	game.sim.start()
	game.sim.enemies.clear()
	game.sim.events.clear()
	for hero_index in game.sim.heroes.size():
		game.sim.heroes[hero_index].deployed = true
		game.sim.heroes[hero_index].moving = false
		game.sim.heroes[hero_index].pos = Vector2(250 + hero_index * 110, 360)
		game.sim.heroes[hero_index].target = game.sim.heroes[hero_index].pos
	var boss: Dictionary = game.sim.spawn_enemy(Vector2(900, 350), "boss_04")
	boss.boss_phase = 3
	boss.hp = boss.max_hp * 0.63
	boss.shield = 1280.0
	game.refresh()
	game.battle.advance(0.0)
	await game.get_tree().create_timer(0.65).timeout
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	expect(image != null, "boss HUD validation image is available")
	if image != null:
		if image.get_size() != Vector2i(1920, 1080):
			image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
		var directory := ProjectSettings.globalize_path("res://../docs/v52-validation")
		DirAccess.make_dir_recursive_absolute(directory)
		expect(image.save_png(directory.path_join("compact-boss-hud.png")) == OK, "1920x1080 compact boss HUD capture written")
	print("V52 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
