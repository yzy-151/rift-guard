extends RefCounted
## Runs inside the exported executable, without external script overrides.
var failures: Array[String] = []
var checks := 0
var output := ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func capture(game: Node, filename: String) -> void:
	if DisplayServer.get_name().to_lower() == "headless": return
	for frame in range(4): await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(game.get_viewport().get_texture().get_image().save_png(output.path_join(filename + ".png")) == OK, "capture " + filename)

func run(game: Node) -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	if not output.is_absolute_path():
		printerr("--classic-release-test requires an absolute --qa-output directory")
		game.get_tree().call_deferred("quit", 2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.get_viewport().gui_disable_input=true
	var environment_art=load("res://scripts/battle_environment_art.gd")
	for theme: String in ["crimson","frost","wind","meadow"]:
		check(environment_art.texture(theme)!=null,"painted ground packaged: "+theme)
	check(str(ProjectSettings.get_setting("application/config/version")) == "102.0.0", "V102 package version")
	var device_atlas = load("res://assets/world/v92-devices/functional-atlas.png")
	check(device_atlas is Texture2D and device_atlas.get_width() > 1000, "functional terrain atlas packaged")
	game.open_mode_menu()
	check(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://main.tscn", "V86 default entry")
	check(game.mode_select_panel.is_open(), "original menu")
	check(game.mode_select_panel.starfall_button != null, "additional mode entry")
	check(ResourceLoader.exists("res://starfall/main.tscn"), "additional mode packaged")
	await capture(game, "01-menu")
	game.mode_select_panel.continue_button.pressed.emit()
	check(game.home_panel.is_open(), "original home")
	await capture(game, "02-home")
	check(await game.home_panel.travel_to("harbor",false), "packaged harbor exit")
	game.home_panel.player_pos = Vector2(650,535)
	game.home_panel._update_camera()
	await capture(game,"06-harbor")
	check(await game.home_panel.travel_to("garden",false), "packaged garden exit")
	game.home_panel.player_pos = Vector2(1570,535)
	game.home_panel._update_camera()
	await capture(game,"07-garden")
	check(game.story.stories.has("explore_garden_hero_10"),"regional story packaged")
	check(await game.home_panel.travel_to("harbor",false) and await game.home_panel.travel_to("base",false),"return to base")
	game.return_to_main_menu()
	game.choose_mode("endless_survival")
	check(game.endless_select_panel.is_open() and game.endless_select_panel.cards.size()==3,"three selectable endless maps")
	await capture(game,"08-endless-selection")
	game.endless_select_panel.cards[1].pressed.emit()
	check(game.squad_panel.is_open() and game.sim.endless_layout_id=="frost_isles","layout choice reaches squad selection")
	game.return_to_main_menu()
	game.choose_mode("rift_watch")
	check(game.stage_select_panel.is_open(), "original stage selection")
	game.choose_stage("stage_01")
	check(game.squad_panel.is_open(), "original squad selection")
	await capture(game, "03-squad")
	game.return_to_main_menu()
	game.mode_select_panel.close()
	game.story.reset()
	game.dialogue.root.hide()
	game.hud.get_child(0).show()
	# Fixtures advance both simulation and effects at the same fixed step.
	# Keep the rendering clock deterministic after exercising the menus.
	game.set_physics_process(false)
	game.set_process(false)
	var squad: Array[String] = ["traveler", "hero_03", "hero_04"]
	for scenario: Dictionary in [{"stage":"stage_02","layout":"blood_gate","capture":"04-campaign"},{"stage":"stage_endless","layout":"blood_gate","capture":"05-endless"},{"stage":"stage_endless","layout":"frost_isles","capture":"09-frost-isles"},{"stage":"stage_endless","layout":"wind_cross","capture":"10-wind-cross"}]:
		var stage: String=scenario.stage
		game.sim.select_endless_layout(str(scenario.layout))
		game.sim.reset_stage(stage, squad, 86003)
		game.sim.start()
		game.battle.reset_transients()
		game.hud.reset_transients()
		game.fx.active.clear()
		game.battle_audio.reset()
		for hero: Dictionary in game.sim.heroes:
			hero.deployed = true
			hero.pos = Vector2(540 + int(hero.id) * 65, 345) if stage != "stage_endless" else Vector2(1230 + int(hero.id) * 45, 740)
			hero.target = hero.pos
			hero.hp = 10000.0
			hero.max_hp = 10000.0
		game.sim.enemies.clear()
		game.sim.enemy_lookup.clear()
		var functional_types: Array[String] = []
		for feature: Dictionary in game.sim.terrain_features:
			if str(feature.get("type", "")) in ["relay", "spring", "wind_lane", "hazard_lane"]:
				functional_types.append(str(feature.type))
		check(functional_types.size() == (5 if stage == "stage_endless" else 2), str(scenario.capture) + " authored functional terrain present")
		check(functional_types.has("relay") and functional_types.has("spring"), str(scenario.capture) + " relay and spring present")
		for index in range(6):
			var kinds: Array[String] = ["ranged", "buffer", "originium_bug", "rift_bat", "hilichurl_brute", "charger"]
			var point := Vector2(740 + index * 55, 300 + (index % 3) * 65) if stage != "stage_endless" else Vector2(1450 + index * 55, 720 + (index % 3) * 65)
			game.sim.spawn_enemy(point, kinds[index])
		game.process_events()
		for frame in range(450):
			if game.sim.state == "reward":
				game.sim.choose_reward(0, int(game.sim.heroes[0].id))
			if frame % 120 == 0:
				for hero: Dictionary in game.sim.heroes:
					game.sim.activate_hero_skill(int(hero.id), Vector2(hero.pos) + Vector2(160, 0))
			game.sim.tick(1.0 / 30.0)
			game.process_events()
			game.battle.advance(1.0 / 30.0)
			game.fx.advance(1.0 / 30.0)
			if frame % 15 == 0:
				game.refresh()
				await game.get_tree().process_frame
		check(game.sim.elapsed >= 14.0 and game.sim.elapsed <= 15.1, stage + " simulation advanced at the intended fixed step")
		check(game.sim.heroes.size() == 3, stage + " original party retained")
		game.refresh()
		await capture(game,str(scenario.capture))
	var profiles: Dictionary = game.battle_audio.profile.voices.manifest.get("characters",{})
	check(profiles.size()>=10,"audio manifest exported")
	for character: String in ["traveler","hero_01","hero_02","hero_03","hero_04","hero_06","hero_07","hero_08","hero_10","hero_13"]:
		for slot: String in ["deploy","q","e","down"]:
			var clip: Dictionary=game.battle_audio.profile.voices.resolve(character,slot)
			check(not clip.is_empty() and ResourceLoader.exists(str(clip.get("path",""))),character+" "+slot+" voice exported")
	game.battle_audio.set_enabled(true)
	game.battle_audio.handle_events([{"kind":"deploy","hero_id":0,"character_id":"traveler","pos":Vector2.ZERO}],game.sim)
	await game.get_tree().create_timer(0.3).timeout
	check(game.battle_audio.played>0 and not game.battle_audio.streams.is_empty(),"exported audio streams actually loaded and played")
	game.battle_audio.reset()
	# Allow the original asynchronous boss/contract banners to finish before teardown.
	await game.get_tree().create_timer(3.5).timeout
	game.return_to_main_menu()
	check(game.mode_select_panel.is_open(), "return to original menu")
	game.open_settings()
	check(game.settings_panel.is_open(), "settings entry for workshop")
	var original_sim = game.sim
	game.settings_panel.workshop_button.pressed.emit()
	check(game.workshop != null, "packaged workshop opens through settings button")
	if game.workshop != null:
		var workshop = game.workshop
		workshop.session.paused = true
		check(workshop.session.sim != original_sim, "workshop has isolated simulation")
		workshop.session.sim.terrain_features.clear()
		check(workshop.session.place_hero("hero_13", Vector2(540, 350)), "workshop places Gwen")
		check(workshop.session.place_enemy("armored", Vector2(750, 350)), "workshop places armored enemy")
		workshop.session.selected_kind = "hero"
		workshop.session.selected_id = 1
		check(workshop.session.cast(true, Vector2(920, 350)), "workshop casts Gwen E in shipped package")
		for frame in 55: workshop._advance(1.0 / 60.0)
		workshop.refresh()
		await capture(game, "11-workshop")
		workshop.close()
		await game.get_tree().process_frame
		check(game.workshop == null and game.sim == original_sim and game.settings_panel.is_open(), "workshop returns to original settings and simulation")
	print("V100 RELEASE: checks=%d failures=%d; four 15-second combat fixtures, terrain, exploration, 3 layouts, 40 voice slots, packaged audio and isolated workshop" % [checks, failures.size()])
	await game._quit_after_audio_cleanup(0 if failures.is_empty() else 1)
