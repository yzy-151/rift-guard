extends RefCounted
## Fixtures seed progress only; interactions dispatch through the real viewport.
var game
var tree: SceneTree
var output := ""
var checks := 0
var failures: Array[String] = []
var size := Vector2i(1280, 720)
var narrative = preload("res://scripts/qa_v94_endflow.gd").new()

func check(ok: bool, message: String) -> void:
	checks += 1
	print("V102 %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures.append(message)

func mouse(point: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point; motion.global_position = point
	game.get_viewport().push_input(motion, true)
	await tree.process_frame
	var event := InputEventMouseButton.new()
	event.position = point; event.global_position = point
	event.button_index = button; event.pressed = pressed
	game.get_viewport().push_input(event, true)
	await tree.process_frame

func click(control: Control) -> void:
	var point := control.get_global_transform() * (control.size * 0.5)
	await mouse(point, true); await mouse(point, false)

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.pressed = down
		game.get_viewport().push_input(event, true)
		await tree.process_frame

func capture(name: String) -> void:
	game.refresh()
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var image: Image = game.get_viewport().get_texture().get_image()
	check(image.get_size() == size and image.save_png(output.path_join(name + ".png")) == OK, "native capture " + name)

func paused(label: String) -> void:
	check(game.sim.state == "paused" and game.hud.pause_details.is_visible_in_tree() and not game.mode_select_panel.is_open() and not game.stage_select_panel.is_open() and not game.squad_panel.is_open(), label)

func run(target: Node) -> int:
	game = target; tree = game.get_tree()
	narrative.game = game; narrative.tree = tree
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
		if arg.begins_with("--qa-size="):
			var parts := arg.trim_prefix("--qa-size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	if not output.is_absolute_path():
		printerr("V102 requires absolute --qa-output")
		return 2
	narrative.output = output
	narrative.active_case = "opening"
	DirAccess.make_dir_recursive_absolute(output)
	game.set_process(false); game.set_physics_process(false)
	tree.root.mode = Window.MODE_WINDOWED; tree.root.borderless = true
	tree.root.size = size
	await tree.create_timer(0.2).timeout
	check(not game.qa_storage_path.is_empty(), "isolated save enabled")
	game.open_mode_menu()
	await capture("01-menu")
	await click(game.mode_select_panel.settings_button)
	check(game.settings_panel.is_open(), "menu settings mouse entry")
	await key(KEY_ESCAPE)
	await tree.create_timer(0.25).timeout
	check(game.mode_select_panel.is_open(), "settings returns menu")
	await click(game.mode_select_panel.buttons.rift_watch)
	check(game.stage_select_panel.is_open(), "campaign card mouse entry")
	check(game.stage_select_panel.buttons.stage_02.disabled, "fresh save locks stage two")
	await capture("02-stage-locks")
	await key(KEY_ESCAPE)
	check(game.mode_select_panel.is_open(), "stage Escape returns menu")
	await click(game.mode_select_panel.buttons.rift_watch)
	await click(game.stage_select_panel.back_button)
	check(game.mode_select_panel.is_open(), "stage Back returns menu")
	await click(game.mode_select_panel.buttons.rift_watch)
	await click(game.stage_select_panel.buttons.stage_01)
	check(game.squad_panel.is_open(), "stage one opens squad")
	await capture("03-squad")
	await key(KEY_ESCAPE)
	check(game.stage_select_panel.is_open() and not game.squad_panel.is_open(), "squad Escape returns stages")
	await click(game.stage_select_panel.buttons.stage_01)
	await click(game.squad_panel.confirm_button)
	check(await narrative.drive_narrative(func() -> bool: return game.sim.state == "running" and not game.story.active and not game.campaign_prelude_active and not game.squad_panel.is_open()), "opening narrative reaches battle")
	check(game.sim.current_stage_id == "stage_01" and game.sim.state == "running", "formation starts chosen stage")
	var deploy := Vector2(500, 360)
	var card: Control = game.hud.hero_buttons[0]
	await mouse(card.get_global_rect().get_center(), true)
	await mouse(deploy, false)
	check(game.sim.heroes[0].deployed, "HUD press and battlefield release deploy hero")
	var before: Vector2 = game.sim.heroes[0].pos
	await mouse(Vector2(620, 380), true, MOUSE_BUTTON_RIGHT)
	await mouse(Vector2(620, 380), false, MOUSE_BUTTON_RIGHT)
	for frame in 30: game.sim.tick(1.0 / 60.0)
	check(game.sim.heroes[0].pos.distance_to(before) > 2.0, "right click moves deployed hero")
	game.refresh()
	await click(game.hud.skill_button)
	check(game.skill_aiming, "active skill mouse aim")
	await mouse(Vector2(700, 350), true); await mouse(Vector2(700, 350), false)
	check(game.sim.heroes[0].skill_uses == 1 and not game.skill_aiming, "active skill commits once")
	game.sim.heroes[0].energy = game.sim.heroes[0].max_energy; game.refresh()
	await click(game.hud.ultimate_button)
	check(game.ultimate_aiming, "ultimate mouse aim")
	await mouse(Vector2(700, 350), true); await mouse(Vector2(700, 350), false)
	check(game.sim.heroes[0].ultimate_uses == 1 and game.sim.heroes[0].energy == 0 and not game.ultimate_aiming, "ultimate commits once and spends energy")
	await capture("04-battle")
	game.sim.run_state.pending_level_ups = 1; game.sim.reward_cooldown = 0.0
	game.sim.tick(0.0); game.refresh()
	check(game.sim.state == "reward", "level up opens card choice")
	await capture("05-rewards")
	var history: int = game.sim.rewards.history.size()
	await click(game.hud.reward_panel.buttons[0])
	if game.hud.reward_panel.target_overlay.visible: await key(KEY_1)
	check(game.sim.state == "running" and game.sim.rewards.history.size() == history + 1, "card mouse selection applies once")
	await click(game.hud.pause_button)
	paused("HUD pause opens menu")
	await capture("06-pause")
	var panel = game.hud.pause_presentation
	check(panel.actions.has("squad") and panel.actions.has("stages"), "pause exposes squad and stages")
	for id: String in panel.actions:
		var action: Control = panel.actions[id]
		check(action.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(1280,720)).encloses(action.get_global_rect()), "pause action in viewport: " + id)
	await click(panel.actions.settings); check(game.settings_panel.is_open(), "pause settings mouse entry")
	await key(KEY_ESCAPE); await tree.create_timer(0.25).timeout; paused("settings Escape returns pause")
	await click(panel.actions.squad); check(game.squad_panel.is_open(), "pause squad mouse entry")
	await key(KEY_ESCAPE); paused("squad Escape returns original pause")
	await click(panel.actions.squad); await click(game.squad_panel.back_button)
	paused("squad Back returns original pause")
	await click(panel.actions.stages); check(game.stage_select_panel.is_open(), "pause stages mouse entry")
	await key(KEY_ESCAPE); paused("stage Escape returns original pause")
	await click(panel.actions.stages); await click(game.stage_select_panel.back_button)
	paused("stage Back returns original pause")
	game.compendium.cleared_stages["stage_01"] = true
	game.story.seen["mode1_stage2_opening"] = true
	await click(panel.actions.stages)
	check(not game.stage_select_panel.buttons.stage_02.disabled, "stage unlock refreshes")
	await click(game.stage_select_panel.buttons.stage_02); await click(game.squad_panel.confirm_button)
	check(await narrative.drive_narrative(func() -> bool: return game.sim.state == "running" and not game.story.active and not game.campaign_prelude_active and not game.squad_panel.is_open()), "stage two narrative reaches battle")
	check(game.sim.current_stage_id == "stage_02" and game.sim.state == "running" and not game.story.active, "stage switch resets and starts stage two")
	await key(KEY_SPACE); await click(panel.actions.menu)
	check(game.mode_select_panel.is_open(), "pause menu mouse return")
	await click(game.mode_select_panel.buttons.endless_survival)
	check(game.endless_select_panel.is_open() and game.endless_select_panel.cards.size() == 3, "endless card opens three layouts")
	await capture("07-endless-layouts")
	await key(KEY_ESCAPE); check(game.mode_select_panel.is_open(), "endless layout Escape returns menu")
	for index in 3:
		await click(game.mode_select_panel.buttons.endless_survival)
		var layout_id: String = game.endless_select_panel.choices[index].id
		await click(game.endless_select_panel.cards[index])
		check(game.squad_panel.is_open(), "endless layout mouse entry " + layout_id)
		await key(KEY_ESCAPE)
		check(game.endless_select_panel.is_open(), "endless squad Escape returns layouts")
		await click(game.endless_select_panel.cards[index]); await click(game.squad_panel.confirm_button)
		check(game.sim.endless_mode and game.sim.endless_layout_id == layout_id and game.sim.state == "running" and game.sim.heroes[0].deployed, "endless starts selected layout " + layout_id)
		await capture("08-endless-" + layout_id)
		await key(KEY_SPACE); await click(panel.actions.squad)
		check(game.squad_panel.is_open(), "endless pause squad reachable")
		await key(KEY_ESCAPE); paused("endless squad returns pause")
		await click(panel.actions.stages)
		await key(KEY_F3)
		check(game.stage_select_panel.is_open() and not game.squad_panel.is_open(), "F3 cannot stack squad over stage selector")
		await click(game.stage_select_panel.buttons.stage_01)
		check(game.sim.run_state.mode_id == "endless_survival", "previewing campaign stage preserves endless mode")
		await key(KEY_ESCAPE); await key(KEY_ESCAPE)
		paused("cancel cross-mode preview returns endless pause")
		check(game.sim.endless_mode and game.sim.run_state.mode_id == "endless_survival", "cancel does not mutate live mode")
		await click(panel.actions.squad)
		check(game.squad_panel.is_open(), "squad remains reachable after cancelling cross-mode preview")
		await key(KEY_ESCAPE)
		await click(panel.actions.menu)
	check(game.mode_select_panel.is_open(), "all modes return to menu")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"size":str(size),"renderer":DisplayServer.get_name()}, "\t"))
	print("V102 MODES: %d checks, %d failures" % [checks, failures.size()])
	return 0 if failures.is_empty() else 1
