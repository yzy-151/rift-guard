extends SceneTree
const Main = preload("res://main.tscn")
var failures: Array[String] = []
var checks := 0
var output := ""
var record_motion := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg == "--record-hud": record_motion = true
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)

func capture(game: Node, filename: String) -> void:
	game.refresh()
	game.battle.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless" and not output.is_empty():
		await RenderingServer.frame_post_draw
		check(game.get_viewport().get_texture().get_image().save_png(output.path_join(filename + ".png")) == OK, "capture " + filename)

func pointer(point: Vector2, pressed: bool, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func click(point: Vector2, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	await pointer(point, true, button_index)
	await pointer(point, false, button_index)

func key(keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func exercise_input(game: Node) -> void:
	var hud = game.hud
	game.set_process_input(true)
	game.set_process_unhandled_input(true)
	game.story.active = false
	game.picker.hide()
	await pointer(hud.hero_buttons[0].get_global_rect().get_center(), true)
	check(game.dragging_hero_id == 0, "native card press starts deployment drag")
	await pointer(Vector2(490, 355), false)
	check(game.sim.heroes[0].deployed, "native drag release deploys traveler")
	await click(hud.hero_buttons[0].get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	check(not game.sim.heroes[0].deployed, "native right click recalls deployed traveler")
	await pointer(hud.hero_buttons[0].get_global_rect().get_center(), true)
	await pointer(Vector2(490, 355), false)
	await pointer(hud.hero_buttons[1].get_global_rect().get_center(), true)
	await pointer(Vector2(620, 430), false)
	await click(hud.hero_buttons[0].get_global_rect().get_center())
	check(game.selected_id == 0, "native card click selects the deployed hero")
	await click(hud.skill_button.get_global_rect().get_center())
	check(game.skill_aiming, "native Q button enters real targeting")
	await click(Vector2(900, 355))
	check(float(game.sim.heroes[0].skill_cooldown) > 0.0 and not game.skill_aiming, "native field click executes Q and starts cooldown")
	game.sim.heroes[0].energy = game.sim.heroes[0].max_energy
	game.refresh()
	await click(hud.ultimate_button.get_global_rect().get_center())
	check(game.ultimate_aiming, "native E button enters real targeting")
	await click(Vector2(880, 355))
	check(float(game.sim.heroes[0].ultimate_cooldown) > 0.0 and not game.ultimate_aiming, "native field click executes E and consumes readiness")
	await click(hud.formation_buttons.hold.get_global_rect().get_center())
	check(game.sim.formation_mode == "hold", "native formation button issues hold command")
	await key(KEY_X)
	check(game.sim.formation_mode == "follow", "keyboard formation shortcut still works")
	await click(hud.pause_button.get_global_rect().get_center())
	check(game.sim.state == "paused" and hud.pause_details.visible, "native pause button opens tactical menu")
	var remaining: float = hud.toast_remaining
	hud._process(10.0)
	check(is_equal_approx(hud.toast_remaining, remaining), "notification lifetime freezes while paused")
	await key(KEY_SPACE)
	check(game.sim.state == "running" and not hud.overlay.visible, "space resumes from tactical pause")
	for step in 60:
		game.battle.advance(1.0 / 30.0)
		game.fx.advance(1.0 / 30.0)
	game.refresh()
	await capture(game, "06-input-deployed")

func record(game: Node) -> void:
	if not record_motion or output.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(output.path_join("motion"))
	var squad: Array[String] = ["traveler", "hero_04", "hero_08"]
	game.sim.reset_stage("stage_02", squad, 92003)
	game.sim.start()
	game.sim.run_state.crystal_level = 8
	game.hud.reset_transients()
	game.hud.reduced = false
	game.selected_id = 0
	game.battle.selected_id = 0
	game.battle.reset_transients()
	game.fx.active.clear()
	for hero: Dictionary in game.sim.heroes:
		hero.deployed = true
		hero.pos = Vector2(420 + int(hero.id) * 110, 390)
		hero.target = hero.pos
	game.sim.heroes[0].skill_cooldown = 2.5
	game.hud.set_process(false)
	for frame in 144:
		if frame == 10: game.hud.announce_contract("元素演练", "结晶盾 +120")
		if frame == 28:
			game.sim.heroes[0].hp *= 0.58
			game.sim.run_state.crystal_xp += 150
		if frame == 46:
			game.sim.run_state.buff_levels[str(game.sim.database.cards[0].id)] = 2
		if frame == 65: game.sim.heroes[0].energy = game.sim.heroes[0].max_energy
		if frame == 87: game.select_hero(1)
		if frame == 110: game.select_hero(0)
		game.sim.tick(1.0 / 24.0)
		game.process_events()
		game.battle.advance(1.0 / 24.0)
		game.fx.advance(1.0 / 24.0)
		game.refresh()
		game.hud._process(1.0 / 24.0)
		game.battle.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		game.get_viewport().get_texture().get_image().save_png(output.path_join("motion/%04d.png" % frame))
	game.hud.set_process(true)

func exercise_restart_lifecycle(game: Node) -> void:
	var hud = game.hud
	hud.reset_transients()
	game.refresh()
	var previous_stage: String = game.sim.current_stage_id
	var previous_seed: int = game.sim.run_seed
	hud.announce_contract("重开前契约", "旧局奖励")
	hud.announce_deployment("旧局增援")
	hud.announce_boss_skill_warning("重开前危险技能", 8.0, 2)
	var feedback: Array[Dictionary] = [{"kind":"terrain_react", "terrain_id":"restart_spring", "type":"spring", "phase":"pulse", "pos":Vector2(1280,720), "area":Rect2(1248,688,64,64), "element":"hydro", "value":1}]
	game.battle.accept_events(feedback)
	check(not hud.active_toast.is_empty() and not hud.toast_queue.is_empty() and hud.boss_skill_warning_panel.visible and not game.battle.functional_terrain_art.bursts.is_empty(), "restart fixture includes live notices, boss danger and spring feedback")
	await game.restart(true)
	check(game.sim.current_stage_id == previous_stage and game.sim.run_seed == previous_seed, "real restart retains stage and seed instead of relying on HUD run key changes")
	check(hud.active_toast.is_empty() and hud.toast_queue.is_empty() and hud.toast_remaining == 0.0, "real restart clears active and queued HUD notices")
	check(hud.danger_remaining == 0.0 and not hud.boss_skill_warning_panel.visible, "real restart clears the old boss danger warning")
	check(game.battle.functional_terrain_art.bursts.is_empty(), "real restart clears old spring terrain feedback")
	game.sim.start()
	game.refresh()
	check(not hud.contract_notice_label.text.contains("重开前契约") and not hud.boss_skill_warning_panel.visible and game.battle.functional_terrain_art.bursts.is_empty(), "resuming the restarted run does not resurrect old transient feedback")

func run() -> void:
	var game = Main.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.set_process(false)
	game.set_physics_process(false)
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	var squad: Array[String] = ["traveler", "hero_04", "hero_08"]
	game.sim.reset_stage("stage_02", squad, 92003)
	game.sim.start()
	game.sim.run_state.crystal_level = 8
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	game.sim.drain_events()
	game.refresh()
	var hud = game.hud
	check(hud.has_method("change_buff_page"), "all buffs remain reachable beyond dock capacity")
	check(hud.has_method("reset_transients"), "HUD notifications can be cleared on scene transitions")
	check(hud.skill_name_label.get_theme_font_size("font_size") >= 11, "skill name readable at 1280")
	check(hud.skill_icon.size.x >= 48, "original Q skill icon is at least 48px")
	if failures.size() > 0:
		print("V92 HUD QA: %d checks; %d failures" % [checks, failures.size()])
		game.queue_free()
		await process_frame
		quit(1)
		return
	await capture(game, "01-idle")
	game.sim.run_state.crystal_level = 1
	game.refresh()
	check(hud.hero_buttons[1].disabled and hud.hero_lock_labels[1].visible, "locked character has disabled card and visible lock state")
	await capture(game, "07-locked")
	game.sim.run_state.crystal_level = 8
	game.refresh()
	check(hud.xp_bar.get_global_rect().size.y <= 4, "XP is a thin bar inside the top rail")
	check(hud.hero_hp_bars[0].get_global_rect().size.y <= 7, "hero HP stays inside its card")
	await exercise_input(game)
	hud.reset_transients()
	hud.announce_contract("元素演练", "结晶盾 +120")
	hud.announce_deployment("芙宁娜")
	check(hud.contract_notice_label.text.contains("契约达成"), "lower priority deployment does not overwrite contract completion")
	check(not hud.deployment_notice.visible, "deployment uses one shared ticker")
	check(not hud.contract_notice.get_global_rect().intersects(hud.wave_timeline_panel.get_global_rect()), "task ticker does not overlap countdown")
	hud.reset_transients()
	check(not hud.contract_notice.visible, "reset hides task notification")
	check(hud.deployment_queue.is_empty(), "reset clears queued deployments")
	hud.announce_contract("高优先级提示", "奖励")
	for i in 30: hud.announce_deployment("队员 %d" % i)
	check(hud.toast_queue.size() <= 6, "notification queue remains bounded under event burst")
	hud.reset_transients()
	game.sim.heroes[0].hp = game.sim.heroes[0].max_hp
	game.refresh()
	game.sim.heroes[0].hp *= 0.5
	game.refresh()
	check(hud.hero_hp_trails[0].value > hud.hero_hp_bars[0].value, "damage leaves a visible trailing loss bar")
	hud._process(2.1)
	check(is_equal_approx(hud.hero_hp_trails[0].value, hud.hero_hp_bars[0].value), "loss bar settles to actual HP")
	hud.reduced = true
	hud._pop(hud.skill_icon, 0.5)
	check(hud.motion_pops.is_empty(), "reduced effects suppress one shot motion")
	hud.reduced = false
	for i in 23:
		var card: Dictionary = game.sim.database.cards[i]
		game.sim.run_state.buff_levels[str(card.id)] = i % 5 + 1
	game.refresh()
	var seen: Dictionary = {}
	for page in 3:
		for detail: Dictionary in hud.buff_details:
			if not detail.is_empty(): seen[str(detail.get("id", ""))] = true
		hud.change_buff_page(1)
	check(seen.size() == 23, "paging visits every one of 23 distinct buffs")
	await click(hud.buff_previous.get_global_rect().get_center())
	check(hud.buff_page == 1, "native previous arrow moves to page two")
	await click(hud.buff_icons[0].get_global_rect().get_center())
	check(hud.info_popover.visible and not hud.info_body.text.is_empty(), "native buff icon click opens description")
	hud.dismiss_info_popover()
	hud.change_buff_page(-1)
	game.sim.heroes[0].name = "旅行者·跨越群星与无数世界的见证人"
	game.sim.heroes[0].deployed = true
	game.sim.heroes[1].deployed = true
	game.sim.heroes[1].hp = 0.0
	game.sim.heroes[2].deployed = false
	hud.signature = ""
	await capture(game, "02-long-name-many-buffs")
	check(hud.hero_name_labels[0].clip_text, "long names clip within card and retain tooltip")
	check(hud.hero_statuses[1].text.contains("倒地"), "downed state visible")
	check(hud.hero_statuses[2].text.contains("待命"), "bench state visible")
	game.sim.heroes[1].hp = game.sim.heroes[1].max_hp
	var boss: Dictionary = game.sim.spawn_enemy(Vector2(970, 370), "boss_01")
	boss.special_pending = false
	game.sim.drain_events()
	hud.announce_boss("裂隙君主")
	hud.announce_boss_skill_warning("极长名称·末日终焉连续斩击", 2.0, 3)
	await capture(game, "03-boss-warning")
	check(not hud.boss_alert_frame.visible, "danger warning supersedes arrival capsule")
	check(not hud.boss_panel.get_global_rect().intersects(hud.boss_skill_warning_panel.get_global_rect()), "boss HP and warning never overlap")
	hud.reduced = true
	hud.announce_contract("低特效模式", "不移动或闪烁")
	await capture(game, "04-reduced")
	hud.reduced = false
	hud.reset_transients()
	game.sim.select_endless_layout("wind_cross")
	game.sim.reset_stage("stage_endless", squad, 92003)
	game.sim.start()
	game.sim.drain_events()
	await capture(game, "05-endless")
	check(hud.wave_timeline_panel.visible, "endless forecast remains visible")
	await record(game)
	await exercise_restart_lifecycle(game)
	await click(hud.pause_button.get_global_rect().get_center())
	await click(hud.pause_menu_button.get_global_rect().get_center())
	check(game.mode_select_panel.is_open(), "native pause menu returns to main menu")
	print("V92 HUD QA: %d checks; %d failures" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
