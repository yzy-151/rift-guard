extends CanvasLayer

signal closed
const Session = preload("res://scripts/workshop_session.gd")
const View = preload("res://scripts/battle_view.gd")
const Sheet = preload("res://scripts/sheet_effects.gd")
const Audio = preload("res://scripts/combat_audio_director.gd")
const Icons = preload("res://scripts/content/generated_icon_catalog.gd")
const Layouts = preload("res://scripts/workshop_layouts.gd")
const Toolbar = preload("res://scripts/workshop_toolbar.gd")
const RED := Color("#ed5d6f")
const WHITE := Color("#f6eeea")
const MUTED := Color("#b49ba2")

var session = Session.new()
var battle
var fx
var audio
var hud
var ui: Control
var drawer: Panel
var inspector: Label
var notice: Label
var clock_label: Label
var map_picker: OptionButton
var hero_picker: OptionButton
var enemy_picker: OptionButton
var card_picker: OptionButton
var card_search: LineEdit
var card_description: Label
var pause_button: Button
var toolbar
var collapse_button: Button
var buttons: Dictionary = {}
var placement_kind := ""
var placement_id := ""
var aiming := ""
var camera_center := Vector2(1280, 720)
var last_events: Array[Dictionary] = []
var event_history: Array[Dictionary] = []
var reduced_effects := false
var closing := false
var marker: Node2D
var pan_keys: Dictionary = {}

class SelectionMarker extends Node2D:
	var owner_panel
	func _draw() -> void:
		if owner_panel == null: return
		var unit: Dictionary = owner_panel.session.selected()
		if unit.is_empty(): return
		var point: Vector2 = owner_panel.battle.world_to_screen(unit.pos) + owner_panel.battle.position
		var color := Color("#ff91a0") if owner_panel.session.selected_kind == "enemy" else Color("#fff1cc")
		draw_arc(point, 27.0, 0.0, TAU, 48, color, 2.0, true)
		draw_line(point + Vector2(-34, 0), point + Vector2(-25, 0), color, 2.0)
		draw_line(point + Vector2(25, 0), point + Vector2(34, 0), color, 2.0)

