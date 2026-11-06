extends SceneTree
const MOTION = preload("res://scripts/poster_motion.gd")
const POSTER = preload("res://scripts/poster_surface.gd")
const LAYOUT = preload("res://data/ui_layout_profile.tres")
var app
var panel
var checks := 0
var failures: Array[String] = []
var output_dir := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): output_dir = argument.trim_prefix("--qa-output=")
	_run.call_deferred()

func check(condition: bool, note: String) -> void:
	checks += 1
	print("PASS " + note if condition else "FAIL " + note)
	if not condition: failures.append(note)

func card(id: String) -> Dictionary:
	for item: Dictionary in app.sim.database.cards:
		if str(item.id) == id: return item.duplicate(true)
	return {}

func offer(ids: Array[String]) -> void:
	app.sim.rewards.offered.clear()
	for id in ids: app.sim.rewards.offered.append(card(id))
	app.sim.rewards.offer_revision += 1
	app.sim.rewards.rerolls_left = 2
	app.sim.run_state.pending_level_ups = 1
	app.sim.state = "reward"
	app.hud.signature = ""
	app.refresh()
	app.hud.overlay.hide()

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func click(button: Button) -> void:
	var point: Vector2 = root.get_screen_transform() * button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	Input.parse_input_event(move)
	await process_frame
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
		await process_frame

func at_layout() -> bool:
	for index in panel.buttons.size():
		var expected: Vector2 = LAYOUT.reward_grid_origin + Vector2(index * (LAYOUT.reward_card_size.x + LAYOUT.reward_card_gap.x), 0)
		if not panel.buttons[index].position.is_equal_approx(expected) or not panel.buttons[index].scale.is_equal_approx(Vector2.ONE): return false
	return panel.header_group.position.is_equal_approx(Vector2.ZERO) and panel.footer_group.position.is_equal_approx(Vector2.ZERO)

