extends Control

signal purchase_requested(kind: String)
signal placement_cancel_requested
signal placement_drag_hover_requested(screen_pos: Vector2)
signal placement_drag_drop_requested(kind: String, screen_pos: Vector2)

const POSTER = preload("res://scripts/poster_surface.gd")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const ShopIcon = preload("res://scripts/device_shop_icon.gd")
const KINDS: Array[String] = ["power", "range", "barricade", "mine", "pea", "snowpea", "sunflower", "spikeweed", "melon", "cherry"]
const DRAG_DISTANCE := 8.0

var buttons: Dictionary = {}
var price_labels: Dictionary = {}
var icons: Dictionary = {}
var drawer: Panel
var coin_panel: Panel
var gold_label: Label
var capacity_label: Label
var feedback: Label
var state: Dictionary = {}
var signature := ""
var selected_kind := ""
var local_message := ""
var local_valid := true
var local_message_until_ms := 0
var hud
var dragging_kind := ""
var drag_origin := Vector2.ZERO
var drag_started := false

func build(owner_hud) -> void:
	hud = owner_hud
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = UI_LAYOUT.battle_device_shop_rect.position
	size = UI_LAYOUT.battle_device_shop_rect.size
	var coin_rect: Rect2 = UI_LAYOUT.battle_device_coin_rect
	coin_panel = Panel.new()
	coin_panel.name = "DeviceGold"
	coin_panel.position = coin_rect.position
	coin_panel.size = coin_rect.size
	coin_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	coin_panel.tooltip_text = "击杀怪物获取金币 · 每关同时部署 25 个机关"
	var coin_style := StyleBoxFlat.new()
	coin_style.bg_color = POSTER.RED
	coin_style.border_color = POSTER.INK
	coin_style.set_border_width_all(2)
	coin_panel.add_theme_stylebox_override("panel", coin_style)
	add_child(coin_panel)
	gold_label = _seed_label(coin_panel, Rect2(8, 1, coin_rect.size.x - 16, 23), "币 0", 17, POSTER.PAPER)
	gold_label.clip_text = true
	gold_label.add_theme_font_override("font", POSTER.TYPE)
	capacity_label = _seed_label(coin_panel, Rect2(8, 24, coin_rect.size.x - 16, 15), "0/25 机关", 11, POSTER.PAPER)
	for index in KINDS.size():
		var kind := KINDS[index]
		var at: Vector2 = UI_LAYOUT.battle_device_slot_origin + Vector2((UI_LAYOUT.battle_device_slot_size.x + UI_LAYOUT.battle_device_slot_gap) * index, 0)
		var button: Button = hud.button(self, Rect2(at, UI_LAYOUT.battle_device_slot_size), "", false)
		button.name = "Device_" + kind
		# Selection begins on press so the same slot supports click placement and drag placement.
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.pressed.connect(_request.bind(kind))
		var icon := ShopIcon.new()
		icon.kind = kind
		icon.position = Vector2(4, 3)
		icon.size = Vector2(36, 36)
		button.add_child(icon)
		icons[kind] = icon
		var name_label := _seed_label(button, Rect2(41, 2, UI_LAYOUT.battle_device_slot_size.x - 45, 19), "", 12, POSTER.INK)
		name_label.name = "DeviceName"
		name_label.clip_text = true
		price_labels[kind] = _seed_label(button, Rect2(43, 23, UI_LAYOUT.battle_device_slot_size.x - 47, 16), "", 12, POSTER.RED)
		buttons[kind] = button
	# Kept hidden for the existing main-menu cancellation contract; every seed is now always visible.
	drawer = Panel.new()
	drawer.name = "DeviceSeedDrawer"
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drawer)
	drawer.hide()
	feedback = hud.label(get_parent(), UI_LAYOUT.battle_device_feedback_rect.position, UI_LAYOUT.battle_device_feedback_rect.size, "", 12, POSTER.PAPER)
	feedback.add_theme_color_override("font_outline_color", POSTER.INK)
	feedback.add_theme_constant_override("outline_size", 5)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.hide()
	hide()

func _seed_label(parent: Node, rect: Rect2, text: String, font_size: int, color: Color) -> Label:
	var item: Label = hud.label(parent, rect.position, rect.size, text, font_size, color)
	var variation := FontVariation.new()
	variation.base_font = POSTER.TYPE
	# The display font has generous line metrics; remove whitespace without scaling the glyphs.
	var trim := maxi(0, ceili(POSTER.TYPE.get_height(font_size) - rect.size.y))
	variation.spacing_top = -ceili(trim / 2.0)
	variation.spacing_bottom = -floori(trim / 2.0)
	item.add_theme_font_override("font", variation)
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.reset_size()
	item.size = rect.size
	return item

