extends SceneTree

const HUD = preload("res://scripts/battle_hud.gd")
const POPUP = preload("res://scripts/achievement_popup.gd")
const CATALOG = preload("res://scripts/achievement_catalog.gd")
const DEVICES = preload("res://scripts/battle_devices.gd")
const LAYOUT = preload("res://data/ui_layout_profile.tres")
const KETTLE := "res://assets/story_comics/master_delivery_20261004/furina_kettle_20261005.png"
const KETTLE_TEXT := "还有一位提着烧水壶自称水神的少女（或许）"

class ShopSimulation extends RefCounted:
	var state := "running"
	var device_shop: Dictionary

class PopupInput extends Node:
	var popup
	func _input(event: InputEvent) -> void:
		if popup.handle_input(event): get_viewport().set_input_as_handled()

var hud
var popup
var sim := ShopSimulation.new()
var failures: Array[String] = []
var purchase_events: Array[String] = []
var dismissals := 0
var assertions := 0
var dimensions: Array[Dictionary] = []
var output_directory := "res://../qa/achievement_devices_20261005"

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	assertions += 1
	print("PASS " + label if condition else "FAIL " + label)
	if not condition: failures.append(label)

func click(point: Vector2) -> void:
	point = root.get_screen_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		Input.parse_input_event(motion.duplicate())
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func wheel(point: Vector2, steps: int) -> void:
	point = root.get_screen_transform() * point
	for index in steps:
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_WHEEL_DOWN
			event.pressed = pressed
			Input.parse_input_event(event)
			await process_frame

func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output_directory.path_join(name + ".png")) == OK, "capture " + name)

func refresh_shop() -> void:
	hud.refresh_device_shop(sim)
	await process_frame

func received_purchase(kind: String) -> void:
	purchase_events.append(kind)
	sim.device_shop.selected_kind = "" if sim.device_shop.selected_kind == kind else kind
	sim.device_shop.message = "部署已取消" if sim.device_shop.selected_kind.is_empty() else DEVICES.ITEMS[kind].name + " · 点击地格部署"
	sim.device_shop.valid = true
	hud.refresh_device_shop(sim)

func check_story() -> void:
	for filename in ["authored_story.json", "campaign_comics.json"]:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + filename))
		check(data is Dictionary, filename + " remains valid JSON")
		if not data is Dictionary: continue
		var hits: Array[Dictionary] = []
		_find_kettle(data, hits)
		check(hits.size() == 1, filename + " contains exactly one kettle caption")
		if hits.is_empty(): continue
		check(hits[0].image == KETTLE and hits[0].width == 1774 and hits[0].height == 887, filename + " binds the exact replacement at 2:1")
	var image := Image.new()
	var source_path := ProjectSettings.globalize_path(KETTLE)
	if FileAccess.file_exists(source_path):
		check(image.load(source_path) == OK, "exact source PNG is readable")
		check(image.get_width() == 1774 and image.get_height() == 887, "exact source PNG keeps its full 1774 x 887 pixels")
	else:
		var texture := load(KETTLE) as Texture2D
		check(texture != null and texture.get_width() == 1774 and texture.get_height() == 887, "exported kettle texture keeps its 2:1 ratio")

func _find_kettle(value: Variant, hits: Array[Dictionary]) -> void:
	if value is Dictionary:
		if str(value.get("text", "")) == KETTLE_TEXT: hits.append(value)
		for child: Variant in value.values(): _find_kettle(child, hits)
	elif value is Array:
		for child: Variant in value: _find_kettle(child, hits)