func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true
	app.set_process(false)
	app.set_physics_process(false)
	app.mode_select_panel.close()
	app.stage_select_panel.close()
	app.squad_panel.root.hide()
	app.dialogue.hide()
	app.hud.show()
	app.hud.get_child(0).show()
	app.battle.show()
	var squad: Array[String] = ["traveler","hero_03","hero_13"]
	app.sim.reset_stage("stage_01",squad,20261005)
	app.sim.start()
	panel = app.hud.reward_panel
	offer(["device_botanist","device_gatling","device_iron_nut"])
	check(panel.visible and panel.buttons.size() == 3, "three real card choices appear")
	check(MOTION.active(panel) != null and panel.buttons[2].position.y > LAYOUT.reward_grid_origin.y, "staggered entrance starts below its stable layout")
	var serial: int = panel.opening_serial
	for frame in 12: panel.display(app.sim)
	check(panel.opening_serial == serial, "repeated HUD refresh never restarts the entrance")
	await create_timer(0.65).timeout
	check(at_layout(), "all card buttons settle at the profile positions")
	check(panel.icons.all(func(icon:Sprite2D): return icon.texture != null and is_equal_approx(icon.scale.x,icon.scale.y)), "all generated icons preserve their proportions")
	check(LAYOUT.reward_icon_rect.size.y >= 140 and panel.card_art.size() == 3, "large sticker illustrations replace the old card frame textures")
	check(panel.titles[0].get_theme_font("font") == POSTER.TYPE and panel.descriptions[0].get_theme_color("font_color") == POSTER.INK, "poster typography and high contrast card body stay consistent")
	check(panel.tags[0].text.contains("机关") and panel.tags[0].text.contains("0 / 5") and not panel.summary_labels[0].text.is_empty(), "real device target, stack limit and benefit preview remain visible")
	check(panel.buttons[0].tooltip_text.contains(str(card("device_botanist").description)), "the entire card description remains available in its tooltip")
	panel.buttons[1].grab_focus()
	await create_timer(0.17).timeout
	check(panel.focused_index == 1 and panel.card_art[1].selected and panel.card_bodies[1].position.y < 0, "keyboard focus lifts the paper and paints the action stripe")
	check(at_layout(), "hover leaves the entrance owner's position and scale untouched")
	await click(panel.buttons[0])
	check(int(app.sim.run_state.buff_levels.get("device_botanist",0)) == 1 and app.sim.state == "running", "click anywhere on the full card takes the actual buff")
	check(not panel.visible and at_layout() and MOTION.active(panel) == null, "choice hides and cancels the completed entrance cleanly")
	for index in 8:
		offer(["device_repeater","device_threepeater","device_gatling"])
		await process_frame
		panel.hide()
		check(at_layout() and MOTION.active(panel) == null and panel.card_bodies.all(func(body:Control): return body.position == Vector2.ZERO and body.scale == Vector2.ONE), "rapid hide resets all entrance and hover poses %d" % index)
	app.hud.reduced = true
	offer(["device_repeater","device_threepeater","device_gatling"])
	check(panel.buttons[0].position == LAYOUT.reward_grid_origin, "low effects keeps card positions stationary during the fade")
	await create_timer(0.18).timeout
	check(at_layout() and is_equal_approx(panel.buttons[0].modulate.a,1.0), "low effects entrance settles within its short fade")
	app.hud.reduced = false
	panel.hide()
	offer(["device_repeater","device_threepeater","device_gatling"])
	await key(KEY_2)
	check(int(app.sim.run_state.buff_levels.get("device_threepeater",0)) == 1 and not panel.visible, "number shortcut can choose while entrance is still active")
	offer(["single_attack_common","global_attack_1","device_rooted"])
	await create_timer(0.65).timeout
	await click(panel.buttons[0])
	check(panel.target_overlay.visible and panel.target_card_index == 0 and app.sim.state == "reward", "character cards open the live target picker")
	check(panel.target_previews.size() == 3 and not panel.target_hp_labels[1].text.is_empty(), "target picker keeps actual character artwork and upgrade preview")
	await key(KEY_ESCAPE)
	check(not panel.target_overlay.visible and panel.target_card_index == -1 and MOTION.active(panel.target_overlay) == null, "Escape restores cards and cancels target entrance")
	await key(KEY_1)
	var traveler_damage: float = app.sim.heroes[0].damage
	var second_damage: float = app.sim.heroes[1].damage
	await key(KEY_2)
	check(app.sim.state == "running" and is_equal_approx(float(app.sim.heroes[0].damage),traveler_damage) and float(app.sim.heroes[1].damage) > second_damage, "number target selection applies the buff only to the chosen hero")
	offer(["global_attack_1","device_rooted","device_photosynthesis"])
	await create_timer(0.65).timeout
	await click(panel.synergy_button)
	check(panel.synergy_overlay.visible and panel.synergy_rows.size() == 8, "poster synergy overlay keeps all real recipes")
	var revision: int = app.sim.rewards.offer_revision
	await key(KEY_R)
	check(app.sim.rewards.offer_revision == revision, "synergy modal blocks background reroll keys")
	await key(KEY_ESCAPE)
	check(not panel.synergy_overlay.visible and app.sim.state == "reward", "synergy return preserves the pending reward")
	await key(KEY_R)
	check(app.sim.rewards.rerolls_left == 1 and app.sim.rewards.offer_revision > revision, "real reroll retains two-use budget and refreshes the offer")
	await key(KEY_R)
	check(app.sim.rewards.rerolls_left == 0 and panel.reroll_button.disabled, "second reroll disables the styled button")
	revision = app.sim.rewards.offer_revision
	await key(KEY_R)
	check(app.sim.rewards.offer_revision == revision, "third reroll cannot bypass its budget")
	await create_timer(0.65).timeout
	check(at_layout(), "back-to-back rerolls finish at the original geometry without drift")
	panel.hide()
	for player: Node in app.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	var report := {"checks":checks,"failures":failures,"passed":failures.is_empty()}
	if not output_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(output_dir)
		var file := FileAccess.open(output_dir.path_join("reward-poster.json"),FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report,"\t"))
	print("REWARD POSTER QA: %d checks / %d failures" % [checks,failures.size()])
	app.queue_free()
	app = null
	panel = null
	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	quit(0 if failures.is_empty() else 1)