func refresh(snapshot: Dictionary, battle_state: String) -> void:
	var next_signature := str([snapshot, battle_state, selected_kind, local_message, local_valid, Time.get_ticks_msec() < local_message_until_ms])
	if signature == next_signature: return
	signature = next_signature
	state = snapshot
	visible = bool(state.get("enabled", false))
	if not visible:
		feedback.hide()
		drawer.hide()
		_clear_drag()
		return
	var gold := int(state.get("gold", 0))
	var used := int(state.get("used", 0))
	var limit := int(state.get("limit", 0))
	gold_label.text = "币 %d" % gold if gold < 10000 else "币 %.1fk" % (float(gold) / 1000.0)
	gold_label.tooltip_text = "金币 %d" % gold
	var gold_font := gold_label.get_theme_font("font")
	var gold_size := 17
	while gold_size > 10 and gold_font.get_string_size(gold_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, gold_size).x > gold_label.size.x - 2:
		gold_size -= 1
	gold_label.add_theme_font_size_override("font_size", gold_size)
	capacity_label.text = "%d/%d 机关" % [used, limit]
	selected_kind = str(state.get("selected_kind", selected_kind))
	if not dragging_kind.is_empty() and dragging_kind != selected_kind: _clear_drag()
	var items: Dictionary = state.get("items", {})
	for kind: String in KINDS:
		var definition: Dictionary = items.get(kind, {})
		var price := int(definition.get("price", 0))
		var affordable := gold >= price and used < limit
		_refresh_slot(buttons[kind], price_labels[kind], icons[kind], kind, definition, battle_state, affordable)
	if battle_state not in ["ready", "running", "between"]: _clear_drag()
	if Time.get_ticks_msec() < local_message_until_ms:
		feedback.text = local_message
		feedback.add_theme_color_override("font_color", POSTER.PAPER if local_valid else Color("#ff7d8e"))
	else:
		feedback.text = str(state.get("message", ""))
		feedback.add_theme_color_override("font_color", POSTER.PAPER if bool(state.get("valid", true)) else Color("#ff7d8e"))
	feedback.visible = not feedback.text.is_empty()

func _refresh_slot(item: Button, price: Label, icon, kind: String, definition: Dictionary, battle_state: String, affordable: bool) -> void:
	item.disabled = definition.is_empty() or battle_state not in ["ready", "running", "between"]
	item.get_node("DeviceName").text = str(definition.get("name", ""))
	item.tooltip_text = "%s · %d 金币\n%s\n点击后点地格，或直接拖到地格 · Esc / 右键取消" % [str(definition.get("name", kind)), int(definition.get("price", 0)), str(definition.get("description", ""))]
	price.text = "%d" % int(definition.get("price", 0))
	price.add_theme_color_override("font_color", POSTER.RED.darkened(.2) if affordable else Color("#a05265"))
	_style_slot(item, selected_kind == kind, affordable)
	icon.color = Color.WHITE if affordable else Color("#a9a1a2")
	icon.queue_redraw()

func close_drawer() -> void:
	drawer.hide()

func _style_slot(button: Button, selected: bool, affordable: bool) -> void:
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = POSTER.YELLOW if selected or style_name in ["hover", "focus"] else POSTER.PAPER if affordable else Color("#cac1bd")
		box.border_color = POSTER.RED if selected else POSTER.INK
		box.set_border_width_all(2)
		box.border_width_bottom = 4 if selected else 2
		button.add_theme_stylebox_override(style_name, box)

func _input(event: InputEvent) -> void:
	if dragging_kind.is_empty(): return
	if not is_visible_in_tree():
		_clear_drag()
		return
	if event is InputEventMouseMotion:
		if event.position.distance_to(drag_origin) >= DRAG_DISTANCE: drag_started = true
		if drag_started: placement_drag_hover_requested.emit(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var kind := dragging_kind
		var dropped := drag_started and not get_global_rect().has_point(event.position)
		_clear_drag()
		if dropped:
			placement_drag_drop_requested.emit(kind, event.position)

func _clear_drag() -> void:
	dragging_kind = ""
	drag_started = false

func _request(kind: String) -> void:
	var definition: Dictionary = state.get("items", {}).get(kind, {})
	if definition.is_empty(): return
	# The gameplay selection contract allows cancelling an active slot before affordability checks.
	if str(state.get("selected_kind", "")) == kind:
		signature = ""
		local_message_until_ms = 0
		purchase_requested.emit(kind)
		return
	if int(state.get("used", 0)) >= int(state.get("limit", 0)):
		set_placement(selected_kind, false, "机关上限已满，先移除或等待机关消耗。")
		return
	if int(state.get("gold", 0)) < int(definition.get("price", 0)):
		set_placement(selected_kind, false, "金币不足，还差 %d。" % (int(definition.get("price", 0)) - int(state.get("gold", 0))))
		return
	selected_kind = kind
	signature = ""
	local_message_until_ms = 0
	drawer.hide()
	purchase_requested.emit(kind)
	# Main refreshes aim state before selecting a seed, so capture only after that synchronous refresh.
	if str(state.get("selected_kind", "")) == kind:
		dragging_kind = kind
		drag_origin = get_viewport().get_mouse_position()
		drag_started = false

func set_placement(kind: String, valid: bool = true, message: String = "") -> void:
	selected_kind = kind
	signature = ""
	local_message = message
	local_valid = valid
	local_message_until_ms = Time.get_ticks_msec() + 2100 if not message.is_empty() else 0

func cancel_placement(notify: bool = false) -> void:
	close_drawer()
	_clear_drag()
	selected_kind = ""
	signature = ""
	local_message = "放置已取消。"
	local_valid = true
	local_message_until_ms = Time.get_ticks_msec() + 1600
	if notify: placement_cancel_requested.emit()

func kind_at(point: Vector2) -> String:
	if not visible: return ""
	for kind: String in KINDS:
		if buttons[kind].is_visible_in_tree() and not buttons[kind].disabled and buttons[kind].get_global_rect().has_point(point): return kind
	return ""
