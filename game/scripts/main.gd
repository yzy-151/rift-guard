extends Node
const Sim = preload("res://scripts/combat_simulation.gd")
const View = preload("res://scripts/battle_view.gd")
const Hud = preload("res://scripts/battle_hud.gd")
const QA = preload("res://scripts/qa_suite.gd")
const Stage = preload("res://scripts/stage_projection.gd")
const Story = preload("res://scripts/dialogue_director.gd")
const Content = preload("res://scripts/content_config.gd")
const CompendiumState = preload("res://scripts/compendium_state.gd")
const CompendiumPanel = preload("res://scripts/compendium_panel.gd")
const SquadPanel = preload("res://scripts/squad_panel.gd")
const StageSelectPanel = preload("res://scripts/stage_select_panel.gd")
var content = Content.new()
var story = Story.new(content)
var saved_story
var previewing: bool = false
var picker
var fx
var effect_preview: float = 0.0
var dialogue
var story_resume: String = ""
var sim = Sim.new(-1, true)
var battle
var hud
var selected_id: int = 0
var muted: bool = false
var sound: AudioStreamPlayer
var sound_timer: float = 0.0
var test_mode: bool = false
var compendium = CompendiumState.new()
var compendium_panel
var squad_panel
var stage_select_panel
var pending_stage_id := ""
var pending_stage_number := 0
var stage_result_recorded := false
var skill_aiming := false

func _ready() -> void:
	battle = View.new()
	battle.sim = sim
	add_child(battle)
	fx = preload("res://scripts/sheet_effects.gd").new()
	battle.add_child(fx)
	hud = Hud.new()
	hud.config = content
	add_child(hud)
	hud.reward_action.connect(choose_reward)
	hud.primary_action.connect(primary)
	hud.pause_action.connect(toggle_pause)
	hud.restart_action.connect(restart)
	hud.select_action.connect(select_hero)
	hud.mute_action.connect(func(enabled: bool):
		muted = enabled
		if muted:
			sound.stop())
	hud.reduce_action.connect(func(enabled: bool):
		battle.reduced_effects = enabled
		fx.reduced = enabled)
	hud.compendium_action.connect(toggle_compendium)
	hud.squad_action.connect(open_current_squad)
	hud.stage_action.connect(open_stage_select)
	hud.skill_action.connect(toggle_skill_aiming)
	sound = AudioStreamPlayer.new()
	sound.stream = preload("res://assets/hit.ogg")
	sound.volume_db = -18
	sound.max_polyphony = 3
	add_child(sound)
	dialogue = preload("res://scripts/dialogue_panel.gd").new()
	add_child(dialogue)
	dialogue.config = content
	dialogue.build(hud, story)
	picker = preload("res://scripts/content_preview.gd").new()
	add_child(picker)
	picker.build(self)
	compendium_panel = CompendiumPanel.new()
	add_child(compendium_panel)
	compendium_panel.build(hud, sim.database, compendium)
	squad_panel = SquadPanel.new()
	add_child(squad_panel)
	squad_panel.build(hud, sim.database, compendium)
	squad_panel.confirmed.connect(confirm_next_squad)
	stage_select_panel = StageSelectPanel.new()
	add_child(stage_select_panel)
	stage_select_panel.build(hud, sim.database, compendium)
	stage_select_panel.chosen.connect(choose_stage)
	dialogue.finished.connect(end_dialogue)
	refresh()
	if not content.errors.is_empty():
		var warning = hud.label(hud.get_child(0), Vector2(32, 102), Vector2(1215, 42), "Excel 配置未应用：" + content.errors[0] + "（完整记录：config-errors.txt）", 14, Color("#ff9c8c"))
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif not content.loaded:
		hud.label(hud.get_child(0), Vector2(32, 102), Vector2(1215, 28), "未找到 content/game_config.xlsx，当前使用内置内容。", 13, Color("#d6bd98"))
	if "--v9-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v9_test")
	elif "--v8-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v8_test")
	elif "--v6-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v6_test")
	elif "--v7-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v7_test")
	elif "--v5-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v5_test")
	elif "--config-window-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_config_window_test")
	elif "--phase1-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_phase1_test")
	elif "--v4-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v4_test")
	elif "--m9-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_m9_test")
	elif "--m5-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_m5_test")
	elif "--m4-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_m4_test")
	elif "--ui-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_ui_test")
	elif "--smoke-test" in OS.get_cmdline_user_args():
		test_mode = true
		call_deferred("run_smoke_test")