func _run_resolution(size: Vector2i) -> void:
	root.size = size
	await process_frame
	await process_frame
	var tag := "%dx%d" % [size.x, size.y]
	dimensions.append({"requested": [size.x, size.y], "actual": [root.size.x, root.size.y], "logical": [root.get_visible_rect().size.x, root.get_visible_rect().size.y]})
	check(root.size == size, tag + " actual viewport size")
	sim.device_shop = {"enabled": true, "gold": 1480, "used": 2, "limit": 6, "items": DEVICES.ITEMS.duplicate(true), "selected_kind": "", "message": "点击机关，再点击地格部署 · 右键 / Esc 取消", "valid": true}
	sim.state = "running"
	hud.support_panel.show()
	await refresh_shop()
	check(hud.device_shop_ui.visible and not hud.support_panel.visible, tag + " shop replaces support labels in the same header space")
	check(hud.device_shop_ui.gold_label.text == "币 1480" and hud.device_shop_ui.capacity_label.text == "2/6 机关", tag + " gold and device limit are current")
	var gold_label: Label = hud.device_shop_ui.gold_label
	check(gold_label.get_theme_font("font").get_string_size(gold_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, gold_label.get_theme_font_size("font_size")).x <= gold_label.size.x, tag + " complete gold value fits its label")
	var last_rect := Rect2()
	for kind: String in hud.device_shop_ui.KINDS:
		var slot: Button = hud.device_shop_ui.buttons[kind]
		var rect := slot.get_global_rect()
		check(rect.size.x >= LAYOUT.battle_device_slot_size.x and rect.size.y == LAYOUT.battle_device_slot_size.y, tag + " " + kind + " keeps a full click area")
		check(not rect.intersects(last_rect) and rect.end.x < hud.pause_button.get_global_rect().position.x, tag + " " + kind + " does not overlap adjacent slot or pause")
		last_rect = rect
		check(hud.device_kind_at(rect.get_center()) == kind, tag + " " + kind + " hit testing returns exact kind")
		var before := purchase_events.size()
		await click(rect.get_center())
		check(purchase_events.size() == before + 1 and purchase_events.back() == kind, tag + " real mouse emits one " + kind + " request")
		check(hud.device_shop_ui.selected_kind == kind, tag + " " + kind + " selection stays visible")
	await capture("device_shop_" + tag)
	sim.device_shop.gold = 0
	sim.device_shop.used = 6
	await refresh_shop()
	var toggle_before := purchase_events.size()
	await click(hud.device_shop_ui.buttons.pea.get_global_rect().get_center())
	check(purchase_events.size() == toggle_before + 1 and hud.device_shop_ui.selected_kind.is_empty(), tag + " selecting the active slot cancels even without money or capacity")
	sim.device_shop.gold = 1480
	sim.device_shop.used = 2
	sim.device_shop.items.power.price = 137
	await refresh_shop()
	check(hud.device_shop_ui.price_labels.power.text == "137", tag + " prices refresh from the gameplay catalogue")
	sim.device_shop.gold = 0
	sim.device_shop.selected_kind = ""
	await refresh_shop()
	var before := purchase_events.size()
	await click(hud.device_shop_ui.buttons.power.get_global_rect().get_center())
	await refresh_shop()
	check(purchase_events.size() == before and hud.device_shop_ui.feedback.visible and "金币不足" in hud.device_shop_ui.feedback.text, tag + " unaffordable request displays feedback without buying")
	sim.device_shop.gold = 999
	sim.device_shop.used = 6
	await refresh_shop()
	await click(hud.device_shop_ui.buttons.pea.get_global_rect().get_center())
	await refresh_shop()
	check(purchase_events.size() == before and "上限" in hud.device_shop_ui.feedback.text, tag + " full limit rejects purchase with readable feedback")
	hud.cancel_device_placement()
	sim.device_shop.selected_kind = ""
	await refresh_shop()
	check(hud.device_shop_ui.selected_kind.is_empty() and "取消" in hud.device_shop_ui.feedback.text, tag + " cancel clears selection and acknowledges the action")
	for battle_state in ["paused", "reward"]:
		sim.state = battle_state
		await refresh_shop()
		await click(hud.device_shop_ui.buttons.range.get_global_rect().get_center())
		check(purchase_events.size() == before and hud.device_shop_ui.buttons.range.disabled, tag + " " + battle_state + " blocks purchase input")
	sim.state = "running"
	sim.device_shop.enabled = false
	await refresh_shop()
	check(not hud.device_shop_ui.visible and not hud.device_shop_ui.feedback.visible and hud.device_kind_at(Vector2(850, 30)).is_empty(), tag + " disabled shop has no leftover controls or feedback")
	var ids: Array[String] = ["first_watch", "damage_king", "card_master", "perfect_guard", "last_crystal", "hundred_slayer"]
	popup.open(ids)
	await process_frame
	await process_frame
	check(popup.is_open() and popup.list.get_child_count() == ids.size(), tag + " comic achievement popup retains every earned item")
	var first_row: Control = popup.list.get_child(0)
	var achievement_icon: TextureRect = first_row.get_node_or_null("AchievementIcon")
	check(achievement_icon != null and achievement_icon.size.x >= 110 and achievement_icon.size.y >= 110, tag + " achievement badge remains large")
	check(popup.scroll.get_global_rect().end.y < popup.close_button.get_global_rect().position.y, tag + " scroll content and Continue are separated")
	check(popup.heading.get_global_rect().end.y < popup.scroll.get_global_rect().position.y, tag + " title is separated from earned cards")
	await capture("achievement_popup_" + tag)
	await wheel(popup.scroll.get_global_rect().get_center(), 6)
	check(popup.scroll.scroll_vertical > 0, tag + " real mouse wheel reaches lower achievement rows")
	await capture("achievement_scrolled_" + tag)
	var closed_before := dismissals
	await click(popup.close_button.get_global_rect().get_center())
	check(not popup.is_open() and dismissals == closed_before + 1, tag + " real Continue click closes once")
	popup.open(ids)
	await process_frame
	check(popup.scroll.scroll_vertical == 0 and popup.list.get_child_count() == ids.size(), tag + " reopen resets scroll without duplicating rows")
	await key(KEY_ESCAPE)
	check(not popup.is_open() and dismissals == closed_before + 2, tag + " real Escape closes once and returns to HUD")
	popup.open(ids)
	await process_frame
	await key(KEY_ENTER)
	check(not popup.is_open() and dismissals == closed_before + 3, tag + " real Enter continues without a duplicate dismissal")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):
			output_directory = argument.trim_prefix("--qa-output=").replace("\\", "/")
			if not output_directory.is_absolute_path() or output_directory.begins_with("res://") or output_directory.begins_with("user://"):
				push_error("--qa-output requires an absolute filesystem directory")
				quit(2)
				return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory)) != OK:
		push_error("Cannot create achievement/device QA output directory")
		quit(2)
		return
	create_timer(45.0).timeout.connect(func(): push_error("ACHIEVEMENT/DEVICE QA timeout"); quit(2))
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var backdrop := ColorRect.new()
	backdrop.color = Color("#201b26")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	hud = HUD.new()
	root.add_child(hud)
	await process_frame
	hud.overlay.hide()
	hud.reward_panel.hide()
	hud.map_name_label.text = "裂隙前哨"
	hud.base_label.text = "◆ 基地 12/12"
	hud.wave_label.text = "01/21 · 准备"
	hud.count_label.text = "击退 8 · 敌 12"
	hud.progression_label.text = "水晶 Lv.3 · EXP 102/212 · 02:31"
	hud.device_purchase_requested.connect(received_purchase)
	popup = POPUP.new()
	root.add_child(popup)
	popup.build(hud)
	popup.dismissed.connect(func(): dismissals += 1)
	var input := PopupInput.new()
	input.popup = popup
	root.add_child(input)
	check_story()
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]: await _run_resolution(size)
	var report := {"graphical": DisplayServer.get_name() != "headless", "input": "Input.parse_input_event mouse/wheel/key", "assertions": assertions, "failures": failures, "purchase_events": purchase_events, "dismissals": dismissals, "dimensions": dimensions}
	var output := FileAccess.open(output_directory.path_join("validation.json"), FileAccess.WRITE)
	if output == null:
		push_error("Cannot write achievement/device QA report")
		quit(2)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("ACHIEVEMENT AND DEVICES QA: %d assertions, %d failures" % [assertions, failures.size()])
	hud.ui_highlight.stop()
	hud.ui_confirm.stop()
	await create_timer(0.1).timeout
	input.popup = null
	input.queue_free()
	backdrop.queue_free()
	popup.queue_free()
	hud.queue_free()
	await process_frame
	popup = null
	hud = null
	sim = null
	await process_frame
	quit(0 if failures.is_empty() else 1)
