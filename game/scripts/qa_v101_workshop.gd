extends RefCounted
## Runs through the shipped main scene and real viewport input.
var game
var tree: SceneTree
var output := ""
var mode := "full"
var checks := 0
var failures: Array[String] = []
var requested_size := Vector2i(1280, 720)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)

func click(control: Control) -> void:
	var viewport := control.get_viewport()
	if viewport is Window and viewport != tree.root:
		await tree.process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	var point := control.get_global_rect().get_center()
	if viewport is Window and viewport != tree.root:
		# Embedded Window controls use window-local coordinates; inject through
		# the root so Godot routes the real pointer to the modal first.
		point += Vector2(viewport.position)
		viewport = tree.root
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion, true)
	await tree.process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		viewport.push_input(event, true)
		await tree.process_frame

func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		game.get_viewport().push_input(event, true)
		await tree.process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var picture: Image = game.get_viewport().get_texture().get_image()
	check(picture.get_size() == requested_size, "capture resolution " + name)
	check(picture.save_png(output.path_join(name + ".png")) == OK, "capture saved " + name)

func fixture(workshop) -> void:
	var session = workshop.session
	session.paused = true
	session.auto_attack = false
	session.enemy_action = false
	session.speed = 0.5
	var found := Vector2.ZERO
	for y in range(250, 600, 50):
		for x in range(550, 1150, 50):
			if found == Vector2.ZERO and session.legal(Vector2(x, y), 70.0) and session.legal(Vector2(x + 180, y), 25.0): found = Vector2(x, y)
	check(found != Vector2.ZERO, "fixture has legal floor")
	check(session.place_hero("traveler", found), "place traveler")
	var card: Dictionary = session.sim.database.cards.filter(func(row: Dictionary): return str(row.get("id", "")) == "single_attack_common")[0]
	check(session.apply_card(card), "apply real attack card")
	check(session.place_enemy("grunt", found + Vector2(180, 0)), "place enemy")
	workshop.restore_scenario(session)