func _physics_process(dt: float) -> void:
	if story.active or picker.visible or effect_preview > 0 or compendium_panel.is_open() or squad_panel.is_open() or stage_select_panel.is_open():
		return
	sim.tick(dt)
	check_story()
	process_events()
	compendium.observe(sim)
	if sim.state == "won" and not stage_result_recorded:
		var stage: Dictionary = sim.database.stages.get(sim.current_stage_id, {})
		compendium.clear_stage(sim.current_stage_id, stage.get("unlocks", []))
		compendium.record_result(sim.current_stage_id, sim.kills, sim.base_hp, sim.best_streak)
		stage_result_recorded = true
	if not story.active:
		hud.refresh(sim, selected_id)

func _process(dt: float) -> void:
	if effect_preview > 0:
		effect_preview = maxf(0, effect_preview - dt)
		fx.advance(dt)
		if effect_preview <= 0:
			hud.signature = ""
			refresh()
	sound_timer = maxf(0.0, sound_timer - dt)
	if not story.active and not picker.visible and not compendium_panel.is_open() and not squad_panel.is_open() and not stage_select_panel.is_open() and effect_preview <= 0 and sim.state not in ["paused", "reward"]:
		battle.advance(dt)
		fx.advance(dt)

func process_events() -> void:
	var batch: Array[Dictionary] = sim.drain_events()
	battle.accept_events(batch)
	fx.accept(batch)
	for event in batch:
		if event.kind == "regroup":
			sound.stop()
		if event.kind == "boss_arrival":
			hud.announce_boss(str(event.value))
		if event.kind == "hit" and not muted and not test_mode and sound_timer <= 0.0:
			sound.pitch_scale = 0.94 + float(sim.shots_fired % 3) * 0.06
			sound.play()
			sound_timer = 0.065

func refresh() -> void:
	battle.selected_id = selected_id
	if not story.active:
		hud.refresh(sim, selected_id)
	battle.queue_redraw()

func primary() -> void:
	if story.active:
		return
	match sim.state:
		"ready":
			if test_mode:
				sim.start()
			else:
				var opening_key := "mode1_opening" if sim.v2_mode else "opening"
				if not begin_dialogue(opening_key, "start"):
					sim.start()
		"paused":
			sim.toggle_pause()
		"won", "lost":
			restart()
			primary()
	refresh()

func choose_reward(index: int) -> void:
	if story.active:
		return
	if sim.choose_reward(index):
		refresh()

func restart() -> void:
	story.reset()
	story_resume = ""
	hud.get_child(0).show()
	if dialogue != null:
		dialogue.root.hide()
		dialogue.auto_mode = false
		dialogue.auto_button.text = "自动：关"
	sim.restart_current_stage()
	selected_id = 0
	fx.active.clear()
	effect_preview = 0
	battle.effects.clear()
	battle.shot_flashes.clear()
	battle.base_flash = 0.0
	sound.stop()
	set_skill_aiming(false)
	stage_result_recorded = false
	refresh()

func toggle_pause() -> void:
	if story.active:
		return
	sim.toggle_pause()
	if sim.state == "paused":
		sound.stop()
	refresh()

