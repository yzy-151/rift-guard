extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V17 PASS: " + message)
	else:
		failures += 1
		push_error("V17 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.hud.signature = ""
	game.refresh()
	await game.get_tree().create_timer(0.55).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v17-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func click_control(game, control: Control) -> void:
	if DisplayServer.get_name() == "headless":
		control.pressed.emit()
		await game.get_tree().process_frame
		return
	var logical_point := control.get_global_rect().get_center()
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var point: Vector2 = logical_point if DisplayServer.get_name() == "headless" else logical_point * window_size / viewport_size
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await game.get_tree().process_frame

func run(game) -> void:
	game.open_mode_menu()
	await game.get_tree().process_frame
	expect(game.mode_select_panel.is_open(), "mode menu opens")
	await click_control(game, game.mode_select_panel.buttons["endless_survival"])
	expect(game.sim.endless_mode and game.sim.state == "running", "real pointer click enters endless mode")
	game.sim.events.clear()
	game.sim.enemies.clear()
	game.sim.elapsed = 360.0
	game.sim.endless_spawn_timer = 0.0
	game.sim._endless_spawn_tick(0.1)
	expect(game.sim.enemies.size() >= 6, "late endless spawn tick creates a dense group")

	await click_control(game, game.hud.pause_button)
	expect(game.sim.state == "paused" and game.hud.pause_details.visible, "real pointer click opens tactical pause")
	expect(game.hud.pause_status_label.text.contains("无尽生存") and game.hud.pause_status_label.text.contains("幸运"), "pause contains mode, stage, battle state and luck")
	expect(game.hud.pause_buff_labels.size() == 12 and game.hud.pause_hero_labels.size() == 3, "pause contains build levels and three character sheets")
	var pause_buttons: Array[Button] = [game.hud.pause_settings_button, game.hud.pause_restart_button, game.hud.pause_squad_button, game.hud.pause_stage_button, game.hud.pause_menu_button]
	expect(pause_buttons.all(func(item: Button) -> bool: return item.visible and item.get_parent() == game.hud.pause_details), "settings, restart, squad, stage and menu actions are consolidated in pause")
	await capture(game, "01-pause-hub")

	await click_control(game, game.hud.pause_settings_button)
	expect(game.settings_panel.is_open(), "pause settings button opens volume settings")
	game.settings_panel.close()
	await game.get_tree().create_timer(0.24).timeout
	await game.get_tree().process_frame
	expect(game.sim.state == "paused" and game.hud.pause_details.visible, "closing settings returns to paused battle")

	await click_control(game, game.hud.pause_squad_button)
	expect(game.squad_panel.is_open(), "pause squad button opens formation")
	game.squad_panel.root.hide()
	game.refresh()
	await click_control(game, game.hud.pause_stage_button)
	expect(game.stage_select_panel.is_open(), "pause stage button opens stage list")
	game.stage_select_panel.close()
	game.refresh()

	game.sim.enemies.clear()
	game.sim.elapsed = 90.0
	game.sim.endless_next_boss_at = 90.0
	game.sim.endless_boss_index = 0
	game.sim._spawn_endless_boss_if_due()
	var bosses: Array = game.sim.enemies.filter(func(enemy: Dictionary) -> bool: return str(enemy.get("kind", "")).begins_with("boss_"))
	expect(bosses.size() == 1 and bosses[0].kind == "boss_01", "first endless boss arrives at 90 seconds")
	if not bosses.is_empty():
		bosses[0].pos = game.sim.heroes[0].pos + Vector2(330, 10)
		bosses[0].hp = bosses[0].max_hp * 0.30
		game.sim._update_boss_phase(bosses[0])
		expect(int(bosses[0].boss_phase) == 3, "boss changes into its third phase below 35 percent health")
	game.sim.state = "running"
	game.hud.overlay.hide()
	game.refresh()
	await capture(game, "02-endless-boss-phase3")

	var boss_styles: Dictionary = {}
	for boss_id in game.sim.ENDLESS_BOSS_IDS:
		boss_styles[game.sim.Catalog.ENEMIES[boss_id].boss_style] = true
	expect(game.sim.ENDLESS_BOSS_IDS.size() == 6 and boss_styles.size() == 6, "endless roster contains six mechanically distinct three-phase bosses")
	var thresholds: Array = game.sim.database.stages["stage_01"].xp_thresholds
	expect(int(thresholds[-1]) > int(thresholds[5]) * 10, "late campaign upgrades slow down sharply")

	print("V17 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await game.get_tree().create_timer(0.08).timeout
	game.get_tree().quit(failures)
