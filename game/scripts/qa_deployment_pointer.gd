extends SceneTree

var app
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS " + label if condition else "FAIL " + label)
	if not condition: failures.append(label)

func pointer(point: Vector2, pressed: bool) -> void:
	point = root.get_screen_transform() * point
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	Input.parse_input_event(move)
	await process_frame
	var click := InputEventMouseButton.new()
	click.position = point
	click.global_position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	Input.parse_input_event(click)
	await process_frame

func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.set_physics_process(false)
	app.mode_select_panel.close()
	var squad: Array[String] = ["traveler", "hero_03"]
	app.sim.reset_stage("stage_01", squad, 197)
	app.sim.run_state.crystal_level = 6
	app.sim.start()
	app.hud.get_child(0).show()
	app.refresh()
	await process_frame
	var hero_button: Button = app.hud.hero_buttons[1]
	var origin := hero_button.get_global_rect().get_center()
	var destination: Vector2 = app.battle.get_global_transform() * app.battle.world_to_screen(Vector2(610, 390))
	check(not app.sim.heroes[1].deployed and not hero_button.disabled, "Furina starts on a usable bench card")
	await pointer(origin, true)
	check(app.dragging_hero_id == 1 and app.battle.deploy_preview_active, "actual HUD mouse press begins deployment drag")
	await pointer(destination, false)
	check(app.story.active and app.story_resume == "recruit", "actual battlefield mouse release opens recruitment dialogue")
	check(app.story.key == "deploy_hero_03_0" and app.story.graph_mode and app.story.has_choices() and app.story.current().text == "哈？我堂堂水之魔神也要去和魔物战斗吗", "actual drag presents master-authored deployment choices")
	check(app.dragging_hero_id == -1 and not app.battle.deploy_preview_active, "mouse release clears drag state")
	print("DEPLOYMENT POINTER QA: %d failures" % failures.size())
	app.queue_free()
	await process_frame
	app = null
	await process_frame
	quit(0 if failures.is_empty() else 1)