func run(owner_game) -> int:
	game = owner_game
	tree = game.get_tree()
	var shared := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
		if arg.begins_with("--qa-scenario-mode="): mode = arg.trim_prefix("--qa-scenario-mode=")
		if arg.begins_with("--qa-scenario-directory="): shared = arg.trim_prefix("--qa-scenario-directory=")
		if arg.begins_with("--qa-size="):
			var parts := arg.trim_prefix("--qa-size=").split("x")
			requested_size = Vector2i(int(parts[0]), int(parts[1]))
	if not output.is_absolute_path(): return 2
	DirAccess.make_dir_recursive_absolute(output)
	tree.create_timer(90.0).timeout.connect(func(): printerr("V101 QA timeout"); tree.quit(2))
	if DisplayServer.get_name() != "headless":
		tree.root.mode = Window.MODE_WINDOWED
		tree.root.borderless = true
		await tree.process_frame
		tree.root.size = requested_size
		await tree.create_timer(0.2).timeout
	game.open_mode_menu()
	await key(KEY_F10)
	await click(game.settings_panel.workshop_button)
	check(game.workshop != null, "mouse settings entry opens workshop")
	if game.workshop == null: return 1
	var workshop = game.workshop
	var bar = workshop.scenario_bar
	check(workshop.scenario_directory.begins_with(game.qa_storage_path), "QA scenario store isolated from player")
	if shared.is_absolute_path():
		bar.store = bar.Store.new(shared)
		bar.refresh_slots()
	var campaign = game.sim
	var campaign_time: float = campaign.elapsed
	if mode != "read":
		fixture(workshop)
		await click(bar.save_button)
		if bar.confirmation.visible: await click(bar.confirmation.get_ok_button())
		check(bool(bar.store.slot_info(1).get("occupied", false)), "mouse save writes first slot")
		check(not bar.load_button.disabled, "saved slot enables load")
		await capture("01-saved-scenario")
	if mode != "write":
		var old_session = workshop.session
		old_session.paused = false
		old_session.clear_units()
		await click(bar.load_button)
		check(bar.confirmation.visible and old_session.paused, "load asks and suspends time")
		await capture("02-load-confirmation")
		await key(KEY_DELETE)
		check(game.workshop == workshop, "dialog blocks workshop hotkeys")
		await click(bar.confirmation.get_cancel_button())
		check(workshop.session == old_session and not old_session.paused, "cancel keeps original session and playback")
		await key(KEY_F9)
		check(bar.confirmation.visible, "F9 opens load confirmation")
		await click(bar.confirmation.get_ok_button())
		check(workshop.session != old_session, "load atomically replaces workshop session")
		check(workshop.session.paused and is_zero_approx(workshop.session.sim.elapsed), "restored experiment paused at start")
		check(workshop.session.sim.enemies.size() == 1, "enemy restored across processes")
		check(workshop.session.sim.heroes[0].deployed and workshop.session.cards_applied.size() == 1, "hero and card restored")
		check(not workshop.buttons.auto.button_pressed and not workshop.buttons.enemy_action.button_pressed, "loaded toggle visuals synchronized")
		check(is_equal_approx(float(workshop.buttons.speed.get_selected_metadata()), 0.5), "speed picker synchronized")
		check(workshop.aiming.is_empty() and workshop.placement_kind.is_empty(), "stale placement and aiming canceled")
		check(workshop.battle.sim == workshop.session.sim and workshop.battle.effects.is_empty(), "view and transient effects synchronized")
		check(workshop.session.sim.heroes[0].damage > old_session.template("traveler").damage, "card affects real damage")
		await capture("03-restored-scenario")
		await key(KEY_F5)
		check(bar.confirmation.visible, "F5 asks before replacing occupied slot")
		await capture("04-overwrite-confirmation")
		await click(bar.confirmation.get_cancel_button())
		check(not bar.confirmation.visible, "overwrite cancel closes modal")
		check(workshop.session.paused, "save cancel preserves pause")
		for index in range(1, 3):
			bar.picker.select(index)
			bar.refresh_slots()
			check(bar.load_button.disabled, "empty slot cannot load")
		bar.picker.select(0)
		bar.refresh_slots()
		# Exercise recovery disclosure and refusal through the same real UI.
		await click(bar.save_button)
		await click(bar.confirmation.get_ok_button())
		var damaged := FileAccess.open(bar.store.slot_path(1), FileAccess.WRITE)
		damaged.store_string("{broken")
		damaged.close()
		bar.refresh_slots()
		check(bar.load_button.text.contains("恢复备份") and not bar.load_button.disabled, "backup recovery explicitly labeled")
		var before_recovery = workshop.session
		await click(bar.load_button)
		check(bar.confirmation.dialog_text.contains("上一份完整配置"), "recovery confirmation describes older configuration")
		await capture("05-backup-confirmation")
		await click(bar.confirmation.get_cancel_button())
		check(workshop.session == before_recovery, "cancel backup recovery preserves current experiment")
		await click(bar.load_button)
		await click(bar.confirmation.get_ok_button())
		check(workshop.session != before_recovery and workshop.session.message.contains("恢复"), "explicit recovery swaps and discloses backup")
		bar.picker.select(1)
		bar.refresh_slots()
		await click(bar.save_button)
		damaged = FileAccess.open(bar.store.slot_path(2), FileAccess.WRITE)
		damaged.store_string("{broken")
		damaged.close()
		var before_failure = workshop.session
		bar.refresh_slots()
		check(bar.load_button.disabled, "corrupt slot without backup cannot load")
		await key(KEY_F9)
		check(workshop.session == before_failure and not bar.confirmation.visible, "failed load leaves current scene intact")
		bar.picker.select(0)
		bar.refresh_slots()
		check(workshop.over_ui(bar.get_global_rect().get_center()), "scenario controls intercept placement")
		check(not bar.get_global_rect().intersects(workshop.drawer.get_global_rect()), "scenario rail does not overlap drawer")
	check(game.sim == campaign and is_equal_approx(campaign.elapsed, campaign_time), "campaign simulation unchanged")
	await click(workshop.buttons.exit)
	for frame in 3: await tree.process_frame
	check(game.workshop == null and game.settings_panel.is_open(), "returns to settings cleanly")
	var report := {"checks":checks, "failures":failures, "pid":OS.get_process_id(), "mode":mode, "renderer":DisplayServer.get_name()}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("V101 WORKSHOP: %d checks, %d failures" % [checks, failures.size()])
	return 0 if failures.is_empty() else 1