func build(owner_hud, reduced: bool = false) -> void:
	hud = owner_hud
	layer = 110
	reduced_effects = reduced
	battle = View.new()
	battle.sim = session.sim
	battle.selected_id = -1
	add_child(battle)
	fx = Sheet.new()
	fx.battle_view = battle
	battle.sheet_effects = fx
	battle.add_child(fx)
	audio = Audio.new()
	add_child(audio)
	audio.set_process(false)
	marker = SelectionMarker.new()
	marker.owner_panel = self
	add_child(marker)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = owner_hud.get_child(0).theme
	add_child(ui)
	toolbar = Toolbar.new()
	toolbar.position = Vector2(16, 10)
	toolbar.size = Vector2(1248, 48)
	ui.add_child(toolbar)
	var title := _label(toolbar, Rect2(20, 2, 144, 29), "示范工坊", 22, WHITE)
	title.add_theme_font_override("font", Toolbar.DISPLAY_FONT)
	_label(toolbar, Rect2(184, 6, 72, 19), "独立战场", 11, MUTED)
	clock_label = _label(toolbar, Rect2(20, 28, 241, 17), "", 11, MUTED)
	pause_button = _rail_button(Rect2(288, 7, 110, 34), "暂停", "pause", toggle_pause, "transport", "pause", "空格")
	pause_button.tooltip_text = "暂停 / 继续独立工坊时间 · 空格"
	_rail_button(Rect2(404, 7, 78, 34), "逐帧", "step", step_once, "secondary", "step", ".").tooltip_text = "暂停并推进一个 1/60 秒战斗帧 · ."
	var speed_picker := OptionButton.new()
	speed_picker.position = Vector2(488, 7)
	speed_picker.size = Vector2(88, 34)
	for speed in [0.25, 0.5, 1.0, 2.0]: speed_picker.add_item("× %s" % speed); speed_picker.set_item_metadata(speed_picker.item_count - 1, speed)
	speed_picker.select(2)
	speed_picker.tooltip_text = "工坊时间倍率 · 0.25 / 0.5 / 1 / 2 倍"
	speed_picker.item_selected.connect(func(index: int): session.speed = float(speed_picker.get_item_metadata(index)))
	toolbar.style_speed(speed_picker)
	toolbar.add_child(speed_picker)
	buttons["speed"] = speed_picker
	_rail_button(Rect2(610, 7, 88, 34), "恢复", "recover", func(): session.recover(); refresh()).tooltip_text = "恢复在场单位生命、护盾、能量与冷却"
	_rail_button(Rect2(704, 7, 112, 34), "清除敌人", "clear_enemies", func(): session.clear_units(true); _reset_visuals()).tooltip_text = "保留角色，移除全部敌人和战斗残留"
	_rail_button(Rect2(822, 7, 112, 34), "清空战场", "clear", func(): session.clear_units(); _reset_visuals()).tooltip_text = "移除全部在场角色、敌人和战斗残留"
	_rail_button(Rect2(940, 7, 112, 34), "重置工坊", "reset", func(): _change_map(map_picker.selected)).tooltip_text = "重新加载当前地图，清空摆放与构筑"
	_rail_button(Rect2(1102, 7, 134, 34), "返回设置", "exit", close, "exit", "exit", "Esc")
	drawer = _panel(ui, Rect2(16, 68, 336, 538))
	_label(drawer, Rect2(16, 8, 272, 26), "放置与构筑", 19, WHITE)
	collapse_button = _button(ui, Rect2(358, 68, 106, 32), "收起 [Tab]", "drawer", toggle_drawer)
	_label(drawer, Rect2(16, 42, 300, 18), "地图 · 切换将重置摆放", 12, MUTED)
	map_picker = _picker(drawer, Rect2(16, 64, 304, 32))
	for id: String in session.sim.database.stages:
		if id == "stage_endless": continue
		var data: Dictionary = session.sim.database.stages[id]
		map_picker.add_item(str(data.get("name", id)))
		map_picker.set_item_metadata(map_picker.item_count - 1, {"stage":id, "layout":"blood_gate"})
	for layout: Dictionary in Layouts.OPTIONS:
		map_picker.add_item("无尽 · " + str(layout.name))
		map_picker.set_item_metadata(map_picker.item_count - 1, {"stage":"stage_endless", "layout":layout.id})
	map_picker.item_selected.connect(_change_map)
	_label(drawer, Rect2(16, 105, 300, 18), "角色 · 点击战场放置 / 已在场则重新摆放", 12, MUTED)
	hero_picker = _picker(drawer, Rect2(16, 127, 215, 34))
	for id: String in session.sim.database.characters:
		var data: Dictionary = session.sim.database.characters[id]
		hero_picker.add_item(str(data.name) + ("" if bool(data.get("content_ready", false)) else " · 未完成"))
		hero_picker.set_item_metadata(hero_picker.item_count - 1, id)
		var portrait: String = str(session.sim.database.assets.get(str(data.get("asset_key", "")), {}).get("portrait", ""))
		if ResourceLoader.exists(portrait): hero_picker.set_item_icon(hero_picker.item_count - 1, load(portrait))
	_button(drawer, Rect2(237, 127, 83, 34), "放置角色", "hero", func(): _begin_place("hero", str(hero_picker.get_selected_metadata())))
	_label(drawer, Rect2(16, 170, 300, 18), "怪物 / Boss · 完整战斗目录", 12, MUTED)
	enemy_picker = _picker(drawer, Rect2(16, 192, 215, 34))
	for id: String in Session.Catalog.ENEMIES:
		enemy_picker.add_item(str(Session.Catalog.ENEMIES[id].name))
		enemy_picker.set_item_metadata(enemy_picker.item_count - 1, id)
	_button(drawer, Rect2(237, 192, 83, 34), "放置敌人", "enemy", func(): _begin_place("enemy", str(enemy_picker.get_selected_metadata())))
	_toggle(drawer, Rect2(16, 238, 147, 32), "自动普攻", "auto", session.auto_attack, func(value: bool): session.auto_attack = value)
	_toggle(drawer, Rect2(173, 238, 147, 32), "敌人行动", "enemy_action", session.enemy_action, func(value: bool): session.enemy_action = value)
	_toggle(drawer, Rect2(16, 276, 147, 32), "角色无敌", "invulnerable", session.invulnerable, func(value: bool): session.invulnerable = value)
	_toggle(drawer, Rect2(173, 276, 147, 32), "无限能量 / 冷却", "energy", session.infinite_energy, func(value: bool): session.infinite_energy = value)
	_label(drawer, Rect2(16, 320, 300, 18), "卡牌 · 原名原图 · 加给当前选中角色", 12, MUTED)
	card_search = LineEdit.new()
	card_search.position = Vector2(16, 344)
	card_search.size = Vector2(304, 30)
	card_search.placeholder_text = "搜索卡牌名称"
	card_search.text_changed.connect(_filter_cards)
	drawer.add_child(card_search)
	card_picker = _picker(drawer, Rect2(16, 380, 304, 34))
	card_picker.item_selected.connect(func(_index: int): _show_card())
	card_description = _label(drawer, Rect2(16, 422, 304, 64), "", 12, MUTED)
	card_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(drawer, Rect2(16, 493, 147, 32), "添加所选卡牌", "card", _apply_card)
	_button(drawer, Rect2(173, 493, 147, 32), "重置全部构筑", "reset_build", func(): session.reset_builds(); _reset_visuals())
	_filter_cards("")
	var bottom := _panel(ui, Rect2(16, 616, 1248, 92))
	inspector = _label(bottom, Rect2(16, 7, 766, 49), "", 15, WHITE)
	_button(bottom, Rect2(794, 9, 150, 32), "Q 技能", "skill", func(): _begin_aim(false))
	_button(bottom, Rect2(950, 9, 152, 32), "E 终结技", "ultimate", func(): _begin_aim(true))
	_button(bottom, Rect2(1108, 9, 128, 32), "移除 [Delete]", "remove", func(): session.remove_selected(); refresh())
	notice = _label(bottom, Rect2(16, 61, 1220, 22), "", 12, RED)
	refresh()

