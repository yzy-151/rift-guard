extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if game.mobile_controls == null:
		_fail("mobile overlay was not created")
		return
	game.enter_home()
	var start: Vector2 = game.home_panel.player_pos
	game.mobile_controls.directions.left = true
	game._process(0.016)
	game.home_panel._process(0.3)
	if game.home_panel.player_pos.x >= start.x or game.home_panel.facing >= 0.0:
		_fail("home touch movement or facing failed")
		return
	game.mobile_controls.directions.left = false
	game._set_mobile_move_mode(false)
	if not game.mobile_move_mode or game.mobile_move_all:
		_fail("selected hero movement mode failed")
		return
	game._set_mobile_move_mode(true)
	if not game.mobile_move_mode or not game.mobile_move_all:
		_fail("squad movement mode failed")
		return
	game._set_mobile_move_mode(true)
	if game.mobile_move_mode:
		_fail("movement mode did not toggle off")
		return
	game.home_panel.close()
	game.mode_select_panel.close()
	game.sim.state = "running"
	game.selected_id = 0
	game.sim.heroes[0].deployed = true
	var hero: Dictionary = game.sim.heroes[0]
	var destination: Vector2 = hero.pos + Vector2(70, 30)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = game.battle.get_global_transform() * game.battle.world_to_screen(destination)
	game._set_mobile_move_mode(false)
	game._unhandled_input(tap)
	if game.mobile_move_mode or Vector2(game.sim.heroes[0].target).distance_to(Vector2(hero.pos)) < 10.0:
		_fail("battle touch movement did not command the hero")
		return
	print("MOBILE_CONTROLS_OK")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
