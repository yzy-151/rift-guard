extends SceneTree

const SHY_PORTRAIT := "res://assets/helltaker/dialogue_portraits/芙宁娜_害羞_重绘_大腿根以上.png"
const SURPRISED_PORTRAIT := "res://assets/helltaker/dialogue_portraits/芙宁娜_惊讶_水滴瞳.png"
var app
var failures: Array[String] = []
var checks := 0
var output := ""
var drop_point := Vector2.ZERO

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	print("PASS " + label if condition else "FAIL " + label)
	if not condition: failures.append(label)

func wait_for(condition: Callable, seconds: float = 8.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return bool(condition.call())

func pointer(point: Vector2, pressed: bool) -> void:
	point = root.get_screen_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	await process_frame

func click(point: Vector2) -> void:
	await pointer(point, true)
	await pointer(point, false)

func portrait_matches(path: String) -> bool:
	var line: Dictionary = app.story.current()
	return bool(line.get("portrait_locked", false)) and str(line.get("portrait", "")) == path and app.dialogue.portrait.texture != null and app.dialogue.portrait.texture.resource_path == path

func screenshot(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func begin_branch() -> void:
	app.story.reset()
	app.story_resume = ""
	app.recruited_heroes.clear()
	app.pending_recruitment.clear()
	app.recruitment_transition_active = false
	app.battle.reset_transients()
	var squad: Array[String] = ["traveler", "hero_03"]
	app.sim.reset_stage("stage_01", squad, 20261005)
	app.sim.run_state.crystal_level = 6
	app.sim.start()
	check(app.sim.deploy_hero(0, drop_point - Vector2(140, 0)), "traveler is already deployed while Furina remains on the bench")
	app.hud.get_child(0).show()
	app.hud.signature = ""
	app.refresh()
	await process_frame
	var hero_button: Button = app.hud.hero_buttons[1]
	check(not app.sim.heroes[1].deployed and not hero_button.disabled, "Furina starts as available undeployed bench character")
	await pointer(hero_button.get_global_rect().get_center(), true)
	check(app.dragging_hero_id == 1 and app.battle.deploy_preview_active, "real HUD mouse press begins Furina deployment drag")
	await pointer(app.battle.get_global_transform() * app.battle.world_to_screen(drop_point), false)
	check(app.story.active and app.story_resume == "recruit" and app.story.graph_mode and app.story.key == "deploy_hero_03_0", "real battlefield release opens the delivered Furina graph")
	check(app.dragging_hero_id == -1 and not app.battle.deploy_preview_active, "real release clears drag preview")
	check(app.story.current().text == "哈？我堂堂水之魔神也要去和魔物战斗吗", "delivered deployment speech is preserved verbatim")
	var options: Array = app.story.current().get("choices", [])
	check(options.size() == 2 and options[0].text == "你也可以选择和我战斗" and options[1].text == "你也不想回不去枫丹吧芙宁娜女士", "both delivered choice labels are preserved verbatim")
	check(portrait_matches(SHY_PORTRAIT), "choice uses the exact locked shy portrait")
	check(await wait_for(func(): return app.dialogue.line_ended and app.dialogue.choice_buttons[1].visible and not app.dialogue.choice_buttons[1].disabled), "choice typing and reveal complete before mouse confirmation")
	# The choice cards also animate horizontally; wait until that real reveal ends.
	await create_timer(0.6).timeout

func _run() -> void:
	Engine.time_scale = 4.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.set_physics_process(false)
	app.test_mode = false
	app.muted = true
	app.mode_select_panel.close()
	var variants: Array[String] = []
	for id: String in app.story.graph_scenes:
		if id.begins_with("deploy_hero_03_"): variants.append(id)
	check(variants == ["deploy_hero_03_0"], "only master-delivered Furina deployment graph exists")
	check(not app.story.graph_scenes.has("deploy_hero_01_0"), "placeholder deployment template is not installed")
	var comics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_comics.json"))
	check(comics.mode1_opening.size() == 5 and str(comics.mode1_opening[0].image).ends_with("v85_wake.png"), "three prologue images still precede two stage-one images")
	for y in range(300, 470, 20):
		for x in range(560, 840, 20):
			var point := Vector2(x, y)
			if drop_point == Vector2.ZERO and not app.sim._terrain_blocks(point, 22.0): drop_point = point
	check(drop_point != Vector2.ZERO, "find a legal exact drop point")
	await begin_branch()
	await screenshot("furina_deployment_choice")
	await click(app.dialogue.choice_buttons[0].get_global_rect().get_center())
	check(app.story.current().text == "唔，本来还想看看战败CG......", "success branch preserves delivered response")
	check(portrait_matches(SHY_PORTRAIT), "success response keeps the exact delivered shy expression")
	check(await wait_for(func(): return app.dialogue.line_ended), "success response finishes typing")
	await screenshot("furina_deployment_success_response")
	await click(Vector2(960, 460))
	check(await wait_for(func(): return app.dialogue.animation_waiting), "success reaches the real confirmation animation")
	check(app.story.last_ending.status == "success", "first delivered option resolves SUCCESS")
	await screenshot("furina_deployment_success")
	await click(Vector2(640, 650))
	check(await wait_for(func(): return not app.recruitment_transition_active), "mouse acknowledgement completes success deployment")
	check(app.sim.heroes[1].deployed and app.recruited_heroes.has(1) and Vector2(app.sim.heroes[1].pos).distance_to(drop_point) < 0.1, "successful Furina truly deploys at the dragged world location")
	check(not app.sim.rejected_recruits.has(1) and app.sim.state == "running", "successful deployment resumes the battle")
	await screenshot("furina_deployment_on_field")
	await begin_branch()
	var deployed_before: int = app.sim.heroes.filter(func(hero: Dictionary): return bool(hero.deployed)).size()
	await click(app.dialogue.choice_buttons[1].get_global_rect().get_center())
	check(app.story.current().text == "我看到厕所了，再见旅行者", "failure branch preserves delivered response")
	check(portrait_matches(SURPRISED_PORTRAIT), "failure response shows the exact delivered surprised expression")
	check(await wait_for(func(): return app.dialogue.line_ended), "failure response finishes typing")
	await screenshot("furina_deployment_failure_response")
	await click(Vector2(960, 460))
	check(await wait_for(func(): return app.dialogue.animation_waiting), "failure reaches the real BADEND confirmation animation")
	check(app.story.last_ending.status == "badend", "second delivered option resolves BADEND")
	await screenshot("furina_deployment_badend")
	await click(Vector2(640, 650))
	check(await wait_for(func(): return not app.battle.departing_recruit.is_empty()), "BADEND starts the real walking retreat actor")
	check(app.battle.character_sequences.texture("hero_03", "run") != null, "retreat uses available Furina walking frames")
	var nearest_base := INF
	var furthest_base := 0.0
	var frames: Dictionary = {}
	var remained_on_bench := true
	var retreat_captured := false
	var deadline := Time.get_ticks_msec() + 4500
	while app.recruitment_transition_active and Time.get_ticks_msec() < deadline:
		if not app.battle.departing_recruit.is_empty():
			var actor: Dictionary = app.battle.departing_recruit
			var distance: float = Vector2(actor.pos).distance_to(app.sim.base_world_position())
			nearest_base = minf(nearest_base, distance)
			furthest_base = maxf(furthest_base, distance)
			frames[int(actor.frame)] = true
			remained_on_bench = remained_on_bench and not app.sim.heroes[1].deployed
			if frames.size() >= 3 and not retreat_captured:
				await screenshot("furina_deployment_retreat")
				retreat_captured = true
		await process_frame
	check(not app.recruitment_transition_active and app.battle.departing_recruit.is_empty(), "retreat finishes and removes its transient actor")
	check(frames.size() > 1 and furthest_base - nearest_base > 150.0 and nearest_base < 30.0, "retreat position approaches the actual crystal while walking frames advance")
	check(remained_on_bench and not app.sim.heroes[1].deployed and app.sim.rejected_recruits.has(1) and not app.recruited_heroes.has(1), "rejected Furina stays on the bench throughout the retreat")
	check(app.sim.heroes.filter(func(hero: Dictionary): return bool(hero.deployed)).size() == deployed_before and app.sim.state == "running", "BADEND occupies no deployment slot and battle resumes")
	await screenshot("furina_deployment_back_on_bench")
	for player: Node in app.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	app.queue_free()
	await process_frame
	app = null
	await process_frame
	print("FURINA DELIVERY QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