func _panel(parent: Node, rect: Rect2) -> Panel:
	return hud.panel(parent, rect, Color("#180e16"), Color("#75414c"))

func _rail_button(rect: Rect2, value: String, id: String, action: Callable, role: String = "tool", symbol: String = "", hint: String = "") -> Button:
	var button: Button = toolbar.action(rect, value, role, symbol, hint)
	button.pressed.connect(action)
	buttons[id] = button
	return button

func _label(parent: Node, rect: Rect2, value: String, size: int, color: Color) -> Label:
	return hud.label(parent, rect.position, rect.size, value, size, color)

func _button(parent: Node, rect: Rect2, value: String, id: String, action: Callable) -> Button:
	var button: Button = hud.button(parent, rect, value, false)
	button.set_meta("dialogue_sound", true)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_constant_override("icon_max_width", 20)
	button.pressed.connect(action)
	button.focus_mode = Control.FOCUS_NONE
	buttons[id] = button
	return button

func _toggle(parent: Node, rect: Rect2, title: String, id: String, initial: bool, action: Callable) -> void:
	var button := _button(parent, rect, title, id, func(): pass)
	button.toggle_mode = true
	button.button_pressed = initial
	button.text = title + (" ✓" if initial else " —")
	button.toggled.connect(func(value: bool): action.call(value); button.text = title + (" ✓" if value else " —"); session._sync_flags())

func _picker(parent: Node, rect: Rect2) -> OptionButton:
	var picker := OptionButton.new()
	picker.position = rect.position
	picker.size = rect.size
	picker.fit_to_longest_item = false
	picker.add_theme_font_size_override("font_size", 13)
	picker.add_theme_constant_override("icon_max_width", 24)
	picker.get_popup().max_size = Vector2i(480, 420)
	parent.add_child(picker)
	return picker

func _filter_cards(query: String) -> void:
	card_picker.clear()
	for card: Dictionary in session.sim.database.cards:
		if not query.is_empty() and not query.to_lower() in str(card.name).to_lower(): continue
		card_picker.add_item(str(card.name))
		var index := card_picker.item_count - 1
		card_picker.set_item_metadata(index, card)
		card_picker.set_item_icon(index, Icons.card_texture(card))
	if card_picker.item_count > 0: card_picker.select(0)
	_show_card()

func _show_card() -> void:
	if card_picker.selected < 0: card_description.text = "没有匹配的卡牌。"; return
	var card: Dictionary = card_picker.get_selected_metadata()
	card_description.text = str(card.get("description", ""))
	card_description.tooltip_text = card_description.text

func _apply_card() -> void:
	if card_picker.selected >= 0: session.apply_card(card_picker.get_selected_metadata())
	refresh()

func _change_map(index: int) -> void:
	var row: Dictionary = map_picker.get_item_metadata(index)
	session.change_map(str(row.stage), str(row.layout))
	camera_center = Session.Sim.ENDLESS_ARENA.get_center()
	placement_kind = ""
	aiming = ""
	_reset_visuals()

