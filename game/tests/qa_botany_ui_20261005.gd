extends SceneTree
var app
var checks := 0
var failures: Array[String] = []
var out := "C:/Users/23081/Desktop/codex/rift-guard/qa/botany-20261005"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): out = arg.trim_prefix("--qa-output=")
	run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("BOTANY UI: " + label)
func mouse(point: Vector2, down: bool, button := MOUSE_BUTTON_LEFT) -> void:
	await move_mouse(point)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = down
	root.push_input(event,true)
	await process_frame
func move_mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	await process_frame
func click(point: Vector2) -> void:
	await mouse(point,true)
	await mouse(point,false)
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	event.pressed = false
	root.push_input(event,true)
	await process_frame
func floor_screen(point: Vector2) -> Vector2:
	return app.battle.get_global_transform() * app.battle.world_to_screen(point)
func clear_cell(sim, kind: String) -> Vector2:
	sim.battle_devices.selected_kind = kind
	for row in range(200,560,40):
		for column in range(250,1150,60):
			var point := Vector2(column,row)
			if sim.battle_devices.placement_error(sim,point).is_empty(): return point
	return Vector2.INF
func run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.test_mode = true
	app.set_process(false)
	app.set_physics_process(false)
	app.mode_select_panel.close()
	app.stage_select_panel.close()
	app.squad_panel.root.hide()
	app.dialogue.hide()
	app.dialogue.animation_waiting = false
	app.home_panel.close()
	app.settings_panel.close()
	app.compendium_panel.close()
	app.picker.hide()
	app.story.active = false
	app.campaign_prelude_active = false
	app.hud.get_child(0).show()
	var sim = app.sim
	var squad: Array[String] = ["traveler"]
	sim.reset_stage("stage_01",squad,51060)
	sim.start()
	sim.battle_devices.gold = 10000
	app.refresh()
	await process_frame
	var shop = app.hud.device_shop_ui
	check(not app.qa_storage_path.is_empty(), "main stores test saves in isolated QA directory")
	check(shop.visible and shop.capacity_label.text == "0/25 机关", "actual campaign HUD displays 25-cell capacity")
	check(shop.buttons.size() == 10 and shop.drawer_buttons.size() == 10 and shop.QUICK_KINDS.size() == 5, "ten seeds are accessible without crowding five quick slots")
	check(not shop.drawer.visible, "seed drawer begins closed")
	var quick_rects: Array[Rect2] = []
	for kind: String in shop.QUICK_KINDS:
		var rectangle: Rect2 = shop.buttons[kind].get_global_rect()
		check(not rectangle.intersects(shop.drawer_toggle.get_global_rect()) and not rectangle.intersects(app.hud.pause_button.get_global_rect()), kind + " quick slot clears coin bag and pause")
		for previous: Rect2 in quick_rects: check(not previous.intersects(rectangle), kind + " quick slot has positive neighbour gap")
		quick_rects.append(rectangle)
	await click(shop.drawer_toggle.get_global_rect().get_center())
	check(shop.drawer.visible and sim.battle_devices.selected_kind.is_empty(), "actual coin-bag click opens drawer without buying or selecting")
	var all_rects: Array[Rect2] = []
	for kind: String in shop.KINDS:
		var button: Button = shop.drawer_buttons[kind]
		var rectangle: Rect2 = button.get_global_rect()
		check(shop.drawer.get_global_rect().encloses(rectangle), kind + " seed is fully contained in semantic drawer")
		check(shop.kind_at(rectangle.get_center()) == kind, kind + " drawer hit test matches the actual seed control")
		for previous: Rect2 in all_rects: check(not previous.intersects(rectangle), kind + " drawer slot does not overlap previous seeds")
		all_rects.append(rectangle)
	await key(KEY_ESCAPE)
	check(not shop.drawer.visible and sim.state == "running", "Esc closes seed drawer without pausing the battle")
	for kind: String in shop.KINDS:
		if not shop.drawer.visible: await click(shop.drawer_toggle.get_global_rect().get_center())
		var gold: int = sim.battle_devices.gold
		var count: int = sim.battle_devices.active_count()
		await click(shop.drawer_buttons[kind].get_global_rect().get_center())
		check(sim.battle_devices.selected_kind == kind and not shop.drawer.visible, kind + " real seed click selects and closes drawer")
		check(sim.battle_devices.gold == gold and sim.battle_devices.active_count() == count, kind + " UI click never buys or deploys on covered floor")
		var point := clear_cell(sim,kind)
		check(point.is_finite(), kind + " finds a valid cell in the real first-stage terrain")
		if not point.is_finite(): continue
		await click(floor_screen(point))
		check(sim.battle_devices.active_count() == count+1 and sim.battle_devices.gold == gold-sim.battle_devices.price_of(kind), kind + " real floor click spends exact price once")
		check(sim.battle_devices.selected_kind.is_empty(), kind + " successful placement exits selection")
	check(sim.battle_devices.active_count() == 10 and shop.capacity_label.text == "10/25 机关", "HUD count tracks ten real placed kinds")
	var wall: Dictionary = sim.battle_devices.placed.filter(func(device: Dictionary) -> bool: return device.kind == "barricade")[0]
	var pad: Dictionary = sim.battle_devices.placed.filter(func(device: Dictionary) -> bool: return device.kind == "power")[0]
	var hero_card: Button = app.hud.hero_buttons[0]
	await mouse(hero_card.get_global_rect().get_center(),true)
	check(app.dragging_hero_id == 0, "actual benched hero card starts deployment drag")
	await move_mouse(floor_screen(wall.pos))
	check(app.battle.deploy_preview_active and not app.battle.deploy_preview_valid, "hero preview rejects an occupied plant cell")
	await mouse(floor_screen(wall.pos),false)
	check(not sim.heroes[0].deployed and app.dragging_hero_id == -1, "actual drop on planted Wall-nut refuses overlapping hero")
	await mouse(hero_card.get_global_rect().get_center(),true)
	await move_mouse(floor_screen(pad.pos))
	check(app.battle.deploy_preview_valid, "hero preview still allows purchased attack pad")
	await mouse(floor_screen(pad.pos),false)
	check(sim.heroes[0].deployed and Vector2(sim.heroes[0].pos).distance_to(pad.pos) < .001, "actual hero drop on buff pad deploys at intended location")
	sim.run_state.buff_levels.device_soil_discount = 3
	app.refresh()
	await process_frame
	for kind: String in shop.KINDS:
		var displayed := int(shop.drawer_prices[kind].text)
		check(displayed == sim.battle_devices.price_of(kind), kind + " drawer price tracks live soil discount")
		if shop.QUICK_KINDS.has(kind): check(int(shop.price_labels[kind].text) == displayed, kind + " quick and drawer prices stay synchronized")
	await click(shop.buttons.range.get_global_rect().get_center())
	var gold: int = sim.battle_devices.gold
	await mouse(floor_screen(Vector2(670,480)),true,MOUSE_BUTTON_RIGHT)
	await mouse(floor_screen(Vector2(670,480)),false,MOUSE_BUTTON_RIGHT)
	check(sim.battle_devices.selected_kind.is_empty() and sim.battle_devices.gold == gold and sim.state == "running", "right-click cancels selected purchase without spending or pausing")
	await click(shop.buttons.power.get_global_rect().get_center())
	await key(KEY_ESCAPE)
	check(sim.battle_devices.selected_kind.is_empty() and sim.battle_devices.gold == gold and sim.state == "running", "Esc cancels selected purchase without pausing")
	# Fill the remaining slots through real gameplay placement, then exercise the UI limit.
	while sim.battle_devices.active_count() < 25:
		var point := clear_cell(sim,"power")
		if not point.is_finite(): break
		sim.battle_devices.place(sim,point)
	app.refresh()
	await process_frame
	check(sim.battle_devices.active_count() == 25 and shop.capacity_label.text == "25/25 机关", "HUD displays the fully occupied 25/25 limit")
	gold = sim.battle_devices.gold
	await click(shop.buttons.pea.get_global_rect().get_center())
	app.refresh()
	await process_frame
	check(sim.battle_devices.selected_kind.is_empty() and sim.battle_devices.gold == gold and not shop.feedback.text.is_empty(), "click beyond cap gives feedback without selecting or charging")
	sim.state = "paused"
	app.refresh()
	await process_frame
	check(shop.drawer_toggle.disabled and not shop.drawer.visible, "pause disables and closes the seed bag")
	for kind: String in shop.KINDS: check(shop.buttons[kind].disabled, kind + " cannot be purchased while paused")
	sim.reset_stage("stage_endless",squad,51061)
	app.refresh()
	await process_frame
	check(not shop.visible and not shop.drawer.visible, "endless hides unavailable device shop and drawer")
	await finish()
func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child: Node in node.get_children(): stop_audio(child)
func finish() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var output := FileAccess.open(out+"/ui-input.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	output.close()
	print("BOTANY UI: %d checks, %d failures" % [checks,failures.size()])
	stop_audio(app)
	app.queue_free()
	app = null
	await process_frame
	await process_frame
	await create_timer(.12).timeout
	quit(0 if failures.is_empty() else 1)
