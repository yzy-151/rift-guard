extends RefCounted
## Explicit --ui-test diagnostics; not part of normal play.
var game
var checks: int = 0
var failures: int = 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("UI FAIL: " + message)
	else:
		print("UI PASS: " + message)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
	await game.get_tree().process_frame

func mouse(point: Vector2, which: MouseButton) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = which
		event.pressed = pressed
		Input.parse_input_event(event)
	await game.get_tree().process_frame

func capture(name: String) -> void:
	game.refresh()
	await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png("user://m3-" + name + ".png")

func step(frames: int) -> void:
	for i in frames:
		game.sim.tick(1.0 / 60.0)
		game.process_events()
		game.battle.advance(1.0 / 60.0)

func run(root) -> void:
	game = root
	await capture("title")
	await key(KEY_ENTER)
	expect(game.sim.state == "running", "Enter starts battle")
	await key(KEY_2)
	expect(game.selected_id == 1, "2 selects fire hero")
	var other_target: Vector2 = game.sim.heroes[0].target
	await mouse(Vector2(500, 480), MOUSE_BUTTON_RIGHT)
	expect(game.sim.heroes[1].target == Vector2(500, 480) and game.sim.heroes[0].target == other_target, "right click moves only selected hero")
	await mouse(Vector2(700, 620), MOUSE_BUTTON_LEFT)
	expect(game.selected_id == 2, "third hero card selects water hero")
	await mouse(Vector2(1100, 250), MOUSE_BUTTON_RIGHT)
	expect(game.sim.heroes[2].target == Vector2(530, 250), "water move clamps to deployment zone")
	await mouse(game.sim.heroes[0].pos, MOUSE_BUTTON_LEFT)
	expect(game.selected_id == 0, "clicking guard selects guard")
	await key(KEY_SPACE)
	var saved: Vector2 = game.sim.heroes[0].target
	await mouse(Vector2(450, 450), MOUSE_BUTTON_RIGHT)
	expect(game.sim.state == "paused" and game.sim.heroes[0].target == saved, "pause modal blocks movement")
	await key(KEY_3)
	expect(game.selected_id == 0, "pause blocks hero hotkeys")
	for i in 8:
		await key(KEY_TAB)
		expect(game.get_viewport().gui_get_focus_owner() == game.hud.modal_action, "pause focus remains trapped " + str(i + 1))
	await capture("paused")
	await key(KEY_ENTER)
	expect(game.sim.state == "running", "Enter activates focused resume button")
	game.restart()
	game.primary()
	step(1150)
	await capture("battle")
	game.sim.damage_hero(2, 10000)
	game.refresh()
	await key(KEY_3)
	var dead_target: Vector2 = game.sim.heroes[2].target
	await mouse(Vector2(500, 500), MOUSE_BUTTON_RIGHT)
	expect(game.sim.heroes[2].target == dead_target and game.sim.heroes[2].hp == 0, "downed hero cannot be moved by UI")
	await capture("down")
	game.restart()
	game.sim.reset(303)
	game.primary()
	var rewards_seen: int = 0
	for i in 30000:
		step(1)
		if game.sim.state == "reward":
			rewards_seen += 1
			game.refresh()
			await game.get_tree().process_frame
			expect(game.hud.reward_panel.visible and game.sim.rewards.offered.size() == 3, "reward panel opens at node " + str(rewards_seen))
			if rewards_seen == 1:
				await capture("reward")
				var elapsed: float = game.sim.elapsed
				step(120)
				await key(KEY_SPACE)
				expect(game.sim.state == "reward" and game.sim.elapsed == elapsed, "reward screen freezes battle and cannot be skipped")
				for n in 5:
					await key(KEY_TAB)
					expect(game.get_viewport().gui_get_focus_owner() in game.hud.reward_panel.buttons, "reward focus remains within cards " + str(n + 1))
				await key(KEY_1)
			elif rewards_seen == 2:
				await mouse(Vector2(265, 495), MOUSE_BUTTON_LEFT)
			elif rewards_seen == 3:
				await key(KEY_ENTER)
			else:
				await key(KEY_1)
			expect(game.sim.state == "between" and game.sim.rewards.history.size() == rewards_seen, "reward choice commits once " + str(rewards_seen))
			game.choose_reward(0)
			expect(game.sim.rewards.history.size() == rewards_seen, "repeat callback cannot grant twice " + str(rewards_seen))
		if game.sim.state in ["won", "lost"]:
			break
	expect(rewards_seen == 4 and game.sim.wave == 5, "four choices followed by final node with no extra reward")
	expect(game.sim.team_level == 5, "shared experience reaches level five")
	expect(game.sim.state == "won" and game.sim.reactions > 0, "mixed-wave run wins with reactions")
	await capture("victory")
	await key(KEY_ENTER)
	expect(game.sim.state == "running" and game.sim.reactions == 0 and game.sim.rewards.history.is_empty() and game.sim.team_level == 1 and game.sim.heroes[2].hp == game.sim.heroes[2].max_hp, "result retry resets all heroes and reaction count")
	game.sim.base_hp = 1
	game.sim.spawn_enemy(Vector2(119, 450), "armored")
	step(1)
	expect(game.sim.state == "lost", "defeat still works")
	await capture("defeat")
	for dimensions in [Vector2i(960, 540), Vector2i(1600, 900)]:
		DisplayServer.window_set_size(dimensions)
		await game.get_tree().process_frame
		await capture("%dx%d" % [dimensions.x, dimensions.y])
	print("M3 UI TESTS: %d checks; %d failures" % [checks, failures])
	game.get_tree().quit(0 if failures == 0 else 1)
