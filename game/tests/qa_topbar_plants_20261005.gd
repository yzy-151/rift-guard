extends SceneTree

const ITEMS = preload("res://scripts/battle_devices.gd").ITEMS
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
var app
var checks := 0
var failures: Array[String] = []
var out := "C:/Users/23081/Desktop/codex/rift-guard/qa/topbar-plants-20261005"
var hover_events := 0
var drop_events := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): out = arg.trim_prefix("--qa-output=")
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("TOPBAR PLANTS: " + label)

func mouse(point: Vector2, down: bool, button := MOUSE_BUTTON_LEFT) -> void:
	await move_mouse(point)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = down
	root.push_input(event, true)
	await process_frame

func move_mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame

func click(point: Vector2) -> void:
	await mouse(point, true)
	await mouse(point, false)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func floor_screen(point: Vector2) -> Vector2:
	return app.battle.get_global_transform() * app.battle.world_to_screen(point)

func clear_cell(sim, kind: String) -> Vector2:
	var original: String = sim.battle_devices.selected_kind
	sim.battle_devices.selected_kind = kind
	for row in range(200, 560, 40):
		for column in range(250, 1150, 60):
			var point := Vector2(column, row)
			if sim.battle_devices.placement_error(sim, point).is_empty():
				sim.battle_devices.selected_kind = original
				return point
	sim.battle_devices.selected_kind = original
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
	sim.reset_stage("stage_01", squad, 51071)
	sim.start()
	sim.battle_devices.gold = 10000
	app.refresh()
	await process_frame
	var shop = app.hud.device_shop_ui
	app.hud.device_drag_hover_requested.connect(func(_point: Vector2): hover_events += 1)
	app.hud.device_drag_drop_requested.connect(func(_kind: String, _point: Vector2): drop_events += 1)
	check(not app.qa_storage_path.is_empty(), "save files use the isolated QA path")
	check(shop.visible and shop.buttons.size() == 10, "all ten seed cards are directly visible")
	check(not shop.drawer.visible and shop.drawer.get_child_count() == 0, "there is no hidden seed drawer to discover")
	check(shop.capacity_label.text == "0/25 机关", "capacity remains 25")
	check(shop.get_global_rect().end.y <= UI_LAYOUT.battle_playfield_rect.position.y, "the entire seed row stays above the existing playable viewport")
	var headline: Array[Control] = [app.hud.progression_label, app.hud.base_label, app.hud.wave_label, app.hud.count_label, app.hud.map_name_label, app.hud.pause_button]
	var header_rects: Array[Rect2] = []
	for item: Control in headline:
		var rectangle := item.get_global_rect()
		check(not rectangle.intersects(shop.get_global_rect()), item.name + " headline does not collide with seed cards")
		for previous: Rect2 in header_rects:
			check(not rectangle.intersects(previous), item.name + " headline does not collide with another statistic")
		header_rects.append(rectangle)
	var card_rects: Array[Rect2] = []
	for kind: String in shop.KINDS:
		var button: Button = shop.buttons[kind]
		var rectangle := button.get_global_rect()
		var name_label: Label = button.get_node("DeviceName")
		check(button.is_visible_in_tree() and not button.disabled, kind + " is a visible actionable card")
		check(shop.get_global_rect().encloses(rectangle), kind + " is fully contained in the seed row")
		check(not rectangle.intersects(shop.coin_panel.get_global_rect()), kind + " does not collide with the coin panel")
		check(shop.kind_at(rectangle.get_center()) == kind, kind + " real control hit-test returns the correct device")
		check(name_label.text == ITEMS[kind].name, kind + " displays the complete original name")
		var font := name_label.get_theme_font("font")
		check(font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_label.get_theme_font_size("font_size")).x <= name_label.size.x, kind + " full name fits without truncation")
		check(rectangle.encloses(shop.icons[kind].get_global_rect()) and shop.icons[kind].size.x >= 36, kind + " original plant icon is large and fully visible")
		check(not name_label.get_global_rect().intersects(shop.icons[kind].get_global_rect()), kind + " plant icon does not cover its name")
		check(not shop.price_labels[kind].get_global_rect().intersects(name_label.get_global_rect()), kind + " price has its own line")
		for previous: Rect2 in card_rects: check(not previous.intersects(rectangle), kind + " has a positive gap from neighbouring cards")
		card_rects.append(rectangle)
	var gold: int = sim.battle_devices.gold
	await click(shop.coin_panel.get_global_rect().get_center())
	check(sim.battle_devices.gold == gold and sim.battle_devices.selected_kind.is_empty() and not shop.drawer.visible, "coin panel is informational and never buys an invisible item")
	for kind: String in shop.KINDS:
		gold = sim.battle_devices.gold
		var count: int = sim.battle_devices.active_count()
		await click(shop.buttons[kind].get_global_rect().get_center())
		check(sim.battle_devices.selected_kind == kind, kind + " real card click selects the matching device")
		check(sim.battle_devices.gold == gold and sim.battle_devices.active_count() == count and drop_events == 0, kind + " stationary click never deploys or charges")
		var point := clear_cell(sim, kind)
		check(point.is_finite(), kind + " has a free cell in actual first-stage terrain")
		if not point.is_finite(): continue
		await click(floor_screen(point))
		check(sim.battle_devices.active_count() == count + 1 and sim.battle_devices.gold == gold - sim.battle_devices.price_of(kind), kind + " actual floor click buys exactly once")
		check(sim.battle_devices.selected_kind.is_empty(), kind + " purchase clears selection")
	check(sim.battle_devices.active_count() == 10 and shop.capacity_label.text == "10/25 机关", "all ten directly visible cards deployed successfully")
	for kind: String in shop.KINDS:
		gold = sim.battle_devices.gold
		var count: int = sim.battle_devices.active_count()
		var previous_drop := drop_events
		var point := clear_cell(sim, kind)
		check(point.is_finite(), kind + " drag test has a valid free cell")
		if not point.is_finite(): continue
		await mouse(shop.buttons[kind].get_global_rect().get_center(), true)
		check(sim.battle_devices.selected_kind == kind and shop.dragging_kind == kind, kind + " press begins the correct drag")
		await move_mouse(floor_screen(point))
		check(shop.drag_started and hover_events > 0 and sim.battle_devices.valid, kind + " dragged seed previews a valid actual terrain cell")
		await mouse(floor_screen(point), false)
		check(drop_events == previous_drop + 1, kind + " release emits a single drop")
		check(sim.battle_devices.active_count() == count + 1 and sim.battle_devices.gold == gold - sim.battle_devices.price_of(kind), kind + " real drag drop buys exactly once")
		check(shop.dragging_kind.is_empty() and sim.battle_devices.selected_kind.is_empty(), kind + " successful drop clears drag and selection")
	check(sim.battle_devices.active_count() == 20 and shop.capacity_label.text == "20/25 机关", "all ten seeds can be directly dragged as well as clicked")
	sim.run_state.buff_levels.device_soil_discount = 3
	app.refresh()
	await process_frame
	for kind: String in shop.KINDS:
		check(int(shop.price_labels[kind].text) == sim.battle_devices.price_of(kind), kind + " directly visible price follows the live card discount")
	gold = sim.battle_devices.gold
	await mouse(shop.buttons.pea.get_global_rect().get_center(), true)
	await move_mouse(Vector2(16, 150))
	await mouse(Vector2(16, 150), false)
	check(sim.battle_devices.active_count() == 20 and sim.battle_devices.gold == gold, "invalid terrain drop never spends gold")
	check(shop.dragging_kind.is_empty() and sim.battle_devices.selected_kind == "pea", "invalid drop clears capture but retains selection for retry")
	await key(KEY_ESCAPE)
	check(sim.battle_devices.selected_kind.is_empty() and sim.state == "running", "Esc cancels an invalid drop without pausing")
	await mouse(shop.buttons.sunflower.get_global_rect().get_center(), true)
	check(shop.dragging_kind == "sunflower", "stage-switch test begins a real sunflower drag")
	sim.reset_stage("stage_02", squad, 51072)
	sim.start()
	app.refresh()
	await process_frame
	check(shop.dragging_kind.is_empty() and shop.selected_kind.is_empty(), "switching stages clears stale drag state")
	gold = sim.battle_devices.gold
	await mouse(floor_screen(Vector2(500, 320)), false)
	check(sim.battle_devices.active_count() == 0 and sim.battle_devices.gold == gold, "release after stage switch cannot purchase into the next stage")
	sim.battle_devices.gold = 0
	app.refresh()
	await mouse(shop.buttons.melon.get_global_rect().get_center(), true)
	check(shop.dragging_kind.is_empty() and sim.battle_devices.selected_kind.is_empty(), "unaffordable watermelon cannot start a drag")
	await mouse(floor_screen(Vector2(500, 320)), false)
	check(sim.battle_devices.active_count() == 0 and sim.battle_devices.gold == 0, "unaffordable drag cannot sneak in a free plant")
	sim.battle_devices.gold = 10000
	while sim.battle_devices.active_count() < 25:
		var point := clear_cell(sim, "power")
		if not point.is_finite(): break
		sim.battle_devices.selected_kind = "power"
		sim.battle_devices.place(sim, point)
	app.refresh()
	await process_frame
	check(sim.battle_devices.active_count() == 25 and shop.capacity_label.text == "25/25 机关", "new header retains the full 25-device ceiling")
	gold = sim.battle_devices.gold
	await mouse(shop.buttons.sunflower.get_global_rect().get_center(), true)
	check(shop.dragging_kind.is_empty() and sim.battle_devices.selected_kind.is_empty(), "full capacity cannot start a drag")
	await mouse(floor_screen(Vector2(500, 320)), false)
	check(sim.battle_devices.gold == gold and sim.battle_devices.active_count() == 25, "full capacity never charges for a 26th device")
	sim.state = "paused"
	app.refresh()
	await process_frame
	for kind: String in shop.KINDS: check(shop.buttons[kind].disabled, kind + " purchase is disabled while paused")
	sim.reset_stage("stage_endless", squad, 51073)
	app.refresh()
	await process_frame
	check(not shop.visible and not shop.drawer.visible and shop.dragging_kind.is_empty(), "endless hides the unavailable shop without stale drag state")
	await finish()

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child: Node in node.get_children(): stop_audio(child)

func finish() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var output := FileAccess.open(out + "/ui-input.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures, "hover_events": hover_events, "drop_events": drop_events}, "\t"))
	output.close()
	print("TOPBAR PLANTS: %d checks, %d failures" % [checks, failures.size()])
	stop_audio(app)
	app.queue_free()
	app = null
	await process_frame
	await process_frame
	await create_timer(.12).timeout
	quit(0 if failures.is_empty() else 1)