func _reset_visuals() -> void:
	battle.sim = session.sim
	battle.selected_id = -1
	battle.skill_targeting = false
	battle.reset_transients()
	for effect: Dictionary in battle.effects: battle.effect_pool.release(effect)
	battle.effects.clear()
	battle.enemy_death_visuals.clear()
	battle.hero_attack_visuals.clear()
	battle.hero_down_visuals.clear()
	battle.shot_flashes.clear()
	battle.projectile_trails.clear()
	battle.unit_visual_actors.clear()
	battle.shake_trauma = 0.0
	battle.base_flash = 0.0
	battle.position = Vector2.ZERO
	battle.camera_center = camera_center
	fx.active.clear()
	audio.reset()
	last_events.clear()
	event_history.clear()
	refresh()

func _begin_place(kind: String, id: String) -> void:
	placement_kind = kind
	placement_id = id
	aiming = ""
	battle.skill_targeting = false
	session.message = "点击合法战场位置放置；可连续放置敌人。右键取消。Tab 收起工具。"
	refresh()

func _begin_aim(ultimate: bool) -> void:
	if session.selected_kind != "hero" or session.selected().is_empty():
		session.message = "先点选战场中的角色。"; refresh(); return
	aiming = "ultimate" if ultimate else "skill"
	placement_kind = ""
	battle.skill_targeting = true
	battle.skill_preview_ultimate = ultimate
	session.message = "%s · 点击战场决定落点 / 方向，右键取消。" % (session.sim.hero_ultimate_name(session.selected_id) if ultimate else session.sim.hero_skill_name(session.selected_id))
	refresh()

func toggle_drawer() -> void:
	card_search.release_focus()
	drawer.visible = not drawer.visible
	collapse_button.position.x = 358 if drawer.visible else 16
	collapse_button.text = "收起 [Tab]" if drawer.visible else "工具 [Tab]"

func toggle_pause() -> void:
	session.paused = not session.paused
	refresh()

func step_once() -> void:
	session.paused = true
	_advance(1.0 / 60.0)

func _physics_process(dt: float) -> void:
	if closing: return
	if session.sim.endless_mode and not card_search.has_focus():
		var direction := Vector2(float(pan_keys.get(KEY_D, false)) - float(pan_keys.get(KEY_A, false)), float(pan_keys.get(KEY_S, false)) - float(pan_keys.get(KEY_W, false)))
		camera_center += direction * 650.0 * dt
		camera_center.x = clampf(camera_center.x, 704.0, 1856.0)
		camera_center.y = clampf(camera_center.y, 357.0, 1083.0)
		battle.camera_center = camera_center
	if not session.paused: _advance(dt * session.speed)
	else: refresh(); battle.queue_redraw()

func _advance(dt: float) -> void:
	session.tick(dt)
	last_events = session.sim.drain_events()
	event_history.append_array(last_events)
	if event_history.size() > 256: event_history = event_history.slice(event_history.size() - 256)
	battle.accept_events(last_events)
	fx.accept(last_events)
	audio.accept(last_events, session.sim, battle.visible_world_rect())
	audio._process(dt)
	battle.advance(dt)
	battle.camera_center = camera_center
	battle.reduced_effects = reduced_effects
	fx.reduced = reduced_effects
	fx.advance(dt)
	refresh()