func select_hero(id: int) -> void:
	if story.active:
		return
	if sim.state not in ["running", "between"]:
		return
	if id < 0 or id >= sim.heroes.size():
		return
	selected_id = id
	refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2 and not story.active:
		toggle_compendium()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3 and not story.active:
		open_current_squad()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4 and not story.active:
		open_stage_select()
		get_viewport().set_input_as_handled()
		return
	if compendium_panel.is_open():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			compendium_panel.close()
			get_viewport().set_input_as_handled()
		return
	if squad_panel.is_open():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
			squad_panel.confirm()
		get_viewport().set_input_as_handled()
		return
	if stage_select_panel.is_open():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			stage_select_panel.close()
		get_viewport().set_input_as_handled()
		return
	if picker.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			picker.hide()
			refresh()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not story.active:
		if event.keycode == KEY_F6:
			picker.open()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F7 and sim.state in ["ready", "paused"]:
			preview_effects()
			get_viewport().set_input_as_handled()
			return
	if story.active:
		dialogue.handle_input(event)
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			toggle_skill_aiming()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and skill_aiming:
			set_skill_aiming(false)
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_SPACE, KEY_ESCAPE:
				toggle_pause()
				get_viewport().set_input_as_handled()
			KEY_ENTER:
				if sim.state in ["ready", "won", "lost"]:
					primary()
					get_viewport().set_input_as_handled()
			KEY_R:
				restart()
				get_viewport().set_input_as_handled()
			KEY_1, KEY_2, KEY_3:
				if sim.state == "reward":
					choose_reward(event.keycode - KEY_1)
				else:
					select_hero(event.keycode - KEY_1)
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if story.active or picker.visible or effect_preview > 0 or squad_panel.is_open() or stage_select_panel.is_open():
		return
	if sim.state not in ["running", "between"]:
		return
	if event is InputEventMouseMotion and skill_aiming:
		var hover_screen: Vector2 = battle.get_global_transform().affine_inverse() * event.position
		battle.skill_point = Stage.unproject(hover_screen)
		battle.queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed:
		var screen_point: Vector2 = battle.get_global_transform().affine_inverse() * event.position
		var point: Vector2 = Stage.unproject(screen_point)
		if not View.WORLD.has_point(point):
			return
		if event.button_index == MOUSE_BUTTON_LEFT and skill_aiming:
			if sim.activate_traveler_skill(point):
				set_skill_aiming(false)
				process_events()
				refresh()
			return
		elif event.button_index == MOUSE_BUTTON_LEFT:
			selected_id = -1
			var closest: float = 48.0
			for h in sim.heroes:
				var distance: float = screen_point.distance_to(Stage.project(h.pos) + Vector2(0, -18))
				if distance < closest:
					closest = distance
					selected_id = h.id
		elif event.button_index == MOUSE_BUTTON_RIGHT and selected_id >= 0:
			sim.command_move(selected_id, point)
		refresh()

func run_smoke_test() -> void:
	primary()
	for frame in 150:
		await get_tree().process_frame
	print("M3 EXPORTED SMOKE PASSED; state=" + sim.state)
	get_tree().quit()

func run_ui_test() -> void:
	var suite = QA.new()
	await suite.run(self)

func begin_dialogue(key: String, resume_action: String = "") -> bool:
	if not story.begin(key):
		return false
	story_resume = resume_action
	sound.stop()
	hud.get_child(0).hide()
	dialogue.display()
	return true

func end_dialogue() -> void:
	if previewing:
		story = saved_story
		dialogue.director = story
		previewing = false
	hud.get_child(0).show()
	hud.signature = ""
	var action: String = story_resume
	story_resume = ""
	if action == "start":
		sim.start()
	elif action == "advance_stage":
		advance_stage()
	refresh()

func check_story() -> void:
	if story.active:
		return
	if sim.v2_mode:
		if sim.state == "won":
			if has_next_stage():
				begin_dialogue("mode1_won", "advance_stage")
			else:
				begin_dialogue("mode1_final_won")
		elif sim.state == "lost":
			begin_dialogue("mode1_lost")
		return
	if sim.state == "reward" and not sim.v2_mode:
		begin_dialogue("node%d" % sim.wave)
	elif sim.state in ["won", "lost"]:
		begin_dialogue(sim.state)

func has_next_stage() -> bool:
	var mode: Dictionary = sim.database.modes.get(sim.run_state.mode_id, {})
	var ids: Array = mode.get("stage_ids", [])
	var index := ids.find(sim.current_stage_id)
	return index >= 0 and index + 1 < ids.size()

func advance_stage() -> void:
	var mode: Dictionary = sim.database.modes.get(sim.run_state.mode_id, {})
	var ids: Array = mode.get("stage_ids", [])
	var index := ids.find(sim.current_stage_id)
	if index < 0 or index + 1 >= ids.size():
		return
	var completed: Dictionary = sim.database.stages.get(sim.current_stage_id, {})
	var unlocks: Array = completed.get("unlocks", [])
	compendium.clear_stage(sim.current_stage_id, unlocks)
	pending_stage_id = str(ids[index + 1])
	pending_stage_number = index + 2
	squad_panel.open(pending_stage_id, sim.run_state.squad, unlocks)
	sound.stop()

