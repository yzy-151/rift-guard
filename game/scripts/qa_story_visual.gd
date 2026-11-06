extends SceneTree

var app
var output := "res://../qa/story_delivery"

func _initialize() -> void:
	_run.call_deferred()

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(output.path_join(filename))
	image.save_png(path)
	print("CAPTURE " + path)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true
	app.muted = true
	app.set_physics_process(false)
	app.set_process(false)
	app.mode_select_panel.close()
	app.stage_select_panel.open()
	await create_timer(0.5).timeout
	await capture("01_stage_select.png")
	app.stage_select_panel.close()
	app.story.reset(); app.story.begin("mode1_opening"); app.story.skip()
	app.hud.get_child(0).hide()
	app.dialogue.display()
	await create_timer(1.0).timeout
	app.dialogue.letters = 10000
	app.dialogue.body.visible_characters = -1
	app.dialogue._reveal_choices()
	await create_timer(0.3).timeout
	await capture("02_furina_choice.png")
	app.dialogue.root.hide(); app.story.reset()
	var squad: Array[String] = ["traveler", "hero_03"]
	app.sim.reset_stage("stage_01", squad, 9304)
	app.sim.start()
	app.sim.heroes[0].deployed = true
	app.sim.heroes[0].pos = Vector2(450, 360)
	app.sim.heroes[0].target = app.sim.heroes[0].pos
	app.sim.heroes[1].deployed = true
	app.sim.heroes[1].pos = Vector2(480, 455)
	app.sim.heroes[1].target = app.sim.heroes[1].pos
	app.sim.spawn_enemy(Vector2(825, 265), "hilichurl_brute")
	app.sim.spawn_enemy(Vector2(900, 450), "hilichurl_brute")
	app.sim.spawn_enemy(Vector2(980, 340), "grunt")
	app.sim.spawn_enemy(Vector2(1080, 435), "ranged")
	app.battle.advance(0.2)
	app.hud.get_child(0).show(); app.refresh()
	await create_timer(0.5).timeout
	await capture("03_stage_1_map.png")
	app.story.begin("mode1_won")
	app.story.advance(); app.story.choose(0)
	app.hud.get_child(0).hide(); app.dialogue.display()
	await create_timer(1.0).timeout
	app.dialogue.body.visible_characters = -1
	await capture("04_gwen_response.png")
	app.dialogue.root.hide(); app.story.reset()
	app.return_to_main_menu(); app.open_settings()
	await create_timer(0.5).timeout
	await capture("05_v100_settings.png")
	app.open_workshop()
	app.workshop.session.place_hero("hero_13", Vector2(650, 360))
	app.workshop.session.place_enemy("hilichurl_brute", Vector2(850, 360))
	app.workshop.session.paused = true
	app.workshop.refresh()
	await create_timer(0.5).timeout
	await capture("06_v100_workshop.png")
	app.workshop.close()
	await process_frame
	print("STORY VISUAL QA COMPLETE")
	quit()
