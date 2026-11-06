extends SceneTree
const MOTION = preload("res://scripts/poster_motion.gd")
const POSTER = preload("res://scripts/poster_surface.gd")
const LAYOUT = preload("res://data/ui_layout_profile.tres")
const BACKDROP = preload("res://scripts/reward_poster_backdrop.gd")
var app
var panel
var archive
var checks := 0
var failures: Array[String] = []
var output_dir := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): output_dir = argument.trim_prefix("--qa-output=")
	_run.call_deferred()

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)
		print("FAIL " + note)

func inside(rect: Rect2, polygon: PackedVector2Array, margin := 0.0) -> bool:
	for point in [rect.position - Vector2.ONE * margin, Vector2(rect.end.x + margin, rect.position.y - margin), rect.end + Vector2.ONE * margin, Vector2(rect.position.x - margin, rect.end.y + margin)]:
		if not Geometry2D.is_point_in_polygon(point, polygon): return false
	return true

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func click(button: Control) -> void:
	var point: Vector2 = root.get_screen_transform() * button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func get_card(id: String) -> Dictionary:
	for card: Dictionary in app.sim.database.cards:
		if str(card.id) == id: return card.duplicate(true)
	return {}

func offer(ids: Array[String]) -> void:
	app.sim.rewards.offered.clear()
	for id in ids: app.sim.rewards.offered.append(get_card(id))
	app.sim.rewards.offer_revision += 1
	app.sim.rewards.rerolls_left = 2
	app.sim.run_state.pending_level_ups = 1
	app.sim.state = "reward"
	app.hud.signature = ""
	app.refresh()
	app.hud.overlay.hide()

func archive_at_layout() -> bool:
	return archive.archive_frame.position.is_equal_approx(LAYOUT.stage_compendium_frame_rect.position) and archive.archive_frame.scale.is_equal_approx(Vector2.ONE) and archive.scroll.position.is_equal_approx(LAYOUT.stage_compendium_scroll_rect.position) and archive.scroll.scale.is_equal_approx(Vector2.ONE)