func refresh() -> void:
	if not is_instance_valid(inspector): return
	var unit: Dictionary = session.selected()
	battle.selected_id = session.selected_id if session.selected_kind == "hero" and not unit.is_empty() else -1
	if unit.is_empty():
		inspector.text = "点击单位查看属性 · 右键移动选中单位 · 无尽地图 WASD 平移视野\nQ / E 瞄准施放 · 角色与怪物均使用正式战斗判定"
	else:
		var range_value := float(unit.get("range", unit.get("attack_range", 0.0)))
		if session.selected_kind == "enemy": range_value = float(unit.get("attack_range", 52.0))
		var rate_value := float(unit.get("rate", 1.0 / maxf(0.01, float(unit.get("attack_interval", 1.0)))))
		var name_suffix := ""
		if session.selected_kind == "hero":
			var character: Dictionary = session.sim.database.characters.get(str(unit.character_id), {})
			if not bool(character.get("content_ready", false)): name_suffix = " · 未完成内容"
		inspector.text = "%s%s  |  生命 %.0f / %.0f  攻击 %.1f  护甲 %.0f\n普攻范围 %.0f  攻速 %.2f / 秒  移速 %.0f%s" % [str(unit.name), name_suffix, float(unit.hp), float(unit.max_hp), float(unit.damage), float(unit.get("armor", 0.0)), range_value, rate_value, float(unit.speed), "  ·  能量 %.0f / %.0f" % [float(unit.energy), float(unit.max_energy)] if session.selected_kind == "hero" else ""]
	var hero_selected: bool = session.selected_kind == "hero" and not unit.is_empty()
	for id: String in ["skill", "ultimate", "card"]: buttons[id].disabled = not hero_selected
	if hero_selected:
		buttons.skill.text = "Q " + session.sim.hero_skill_name(session.selected_id)
		buttons.ultimate.text = "E " + session.sim.hero_ultimate_name(session.selected_id)
		buttons.skill.icon = Icons.ability_texture(str(unit.character_id), false)
		buttons.ultimate.icon = Icons.ability_texture(str(unit.character_id), true)
	else:
		buttons.skill.text = "Q 技能"; buttons.ultimate.text = "E 终结技"
		buttons.skill.icon = null; buttons.ultimate.icon = null
	clock_label.text = "%05.2fs  ·  %02d 角色  /  %02d 敌人" % [session.sim.elapsed, session.sim.heroes.filter(func(h: Dictionary): return bool(h.deployed)).size(), session.sim.enemies.size()]
	pause_button.text = "继续" if session.paused else "暂停"
	pause_button.set("paused", session.paused)
	pause_button.queue_redraw()
	toolbar.set_paused(session.paused)
	notice.text = session.message
	battle.queue_redraw()
	marker.queue_redraw()

func over_ui(point: Vector2) -> bool:
	return Rect2(16, 10, 1248, 48).has_point(point) or Rect2(16, 616, 1248, 92).has_point(point) or (drawer.visible and drawer.get_global_rect().has_point(point)) or collapse_button.get_global_rect().has_point(point)

func _input(event: InputEvent) -> void:
	# The campaign input owner is suspended while this independent battle is open.
	# Keep GUI clicks unhandled so buttons and pickers still receive their events.
	if is_instance_valid(ui) and handle_input(event):
		get_viewport().set_input_as_handled()

func handle_input(event: InputEvent) -> bool:
	if closing: return true
	if event is InputEventKey and event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		pan_keys[event.keycode] = event.pressed and not card_search.has_focus()
	for picker: OptionButton in [map_picker, hero_picker, enemy_picker, card_picker, buttons.get("speed")]:
		if picker.get_popup().visible: return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_F10]: close(); return true
		if card_search.has_focus(): return false
		match event.keycode:
			KEY_TAB: toggle_drawer(); return true
			KEY_SPACE: toggle_pause(); return true
			KEY_PERIOD: step_once(); return true
			KEY_DELETE: session.remove_selected(); refresh(); return true
			KEY_Q: _begin_aim(false); return true
			KEY_E: _begin_aim(true); return true
	if event is InputEventMouseMotion:
		if not aiming.is_empty():
			battle.skill_point = battle.screen_to_world(battle.get_global_transform().affine_inverse() * event.position)
			battle.queue_redraw()
		return false
	if event is InputEventMouseButton and event.pressed:
		if over_ui(event.position): return false
		card_search.release_focus()
		var point: Vector2 = battle.screen_to_world(battle.get_global_transform().affine_inverse() * event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not placement_kind.is_empty() or not aiming.is_empty(): placement_kind = ""; aiming = ""; battle.skill_targeting = false
			else: session.move_selected(point)
			refresh(); return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not aiming.is_empty():
				session.cast(aiming == "ultimate", point)
				aiming = ""; battle.skill_targeting = false
			elif placement_kind == "hero":
				if session.place_hero(placement_id, point): placement_kind = ""
			elif placement_kind == "enemy": session.place_enemy(placement_id, point)
			else:
				if not session.select_at(point):
					var screen_point: Vector2 = battle.get_global_transform().affine_inverse() * event.position
					for hero: Dictionary in session.sim.heroes:
						if bool(hero.deployed) and battle.hero_pick_rect(hero).has_point(screen_point):
							session.selected_kind = "hero"; session.selected_id = int(hero.id); break
			refresh(); return true
	return false

func close() -> void:
	if closing: return
	closing = true
	set_physics_process(false)
	audio.reset()
	battle.reset_transients()
	fx.active.clear()
	closed.emit()
	queue_free()
