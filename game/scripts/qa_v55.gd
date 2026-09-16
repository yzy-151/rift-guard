extends RefCounted

const STAGE_VISUAL = preload("res://data/stage_visual_profile.tres")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V55 PASS: " + message)
	else:
		failures += 1
		push_error("V55 FAIL: " + message)

func run(game) -> void:
	expect(UI_SKIN.battle_topbar != null, "unified top HUD uses packaged red-black artwork")
	expect(UI_LAYOUT.battle_status_rect.size.y >= 60.0 and UI_LAYOUT.battle_status_rect.size.x >= 1200.0 and UI_LAYOUT.battle_timeline_rect.size.x <= 280.0, "top HUD is unified while the enemy badge stays compact")
	expect(STAGE_VISUAL.chapter1_background != null and STAGE_VISUAL.chapter1_ground != null and UI_LAYOUT.battle_playfield_rect == Rect2(16, 88, 1248, 490), "chapter one art is clipped to the restored battle playfield")
	expect(STAGE_VISUAL.chapter1_crystal != null and STAGE_VISUAL.chapter1_high_platform != null, "chapter one crystal and high platform are bound")
	expect(STAGE_VISUAL.chapter1_lowland != null and STAGE_VISUAL.chapter1_barricade != null and STAGE_VISUAL.chapter1_bush != null, "chapter one terrain props are bound")

	var squad: Array[String] = ["traveler", "hero_03", "hero_08"]
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	game.sim.reset_stage("stage_01", squad, 5401)
	game.sim.start()
	for index in game.sim.heroes.size():
		game.sim.heroes[index].deployed = true
		game.sim.heroes[index].moving = false
		game.sim.heroes[index].pos = Vector2(260 + index * 125, 350 + index * 36)
	game.refresh()
	game.battle.advance(0.0)
	await game.get_tree().create_timer(0.35).timeout
	expect(game.battle._is_chapter_one_stage(), "stage_01 selects the Mondstadt chapter renderer")
	expect(game.battle.debug_stage_layer_order == ["backdrop", "atmosphere", "ground", "routes", "terrain", "architecture", "foreground"], "chapter one keeps the complete layer order")
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	expect(image != null, "chapter one validation frame is available")
	if image != null:
		if image.get_size() != Vector2i(1920, 1080):
			image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
		var directory := ProjectSettings.globalize_path("res://../docs/v55-validation")
		DirAccess.make_dir_recursive_absolute(directory)
		expect(image.save_png(directory.path_join("chapter1-stage01.png")) == OK, "chapter one 1920x1080 screenshot written")
	game.sim.reset_stage("stage_04", squad, 5402)
	expect(not game.battle._is_chapter_one_stage(), "chapter two keeps its original renderer")
	print("V55 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
