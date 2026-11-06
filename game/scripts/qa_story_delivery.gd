extends SceneTree

const Director = preload("res://scripts/dialogue_director.gd")
const Session = preload("res://scripts/workshop_session.gd")
var failures: Array[String] = []
var app

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS " + label if condition else "FAIL " + label)
	if not condition: failures.append(label)

func pump_until(condition: Callable, seconds: float = 18.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		if app.dialogue.animation_waiting: app.dialogue.acknowledge_animation()
		if app.achievement_popup.is_open(): app.achievement_popup.close()
		await create_timer(0.03).timeout
	return bool(condition.call())

func complete_graph(director, option: int) -> void:
	var remaining := 30
	while director.active and remaining > 0:
		if director.has_choices(): director.choose(option)
		else: director.advance()
		remaining -= 1

func _run() -> void:
	Engine.time_scale = 6.0
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true
	app.set_physics_process(false)
	app.set_process(false)
	app.mode_select_panel.close()
	check(app.compendium.unlocked_characters.keys() == ["traveler"], "fresh campaign has only traveler")
	check(app.sim.heroes.size() == 2 and str(app.sim.heroes[0].get("character_id", "")) == "traveler" and not bool(app.sim.heroes[0].get("temporary_assist", false)) and str(app.sim.heroes[1].get("character_id", "")) == "hero_13" and bool(app.sim.heroes[1].get("temporary_assist", false)) and bool(app.sim.heroes[1].get("deployed", false)) and app.sim.run_state.squad == ["traveler"], "initial stage has traveler and deployed temporary-assist Gwen without adding Gwen to the chosen squad")
	for n in range(2, 9): check(not app.stage_select_panel._is_unlocked("stage_%02d" % n), "stage %d initially locked" % n)
	var first: Dictionary = app.sim.database.stages.stage_01
	var fifth: Dictionary = app.sim.database.stages.stage_05
	check(first.template_id == "crucible_spiral" and first.routes.main == JSON.parse_string("[[1195,360],[1050,470],[900,360],[760,480],[610,350],[430,430],[115,360]]"), "stage 1 uses original stage 5 map")
	check(fifth.template_id == "citadel_zigzag" and fifth.routes.main == JSON.parse_string("[[1195,355],[1010,355],[880,430],[690,430],[590,360],[390,360],[130,395]]") and fifth.visual_stage_id == "stage_01", "stage 5 uses original stage 1 map")
	check(first.boss_id == "boss_02", "slime king retained")
	var brutes := 0
	for wave: Dictionary in first.waves:
		if wave.enemy_id == "hilichurl_brute": brutes += int(wave.count)
	check(brutes == 2, "exactly two additional brutes")
	check(app.battle._visual_stage_id() == "stage_05", "stage 5 artwork used")
	var map_sim = preload("res://scripts/combat_simulation.gd").new(20261005, true)
	check(map_sim.base_world_position() == Vector2(100, 365) and not app.battle._is_chapter_one_stage(), "stage 1 uses stage 5 crystal anchor and scenery rules")
	var grid_features := 0
	var correctly_gridded := true
	for feature: Dictionary in map_sim.terrain_features:
		if feature.type in ["high_ground", "attack_ground", "blocked", "trap", "low_ground"]:
			grid_features += 1
			correctly_gridded = correctly_gridded and not feature.get("grid_cells", []).is_empty()
	check(correctly_gridded and grid_features == 12, "stage 1 keeps original stage 5 grid terrain behavior")
	map_sim.reset_stage("stage_05", ["traveler"], 20261005)
	var view_sim = app.battle.sim
	app.battle.sim = map_sim
	check(app.battle._visual_stage_id() == "stage_01" and app.battle._is_chapter_one_stage() and map_sim.base_world_position() == Vector2(130, 395), "stage 5 uses original stage 1 artwork and wind statue anchor")
	app.battle.sim = view_sim
	var ellipse_pads := 0
	var correctly_ungridded := true
	for feature: Dictionary in map_sim.terrain_features:
		if feature.type == "attack_ground":
			ellipse_pads += 1
			var raw: Array = feature.rect
			correctly_ungridded = correctly_ungridded and feature.get("collision_shape", "") == "ellipse" and not feature.has("grid_cells") and feature.area == Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
	check(correctly_ungridded and ellipse_pads == 2, "stage 5 preserves original stage 1 ellipse pads and exact bounds")
	var runtime = preload("res://scripts/stages/stage_runtime.gd").new(first)
	var emitted_brutes := 0
	var bosses: Array[String] = []
	for frame in 500:
		for event: Dictionary in runtime.tick(1.0):
			if event.kind == "spawn" and event.enemy_id == "hilichurl_brute": emitted_brutes += 1
			if event.kind == "boss_wave": bosses.append(event.enemy_id)
	check(emitted_brutes == 2 and bosses == ["boss_02"] and runtime.all_spawns_emitted, "full spawn schedule emits requested cast")
	var comics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_comics.json"))
	check(comics.mode1_opening.size() == 5 and str(comics.mode1_opening[0].image).ends_with("v85_wake.png"), "three prologue panels precede two delivered panels")
	var director = Director.new()
	director.begin("mode1_opening")
	director.skip()
	check(director.active and director.has_choices(), "skip stops at authored choice")
	complete_graph(director, 1)
	check(director.last_ending.status == "badend" and director.last_ending.unlock_character == "", "Furina rejection grants no unlock")
	director.reset(); director.begin("mode1_opening"); complete_graph(director, 0)
	check(director.last_ending.status == "success" and director.last_ending.unlock_character == "hero_03", "Furina acceptance grants intended hero")
	for option in 2:
		director.reset(); director.begin("mode1_won"); complete_graph(director, option)
		check(director.last_ending.status == "success" and director.last_ending.unlock_character == "hero_13", "Gwen delivery branch %d preserved" % option)
	app.choose_stage("stage_01")
	check(app.story.active and app.story_resume == "pre_stage" and not app.squad_panel.is_open(), "stage click plays story before squad selection")
	check(await pump_until(func(): return not app.campaign_prelude_active), "intro comic sequence completes")
	complete_graph(app.story, 1)
	app.end_dialogue()
	check(await pump_until(func(): return app.story.active and app.story_resume == "pre_stage"), "bad end restarts opening")
	check(not app.compendium.unlocked_characters.has("hero_03") and not app.squad_panel.is_open(), "failed opening cannot deploy or unlock Furina")
	check(await pump_until(func(): return not app.campaign_prelude_active), "replayed prologue completes")
	complete_graph(app.story, 0)
	app.end_dialogue()
	check(await pump_until(func(): return app.squad_panel.is_open()), "successful opening opens squad picker")
	check(app.compendium.unlocked_characters.has("hero_03") and not app.compendium.unlocked_characters.has("hero_13"), "only Furina earned before battle")
	app.squad_panel.root.hide()
	var squad: Array[String] = ["traveler", "hero_03"]
	app.confirm_next_squad(squad)
	check(app.sim.state == "running" and not app.story.active, "confirm squad enters combat without replaying intro")
	app.sim.state = "won"; app.check_story()
	check(app.battle.stage_exit_active and app.battle.stage_exit_character_id == "hero_13", "Gwen enters after victory")
	check(not app.compendium.cleared_stages.has("stage_01"), "victory alone cannot unlock next stage")
	app.battle._advance_stage_exit(1.1)
	check(app.battle._stage_exit_visual_sample().state == "idle", "newcomer waits at meeting point")
	app.sim.heroes[0].pos = app.battle.STAGE_EXIT_MEET
	app.battle._advance_stage_exit(0.1)
	check(app.battle.stage_exit_phase == "dialogue" and app.story_resume == "stage_recruit", "meeting triggers Gwen branch before departure")
	check(await pump_until(func(): return not app.campaign_prelude_active), "outro comics finish")
	complete_graph(app.story, 0); app.end_dialogue()
	check(await pump_until(func(): return app.battle.stage_exit_phase == "departing"), "success permits joint departure")
	check(app.compendium.unlocked_characters.has("hero_13") and app.stage_select_panel._is_unlocked("stage_02"), "Gwen success unlocks hero and stage 2")
	check(app.battle._stage_exit_visual_sample().state == "run" and app.battle._stage_exit_visual_sample().facing == 1.0, "departure uses walking frames and correct facing")
	app.battle.reset_transients()
	app.story.reset(); app.story_resume = ""; app.campaign_prelude_active = false
	app.sim.state = "running"
	app._begin_recruitment(1, Vector2(720, 360))
	check(app.story.active and app.story_resume == "recruit", "drag deployment invokes full dialogue")
	app.story.choose(1); app.story.advance(); app.end_dialogue()
	check(await pump_until(func(): return not app.recruitment_transition_active), "failed deployment animation completes")
	check(app.sim.rejected_recruits.has(1) and not app.sim.heroes[1].deployed, "failed deployment runs away instead of joining battle")
	app.story.reset()
	app.sim.rejected_recruits.clear()
	app.test_mode = false; app.muted = true
	var drop_point: Vector2 = app.battle.get_global_transform() * app.battle.world_to_screen(Vector2(620, 360))
	app.handle_deploy_drag(1, true, drop_point)
	app._finish_deploy_drag(drop_point)
	check(app.story.key == "deploy_hero_03_0" and app.story.graph_mode and app.story.current().text == "哈？我堂堂水之魔神也要去和魔物战斗吗", "actual drag selects master-delivered deployment graph")
	complete_graph(app.story, 0); app.end_dialogue()
	check(await pump_until(func(): return not app.recruitment_transition_active), "authored deployment success animation completes")
	check(app.sim.heroes[1].deployed and app.recruited_heroes.has(1), "authored success joins battlefield at dragged position")
	app.test_mode = true
	var session = Session.new()
	check(session.place_hero("traveler", Vector2(450, 360)), "V100 workshop places hero")
	check(session.place_enemy("grunt", Vector2(550, 360)), "V100 workshop places monster")
	session.enemy_action = false; session.auto_attack = false
	var hp: float = session.sim.heroes[0].hp
	session.sim.damage_hero(0, 10000.0)
	check(session.sim.heroes[0].hp == hp, "workshop invulnerability")
	session.selected_kind = "enemy"; session.selected_id = session.sim.enemies[0].id
	check(session.move_selected(Vector2(620, 360)), "workshop manual enemy movement available")
	for frame in 300: session.tick(1.0 / 60.0)
	check(session.sim.enemies.size() == 1 and session.sim.state == "running", "workshop never spawns campaign waves or settles")
	session.selected_kind = "hero"; session.selected_id = 0
	check(session.cast(false, Vector2(620, 360)) and session.cast(true, Vector2(620, 360)), "workshop casts Q and E skills")
	app.return_to_main_menu(); app.open_settings(); app.open_workshop()
	check(app.workshop != null and app.settings_panel.workshop_button != null, "V100 settings opens functional workshop")
	app.workshop.close()
	await process_frame
	check(app.workshop == null and app.settings_panel.is_open(), "workshop returns to settings")
	print("STORY DELIVERY QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