func _run() -> void:
	create_timer(40).timeout.connect(func(): push_error("Reward/gallery QA timeout"); quit(2))
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
	var squad: Array[String] = ["traveler", "hero_03", "hero_13"]
	app.sim.reset_stage("stage_01", squad, 202610052)
	app.sim.start()
	# The rebalanced catalogue gates specialised cards by crystal level; the UI
	# fixture is a real late-enough offer, not an ineligible level-one hand.
	app.sim.run_state.crystal_level = 20
	panel = app.hud.reward_panel
	archive = app.compendium_panel
	offer(["global_attack_1", "device_rooted", "device_photosynthesis"])
	await create_timer(0.65).timeout
	var backdrop := BACKDROP.new()
	var header_polygon: PackedVector2Array = backdrop.header_polygon()
	for field in ["battle_reward_brand_rect", "battle_reward_heading_rect", "battle_reward_status_rect", "battle_reward_reroll_rect", "battle_reward_synergy_button_rect"]:
		check(inside(LAYOUT.get(field), header_polygon, 1.0), "header contains %s with safe slanted edge" % field)
	for screen_size in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2424,1298)]:
		root.size = screen_size
		await process_frame
		var transform := root.get_screen_transform()
		var device_header := PackedVector2Array()
		for point in header_polygon: device_header.append(transform * point)
		for button in [panel.reroll_button, panel.synergy_button]:
			for point in [button.get_global_rect().position, button.get_global_rect().end]:
				check(Geometry2D.is_point_in_polygon(transform * point, device_header), "%s header button remains inside transformed banner at %s" % [button.text, screen_size])
		for index in 3:
			var art: Control = panel.card_art[index]
			check(inside(LAYOUT.reward_action_rect.grow(1), art.body_polygon()), "action fill keeps genuine paper bottom margin at %s / %d" % [screen_size, index])
			check(inside(LAYOUT.reward_title_rect, art.title_polygon()), "title text fits the angled solid strip at %s / %d" % [screen_size, index])
			check(inside(LAYOUT.battle_reward_rarity_badge_rect.grow(1), art.body_polygon()), "rarity badge stays on the paper at %s / %d" % [screen_size, index])
	root.size = Vector2i(1280,720)
	await process_frame
	var rarity_colors := {}
	for rarity in ["common", "rare", "epic", "legendary", "mythic"]:
		var sample := get_card("global_attack_1")
		sample.rarity = rarity
		panel._apply_offer(0, sample, app.sim)
		var normalized: String = panel._normalize_rarity(rarity)
		rarity_colors[str(panel.card_art[0].accent)] = true
		check(panel.rarity_badges[0].text.begins_with(panel._rarity_name(normalized)) and panel.rarity_badges[0].size.x >= 100, "large printed badge identifies " + rarity)
		check(panel.card_art[0].accent == panel._rarity_color(normalized) and panel.rarity_badges[0].get_theme_color("font_color") == POSTER.INK, "rarity stripe and contrasting badge identify " + rarity)
	check(rarity_colors.size() == 5, "all five qualities have distinct independent inks")
	var names_checked := 0
	for card: Dictionary in app.sim.database.cards:
		panel._apply_offer(0, card, app.sim)
		var title: Label = panel.titles[0]
		var title_width := title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
		check(title.text == str(card.name) and title_width <= title.size.x + 0.01, "unchanged name fits " + str(card.id))
		check(not panel.tags[0].text.contains("∞") and panel.tags[0].text.contains("/ %d" % int(card.get("max_stacks",1))), "finite level cap visible " + str(card.id))
		check(panel.icons[0].texture != null and is_equal_approx(panel.icons[0].scale.x, panel.icons[0].scale.y), "unchanged icon fits " + str(card.id))
		check(panel.buttons[0].tooltip_text.contains(str(card.description)) and panel.descriptions[0].get_line_count() <= 3, "full original explanation available " + str(card.id))
		names_checked += 1
	check(names_checked >= 160, "all current cards checked rather than only showcase fixtures")
	offer(["global_attack_1", "device_rooted", "device_photosynthesis"])
	await create_timer(0.65).timeout
	await click(panel.reroll_button)
	check(app.sim.rewards.rerolls_left == 1, "real mouse still activates the inset refresh button")
	# Reroll correctly produces a random target type; use a global fixture for
	# the independent number-shortcut assertion rather than assuming its result.
	offer(["device_botanist", "device_rooted", "device_photosynthesis"])
	await key(KEY_2)
	check(app.sim.state == "running" and not panel.visible, "real number shortcut still takes the offered card")
	app.mode_select_panel.open()
	await create_timer(0.65).timeout
	await click(app.mode_select_panel.buttons.archive)
	check(archive.is_open() and MOTION.active(archive.root) != null, "real menu input starts archive entrance")
	var serial: int = archive.opening_serial
	await create_timer(0.65).timeout
	check(archive_at_layout() and archive.opening_serial == serial, "archive settles once at profile layout")
	var first_row: Button = archive.list.get_child(0)
	check(MOTION.active(first_row) != null and first_row.position.y == 0, "entry content animates without moving container hit region")
	await click(first_row)
	check(archive.detail_overlay.visible and MOTION.active(archive.detail_overlay) != null, "real row input starts portrait detail entrance")
	await create_timer(0.55).timeout
	check(archive.detail_frame.position.is_equal_approx(LAYOUT.stage_compendium_detail_rect.position) and archive.detail_frame.scale.is_equal_approx(Vector2.ONE), "detail settles at its own stable profile rectangle")
	await key(KEY_ESCAPE)
	check(archive.is_open() and not archive.detail_overlay.visible and MOTION.active(archive.detail_overlay) == null, "first Escape cancels detail motion and restores list")
	for card: Dictionary in app.sim.database.cards: app.compendium.discovered_cards[str(card.id)] = true
	await click(archive.tabs[1])
	await process_frame
	check(archive.active_tab == "cards" and archive.list.get_child_count() == names_checked and MOTION.active(archive.list.get_child(0)) != null, "real card tab starts fresh entry motion")
	await create_timer(0.65).timeout
	await click(archive.list.get_child(0))
	var details: RichTextLabel = archive.detail_frame.get_children().filter(func(node): return node is RichTextLabel)[0]
	check(details.text.contains("等级上限：Lv.") and details.text.contains("首级收益"), "card dossier explains finite cap and later level preview")
	await click(archive.detail_return)
	check(not archive.detail_overlay.visible, "real detail return remains usable during animation")
	for iteration in 12:
		archive.close()
		app.open_menu_archive()
		await process_frame
		archive.close()
		check(archive_at_layout() and MOTION.active(archive.root) == null and MOTION.active(archive.detail_overlay) == null, "rapid archive close/open cancels every pose without drift %d" % iteration)
	app.hud.reduced = true
	app.open_menu_archive()
	check(archive_at_layout(), "low effects keeps gallery geometry fixed during short fade")
	await create_timer(0.18).timeout
	check(is_equal_approx(archive.archive_frame.modulate.a,1.0) and archive_at_layout(), "low effects finishes gallery entrance in 140ms")
	archive.show_detail("旅行者", "短文字", Color.WHITE, true, "已解锁", "")
	check(archive.detail_frame.position == LAYOUT.stage_compendium_detail_rect.position, "low effects keeps portrait detail fixed")
	await create_timer(0.18).timeout
	check(is_equal_approx(archive.detail_frame.modulate.a,1.0), "low effects finishes detail fade in 140ms")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	check(not archive.is_open() and app.mode_select_panel.is_open(), "second Escape returns to the underlying menu")
	for player: Node in app.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	backdrop.free()
	var report := {"checks":checks,"failures":failures,"passed":failures.is_empty(),"cards":names_checked,"resolutions":["1280x720","1920x1080","2424x1298"],"input":"real Input.parse_input_event mouse and key"}
	if not output_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(output_dir)
		var file := FileAccess.open(output_dir.path_join("reward-gallery.json"),FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report,"\t"))
	print("REWARD/GALLERY BALANCE QA: %d checks / %d failures" % [checks, failures.size()])
	app.queue_free()
	app = null
	panel = null
	archive = null
	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	quit(0 if failures.is_empty() else 1)