func open_current_squad() -> void:
	if story.active or compendium_panel.is_open() or squad_panel.is_open() or sim.state not in ["ready", "won"]:
		return
	var mode: Dictionary = sim.database.modes.get(sim.run_state.mode_id, {})
	var ids: Array = mode.get("stage_ids", [])
	var index := ids.find(sim.current_stage_id)
	if index < 0:
		return
	pending_stage_id = sim.current_stage_id
	pending_stage_number = index + 1
	squad_panel.open(pending_stage_id, sim.run_state.squad)
	sound.stop()

func open_stage_select() -> void:
	if story.active or compendium_panel.is_open() or squad_panel.is_open() or stage_select_panel.is_open() or sim.state not in ["ready", "won"]:
		return
	stage_select_panel.open()
	sound.stop()

func choose_stage(stage_id: String) -> void:
	var ids: Array = sim.database.modes.get(sim.run_state.mode_id, {}).get("stage_ids", [])
	var index := ids.find(stage_id)
	if index < 0:
		return
	pending_stage_id = stage_id
	pending_stage_number = index + 1
	squad_panel.open(stage_id, sim.run_state.squad)

func confirm_next_squad(squad: Array[String]) -> void:
	if pending_stage_id.is_empty():
		return
	story.reset()
	sim.reset_stage(pending_stage_id, squad, sim.run_seed + 1)
	selected_id = 0
	set_skill_aiming(false)
	stage_result_recorded = false
	fx.active.clear()
	battle.effects.clear()
	battle.shot_flashes.clear()
	hud.get_child(0).show()
	var dialogue_key := "mode1_opening" if pending_stage_number == 1 else "mode1_stage%d_opening" % pending_stage_number
	pending_stage_id = ""
	pending_stage_number = 0
	if not begin_dialogue(dialogue_key, "start"):
		sim.start()

func run_m4_test() -> void:
	var suite = preload("res://scripts/qa_m4.gd").new()
	await suite.run(self)

func preview_scene(key: String) -> void:
	picker.hide()
	saved_story = story
	story = Story.new(content)
	dialogue.director = story
	previewing = true
	if not begin_dialogue(key):
		story = saved_story
		dialogue.director = story
		previewing = false

func preview_effects() -> void:
	effect_preview = 1.5
	hud.overlay.hide()
	fx.active.clear()
	fx.active.append({"kind": "heal", "pos": Vector2(420, 370), "age": -0.15})
	fx.active.append({"kind": "vaporize", "pos": Vector2(790, 370), "age": -0.15})

func run_m5_test() -> void:
	var suite = preload("res://scripts/qa_m5.gd").new()
	await suite.run(self)

func run_m9_test() -> void:
	var suite = preload("res://scripts/qa_m9.gd").new()
	await suite.run(self)

func run_config_window_test() -> void:
	var suite = preload("res://scripts/qa_config_window.gd").new()
	await suite.run(self)

func run_phase1_test() -> void:
	var suite = preload("res://scripts/qa_phase1.gd").new()
	await suite.run(self)

func toggle_compendium() -> void:
	if story.active or squad_panel.is_open() or stage_select_panel.is_open():
		return
	if compendium_panel.is_open():
		compendium_panel.close()
	else:
		compendium.observe(sim)
		compendium_panel.open()
		sound.stop()

func toggle_skill_aiming() -> void:
	if story.active or compendium_panel.is_open() or squad_panel.is_open() or stage_select_panel.is_open() or sim.state != "running" or sim.traveler_skill_cooldown > 0.0:
		return
	set_skill_aiming(not skill_aiming)

func set_skill_aiming(enabled: bool) -> void:
	skill_aiming = enabled
	battle.skill_targeting = enabled
	if enabled and not sim.heroes.is_empty():
		battle.skill_point = sim.heroes[0].pos + Vector2(260, 0)
	hud.set_skill_aiming(enabled)
	refresh()

func run_v4_test() -> void:
	var suite = preload("res://scripts/qa_v4.gd").new()
	await suite.run(self)

func run_v5_test() -> void:
	var suite = preload("res://scripts/qa_v5.gd").new()
	await suite.run(self)

func run_v6_test() -> void:
	var suite = preload("res://scripts/qa_v6.gd").new()
	await suite.run(self)

func run_v7_test() -> void:
	var suite = preload("res://scripts/qa_v7.gd").new()
	await suite.run(self)

func run_v8_test() -> void:
	var suite = preload("res://scripts/qa_v8.gd").new()
	await suite.run(self)

func run_v9_test() -> void:
	var suite = preload("res://scripts/qa_v9.gd").new()
	await suite.run(self)
