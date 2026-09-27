extends SceneTree
const OUT := "res://../outputs/boss-video-import/movement/frames"
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game); await process_frame
	game.test_mode = true;game.set_process(false);game.set_physics_process(false)
	game.mode_select_panel.close();game.stage_select_panel.close();game.squad_panel.root.hide();game.dialogue.hide()
	game.hud.get_child(0).show()
	var squad: Array[String] = ["traveler", "hero_01", "hero_04"]
	game.sim.reset_stage("stage_03", squad, 8712);game.sim.start()
	game.sim.terrain_features.clear();game.sim.enemies.clear();game.sim.enemy_lookup.clear()
	for h in game.sim.heroes:
		h.hp=100000;h.max_hp=100000;h.deployed=true;h.pos=Vector2(450,350+h.id*60);h.target=h.pos
	var galio: Dictionary=game.sim.spawn_enemy(Vector2(980,310),"boss_galio")
	var kindred: Dictionary=game.sim.spawn_enemy(Vector2(980,455),"boss_03")
	galio.galio_revealed=true;kindred.galio_summoned=true;kindred.kindred_respite_used=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for i in 312:
		var dt := 1.0/24.0
		if i < 192:
			var dir := -1.0 if i < 96 else 1.0
			for boss in [galio,kindred]:boss.pos.x += dir*48*dt;boss.facing=dir
		elif i == 192:
			for boss in [galio,kindred]:game.sim._begin_enemy_warning(boss,game.sim.heroes[0])
		elif i < 224:
			for boss in [galio,kindred]:
				if boss.attack_pending:
					boss.warning_timer-=dt
					if boss.warning_timer <= 0:game.sim._resolve_enemy_warning(boss)
		elif i == 240:
			for boss in [galio,kindred]:
				boss.xp=0;boss.shield=0;boss.hp=1;game.sim.apply_hit(boss,99999999,"physical",0)
				game.sim.enemies.erase(boss)
		game.battle.accept_events(game.sim.drain_events());game.battle.advance(dt);game.refresh()
		game.hud.boss_skill_warning_panel.hide();game.battle.queue_redraw()
		RenderingServer.force_draw();await process_frame
		var picture: Image=game.get_viewport().get_texture().get_image()
		picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
		picture.save_png(OUT+"/frame-%04d.png"%i)
	print("DUAL_BOSS_MOVEMENT_CAPTURE_PASS 312 frames")
	game.queue_free();await process_frame;quit()
