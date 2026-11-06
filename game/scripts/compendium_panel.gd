extends CanvasLayer
const GeneratedIconCatalog = preload("res://scripts/content/generated_icon_catalog.gd")
const AchievementCatalog = preload("res://scripts/achievement_catalog.gd")
const ACHIEVEMENT_CARD_RED = preload("res://assets/ui/rift_v2/components/mode_card_red.png")
const ACHIEVEMENT_CARD_GRAY = preload("res://assets/ui/rift_v2/components/mode_card_gray.png")
signal closed

const Catalog = preload("res://scripts/combat_catalog.gd")
const EnemySequenceLibrary = preload("res://scripts/enemy_sequence_library.gd")
const POSTER = preload("res://scripts/poster_surface.gd")
const SURFACE = preload("res://scripts/compendium_surface.gd")
const MOTION = preload("res://scripts/poster_motion.gd")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const WHITE := POSTER.PAPER
const MUTED := Color("#9a9590")
const ACCENT := POSTER.YELLOW

var root: Control
var list: VBoxContainer
var title: Label
var counter: Label
var tabs: Array[Button] = []
var scroll: ScrollContainer
var detail_overlay: ColorRect
var detail_frame: Control
var detail_return: Button
var footer: Label
var database
var progress
var hud
var active_tab := "characters"
var enemy_sequences = EnemySequenceLibrary.new()
var archive_frame: Control
var opening_serial := 0
var tab_serial := 0

func build(owner_hud, game_database, state) -> void:
	hud = owner_hud
	database = game_database
	progress = state
	layer = 40
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	var background := SURFACE.new()
	background.kind = "backdrop"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var frame := POSTER.new()
	archive_frame = frame
	frame.position = UI_LAYOUT.stage_compendium_frame_rect.position
	frame.size = UI_LAYOUT.stage_compendium_frame_rect.size
	frame.title_rect = UI_LAYOUT.stage_compendium_header_rect
	root.add_child(frame)
	var header: Rect2 = UI_LAYOUT.stage_compendium_header_rect
	title = owner_hud.label(frame, header.position + Vector2(14, 3), Vector2(640, 59), "角色图鉴", 42, WHITE)
	title.add_theme_font_override("font", POSTER.TYPE)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", POSTER.INK)
	var subtitle: Label = owner_hud.label(frame, header.position + Vector2(18, 61), Vector2(560, 23), "ARCHIVE / 奇怪的东西，统统归档。", 17, WHITE)
	subtitle.add_theme_font_override("font", POSTER.TYPE)
	counter = owner_hud.label(frame, Vector2(header.end.x - 412, header.position.y + 29), Vector2(245, 28), "", 19, WHITE)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var close_btn: Button = owner_hud.button(frame, Rect2(header.end.x - 152, header.position.y + 11, 136, 44), "返回 [Esc]", false)
	POSTER.style_button(close_btn, false, 20)
	close_btn.pressed.connect(close)
	var tab_data := [["characters", "角色图鉴"], ["cards", "卡牌图鉴"], ["enemies", "敌人档案"], ["achievements", "成就墙"], ["builds", "构筑战报"]]
	for i in tab_data.size():
		var tab_position: Vector2 = UI_LAYOUT.stage_compendium_tab_origin + Vector2((UI_LAYOUT.stage_compendium_tab_size.x + UI_LAYOUT.stage_compendium_tab_gap) * i, 0)
		var tab: Button = owner_hud.button(frame, Rect2(tab_position, UI_LAYOUT.stage_compendium_tab_size), tab_data[i][1], false)
		POSTER.style_button(tab, false, 22)
		tab.pressed.connect(show_tab.bind(str(tab_data[i][0])))
		tabs.append(tab)
	scroll = ScrollContainer.new()
	scroll.position = UI_LAYOUT.stage_compendium_scroll_rect.position
	scroll.size = UI_LAYOUT.stage_compendium_scroll_rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(UI_LAYOUT.stage_compendium_row_size.x, 0)
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	footer = owner_hud.label(frame, UI_LAYOUT.stage_compendium_footer_rect.position, UI_LAYOUT.stage_compendium_footer_rect.size, "点击条目展开档案  /  滚轮浏览  /  F2 或 Esc 返回  /  发现记录自动保存", 16, MUTED)
	footer.add_theme_font_override("font", POSTER.TYPE)
	detail_overlay = ColorRect.new()
	detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_overlay.color = Color(0.02, 0.02, 0.025, 0.86)
	detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(detail_overlay)
	detail_overlay.hide()
	root.visibility_changed.connect(_visibility_changed)
	root.hide()

func open(tab: String = "characters") -> void:
	MOTION.reset(root)
	MOTION.reset(detail_overlay)
	detail_overlay.hide()
	active_tab = tab
	show_tab(tab)
	root.show()
	_enter()

func close() -> void:
	if detail_overlay.visible:
		close_detail()
		return
	root.hide()
	closed.emit()

func is_open() -> bool:
	return root != null and root.visible

func show_tab(tab: String) -> void:
	tab_serial += 1
	MOTION.reset(detail_overlay)
	active_tab = tab
	detail_overlay.hide()
	scroll.scroll_vertical = 0
	for child in list.get_children():
		MOTION.reset(child)
		list.remove_child(child)
		child.queue_free()
	for i in tabs.size():
		POSTER.style_button(tabs[i], i == ["characters", "cards", "enemies", "achievements", "builds"].find(tab), 22)
	match tab:
		"cards": _show_cards()
		"enemies": _show_enemies()
		"achievements": _show_achievements()
		"builds": _show_builds()
		_: _show_characters()
	if root.visible:
		_enter_rows.call_deferred(tab_serial)

func _enter() -> void:
	opening_serial += 1
	var items: Array[Dictionary] = [{"node":archive_frame,"offset":Vector2(-36, 0),"delay":0.0,"scale":0.985}]
	for index in tabs.size():
		items.append({"node":tabs[index],"offset":Vector2(0, 15),"delay":0.03 + index * 0.023,"scale":1.0})
	items.append({"node":scroll,"offset":Vector2(0, 22),"delay":0.09,"scale":1.0})
	items.append({"node":footer,"offset":Vector2(0, 12),"delay":0.12,"scale":1.0})
	MOTION.enter(root, items, bool(hud.reduced))
	_enter_rows.call_deferred(tab_serial)

func _enter_rows(serial: int) -> void:
	if serial != tab_serial or not root.visible: return
	# Animate the paper contents, not rows managed by VBoxContainer; scrolling and
	# full-strip click areas stay stable while the first visible entries settle.
	for index in mini(3, list.get_child_count()):
		var row: Control = list.get_child(index)
		var items: Array[Dictionary] = []
		for child in row.get_children():
			if child is Control:
				items.append({"node":child,"offset":Vector2(24, 0),"delay":index * 0.045,"scale":1.0})
		if not items.is_empty(): MOTION.enter(row, items, bool(hud.reduced))

func _visibility_changed() -> void:
	if root.visible: return
	tab_serial += 1
	MOTION.reset(root)
	MOTION.reset(detail_overlay)
	for child in list.get_children(): MOTION.reset(child)
	detail_overlay.hide()

func _show_characters() -> void:
	title.text = "角色图鉴"
	var unlocked := 0
	for id: String in database.characters:
		var data: Dictionary = database.characters[id]
		var known: bool = bool(data.get("content_ready", false)) and progress.unlocked_characters.has(id)
		unlocked += int(known)
		var name: String = str(data.name) if known else "？？？"
		var skill: Dictionary = data.get("active_skill", {})
		var ultimate: Dictionary = data.get("ultimate", {})
		var body: String = "%s · %s  /  Q %s  /  E %s" % [_element_name(str(data.element)), data.role, skill.get("name", "主动技能"), ultimate.get("name", "终结技")] if known else "档案封锁    /    随剧情推进后解锁"
		var detail_body := body
		if known:
			detail_body += "\n\n基础战斗参数\n生命 %d   攻击 %d   护甲 %d\n攻速 %.2f / 秒   射程 %d   移速 %d\n阻挡 %d   %s" % [int(data.get("max_hp", 0)), int(data.get("attack", 0)), int(data.get("armor", 0)), float(data.get("attack_rate", 0)), int(data.get("attack_range", 0)), int(data.get("move_speed", 0)), int(data.get("block", 0)), "可对空" if data.get("can_hit_air", false) else "攻击地面目标"]
			detail_body += "\n\nQ  %s\n冷却 %.1f 秒   伤害 %d   范围 %d" % [str(skill.get("name", "主动技能")), float(skill.get("cooldown", 0)), int(skill.get("power", 0)), int(skill.get("radius", 0))]
			detail_body += "\n\nE  %s\n消耗 %d 能量   伤害 %d   范围 %d" % [str(ultimate.get("name", "终结技")), int(ultimate.get("energy_cost", 0)), int(ultimate.get("power", 0)), int(ultimate.get("radius", 0))]
		_add_row(name, body, _element_color(str(data.element)) if known else MUTED, known, "", str(database.assets.get(str(data.get("asset_key", "")), {}).get("portrait", "")) if known else "", detail_body)
	counter.text = "解锁 %d / %d" % [unlocked, database.characters.size()]

func _show_cards() -> void:
	title.text = "卡牌图鉴"
	var discovered := 0
	for card: Dictionary in database.cards:
		var id := str(card.id)
		var known: bool = progress.discovered_cards.has(id)
		discovered += int(known)
		var rarity := str(card.rarity)
		var tag_text := "机关" if str(card.get("family", "")) == "device" else " / ".join(card.get("tags", []))
		var evolution := " · 可进化" if not card.get("evolutions", []).is_empty() else ""
		var card_body := "%s\n标签：%s%s" % [str(card.description), tag_text, evolution]
		var target_scope := "机关" if str(card.get("family", "")) == "device" else ("选定角色" if str(card.get("target", "")) == "character" else "全队")
		var level_copy := "\n\n作用对象：%s\n等级上限：Lv.%d\n此处显示首级收益；后续等级以选卡时的实际升级预览为准。" % [target_scope, int(card.get("max_stacks", 1))]
		_add_row(str(card.name) if known else "？？？", card_body if known else "在升级三选一中首次获得后记录", _rarity_color(rarity) if known else MUTED, known, _rarity_name(rarity) if known else "未发现", GeneratedIconCatalog.card_path(card) if known else "", card_body + level_copy if known else "在升级三选一中首次获得后记录")
	counter.text = "发现 %d / %d" % [discovered, database.cards.size()]

func _show_achievements() -> void:
	title.text = "\u88c2\u9699\u6210\u5c31\u5899"
	var unlocked: int = progress.unlocked_achievements.size()
	var row: HBoxContainer
	for index in AchievementCatalog.ITEMS.size():
		if index % 4 == 0:
			row = HBoxContainer.new()
			row.custom_minimum_size = Vector2(UI_LAYOUT.stage_compendium_row_size.x, 172)
			row.add_theme_constant_override("separation", 12)
			list.add_child(row)
		_add_achievement_tile(row, AchievementCatalog.ITEMS[index])
	counter.text = "\u5b8c\u6210 %d / %d" % [unlocked, AchievementCatalog.ITEMS.size()]

func _add_achievement_tile(parent: HBoxContainer, item: Dictionary) -> void:
	var id := str(item.id)
	var known: bool = progress.unlocked_achievements.has(id)
	var tier := str(item.get("tier", "silver"))
	var color := AchievementCatalog.tier_color(tier) if known else MUTED
	var tile := Button.new()
	tile.custom_minimum_size = Vector2((UI_LAYOUT.stage_compendium_row_size.x - 36) / 4, 166)
	tile.text = ""
	for state in ["normal", "hover", "pressed", "focus", "disabled"]: tile.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	parent.add_child(tile)
	var surface := SURFACE.new()
	surface.kind = "row"
	surface.accent = color
	surface.known = known
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tile.add_child(surface)
	var icon_path := AchievementCatalog.icon_path(id)
	if ResourceLoader.exists(icon_path): hud.icon(tile, icon_path, Rect2(12, 22, 78, 118), Color.WHITE if known else Color("#666666"))
	var name_label: Label = hud.label(tile, Vector2(104, 19), Vector2(152, 43), str(item.name), 21, POSTER.INK if known else Color("#65605b"))
	name_label.add_theme_font_override("font", POSTER.TYPE)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var body: Label = hud.label(tile, Vector2(104, 70), Vector2(152, 54), str(item.description), 15, POSTER.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var status: Label = hud.label(tile, Vector2(104, 132), Vector2(152, 22), progress.achievement_progress(id, database), 14, POSTER.RED if known else Color("#655e58"))
	tile.pressed.connect(show_detail.bind(str(item.name), str(item.description) + "\n\n%s · %s\n%s" % [str(item.group), AchievementCatalog.tier_name(tier), progress.achievement_progress(id, database)], color, known, "已完成" if known else "待完成", icon_path))

func _show_builds() -> void:
	title.text = "最终构筑战报"
	if progress.build_history.is_empty():
		_add_row("尚无结算记录", "完成或失败一局后，会记录卡牌、遗物、伤害贡献、触发次数与最高能量。", MUTED, false)
		counter.text = "记录 0 / 20"
		return
	for record: Dictionary in progress.build_history:
		var lines: Array[String] = []
		for hero: Dictionary in record.get("characters", []):
			lines.append("%s 伤害%d · 普攻%d · 技能%d · 终结技%d · 最高能量%d" % [hero.get("name","角色"), int(hero.get("damage",0)), int(hero.get("attacks",0)), int(hero.get("skills",0)), int(hero.get("ultimates",0)), int(hero.get("max_energy",0))])
		var stage_id := str(record.get("stage_id", ""))
		var stage_name := str(database.stages.get(stage_id, {}).get("name", "无尽荒原" if stage_id == "stage_endless" else "未知区域"))
		var stage_icon := "res://assets/ui/stage_thumbnails_v60/%s.png" % stage_id
		if not ResourceLoader.exists(stage_icon):
			stage_icon = "res://assets/ui/icons/temporary/nieobie/level.svg"
		var title_text := "%s · 击杀%d · 闪避%d · 最高叠层Lv.%d" % [stage_name, int(record.get("kills",0)), int(record.get("dodges",0)), int(record.get("highest_stack",0))]
		_add_row(title_text, "\n".join(lines), ACCENT, true, "%d项强化" % record.get("buff_levels",{}).size(), stage_icon)
	counter.text = "记录 %d / 20" % progress.build_history.size()

func _show_enemies() -> void:
	title.text = "敌人档案"
	var discovered := 0
	for id: String in Catalog.ENEMIES:
		var data: Dictionary = Catalog.ENEMIES[id]
		var known: bool = progress.encountered_enemies.has(id)
		discovered += int(known)
		var traits: Array[String] = []
		if data.get("flying", false): traits.append("飞行")
		if data.has("attack_range"): traits.append("远程")
		if data.has("aura_radius"): traits.append("增益光环")
		if data.has("shield"): traits.append("护盾")
		if data.has("boss_pulse"): traits.append("Boss 脉冲")
		if bool(data.get("spawner", false)): traits.append("产怪")
		if float(data.get("large_scale", 1.0)) > 1.0: traits.append("大型")
		if float(data.get("death_burst", 0.0)) > 0.0: traits.append("自爆")
		var trait_text := " / ".join(traits) if not traits.is_empty() else "近战"
		var body: String = "HP %.0f · 护甲 %.0f · 移速 %.0f · %s" % [data.hp, data.armor, data.speed, trait_text] if known else "遭遇该敌人后解锁战斗情报"
		var preview_path := ""
		if known and enemy_sequences.has_enemy(id):
			preview_path = enemy_sequences.portrait_path(id)
		elif known and database.enemy_visuals.has(id):
			preview_path = str(database.enemy_visuals[id].get("sprite", ""))
		var details := body
		if known:
			details += "\n\n基础战斗参数\n生命 %d   攻击 %d   护甲 %d\n攻速 %.2f / 秒   移速 %d\n攻击距离 %d" % [int(data.hp), int(data.damage), int(data.armor), float(data.rate), int(data.speed), int(data.get("attack_range", 80))]
			if data.has("shield"): details += "\n护盾 %d" % int(data.shield)
			if data.has("aura_radius"): details += "\n增益光环范围 %d" % int(data.aura_radius)
			if data.has("heal_radius"): details += "\n治疗范围 %d" % int(data.heal_radius)
			if data.get("spawner", false): details += "\n持续召唤增援"
			details += "\n\n无尽模式中的等级与强化会进一步提升这些数值。"
		_add_row(str(data.name) if known else "未知敌影", body, Color(data.color) if known else MUTED, known, "BOSS" if id.begins_with("boss") and known else "", preview_path, details)
	counter.text = "遭遇 %d / %d" % [discovered, Catalog.ENEMIES.size()]

func _add_row(name: String, body: String, color: Color, known: bool, badge: String = "", preview_path: String = "", detail_body: String = "") -> void:
	var row := Button.new()
	row.custom_minimum_size = UI_LAYOUT.stage_compendium_row_size
	row.clip_contents = true
	row.text = ""
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]: row.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	list.add_child(row)
	var surface := SURFACE.new()
	surface.kind = "row"
	surface.accent = color
	surface.known = known
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(surface)
	row.mouse_entered.connect(func(): surface.highlighted = true; surface.queue_redraw())
	row.mouse_exited.connect(func(): surface.highlighted = false; surface.queue_redraw())
	row.focus_entered.connect(func(): surface.highlighted = true; surface.queue_redraw())
	row.focus_exited.connect(func(): surface.highlighted = false; surface.queue_redraw())
	var icon_rect: Rect2 = UI_LAYOUT.stage_compendium_icon_rect
	var icon_back := ColorRect.new()
	icon_back.position = icon_rect.position
	icon_back.size = icon_rect.size
	icon_back.color = POSTER.INK if known else Color("#4e4b48")
	icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_back)
	_add_preview(row, preview_path, icon_rect.grow(-5), color, known)
	var text_x := icon_rect.end.x + 20
	var name_label: Label = hud.label(row, Vector2(text_x, 14), Vector2(row.custom_minimum_size.x - text_x - 175, 37), name, 28, POSTER.INK if known else Color("#6b6560"))
	name_label.add_theme_font_override("font", POSTER.TYPE)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var body_label: Label = hud.label(row, Vector2(text_x, 60), Vector2(row.custom_minimum_size.x - text_x - 28, 77), body, 18, Color("#292725") if known else Color("#6b6560"))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_constant_override("line_spacing", 3)
	if not badge.is_empty():
		var tag: Label = hud.label(row, Vector2(row.custom_minimum_size.x - 172, 19), Vector2(146, 28), badge, 19, POSTER.RED if known else Color("#6b6560"))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.set_meta("archive_known", known)
	row.set_meta("archive_preview", preview_path)
	row.pressed.connect(show_detail.bind(name, detail_body if not detail_body.is_empty() else body, color, known, badge, preview_path))

func _add_preview(parent: Control, preview_path: String, rect: Rect2, color: Color, known: bool) -> void:
	if not preview_path.is_empty() and ResourceLoader.exists(preview_path):
		var image := TextureRect.new()
		image.name = "ArchivePreview"
		image.position = rect.position
		image.size = rect.size
		image.texture = ResourceLoader.load(preview_path)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.modulate = Color.WHITE if known else Color("#777777")
		parent.add_child(image)
	else:
		var placeholder: Label = hud.label(parent, rect.position, rect.size, "?", 62, WHITE)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_detail(name: String, body: String, color: Color, known: bool, badge: String, preview_path: String) -> void:
	MOTION.reset(detail_overlay)
	for child in detail_overlay.get_children():
		detail_overlay.remove_child(child)
		child.queue_free()
	detail_frame = POSTER.new()
	detail_frame.position = UI_LAYOUT.stage_compendium_detail_rect.position
	detail_frame.size = UI_LAYOUT.stage_compendium_detail_rect.size
	detail_frame.title_rect = Rect2(20, 18, detail_frame.size.x - 40, 72)
	detail_overlay.add_child(detail_frame)
	var name_label: Label = hud.label(detail_frame, Vector2(36, 28), Vector2(detail_frame.size.x - 239, 48), name, 32, WHITE)
	name_label.add_theme_font_override("font", POSTER.TYPE)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_return = hud.button(detail_frame, Rect2(detail_frame.size.x - 183, 33, 148, 42), "返回列表", false)
	POSTER.style_button(detail_return, false, 21)
	detail_return.pressed.connect(close_detail)
	var image_rect := Rect2(30, 112, 274, detail_frame.size.y - 167)
	var image_back := Panel.new()
	image_back.position = image_rect.position
	image_back.size = image_rect.size
	image_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_back.add_theme_stylebox_override("panel", POSTER.paper_style())
	detail_frame.add_child(image_back)
	_add_preview(image_back, preview_path, Rect2(Vector2(12, 12), image_rect.size - Vector2(24, 48)), color, known)
	var image_caption: Label = hud.label(image_back, Vector2(12, image_rect.size.y - 35), Vector2(image_rect.size.x - 24, 24), badge if not badge.is_empty() else "档案已解锁" if known else "档案封锁", 17, POSTER.RED if known else Color("#68615a"))
	image_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var details := RichTextLabel.new()
	details.position = Vector2(332, 119)
	details.size = Vector2(detail_frame.size.x - 366, detail_frame.size.y - 174)
	details.text = body
	details.add_theme_font_override("normal_font", POSTER.TYPE)
	details.add_theme_font_size_override("normal_font_size", 22)
	details.add_theme_color_override("default_color", WHITE)
	details.add_theme_constant_override("line_separation", 7)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.scroll_active = true
	detail_frame.add_child(details)
	hud.label(detail_frame, Vector2(38, detail_frame.size.y - 41), Vector2(detail_frame.size.x - 76, 22), "Esc 返回列表 / 滚轮阅读完整档案", 15, MUTED)
	detail_overlay.show()
	var items: Array[Dictionary] = [{"node":detail_frame,"offset":Vector2(0, 28),"delay":0.0,"scale":0.985}, {"node":image_back,"offset":Vector2(-22, 0),"delay":0.035,"scale":1.0}, {"node":details,"offset":Vector2(24, 0),"delay":0.07,"scale":1.0}]
	MOTION.enter(detail_overlay, items, bool(hud.reduced))
	detail_return.grab_focus()

func close_detail() -> void:
	MOTION.reset(detail_overlay)
	detail_overlay.hide()
	if not tabs.is_empty(): tabs[maxi(0, ["characters", "cards", "enemies", "achievements", "builds"].find(active_tab))].grab_focus()

func _rarity_name(rarity: String) -> String:
	return {"common": "普通", "rare": "稀有", "epic": "史诗", "legendary": "传奇", "mythic":"创世", "genesis":"创世"}.get(rarity, rarity)

func _rarity_color(rarity: String) -> Color:
	return {"common": Color("#d8d1ca"), "rare": Color("#62b8ee"), "epic": Color("#c781f0"), "legendary": Color("#ffc94d"), "mythic":Color("#65e0d6"), "genesis":Color("#65e0d6")}.get(rarity, WHITE)

func _element_name(element: String) -> String:
	return {"none": "无元素", "anemo": "风元素", "electro": "雷元素", "pyro": "火元素", "hydro": "水元素", "geo": "岩元素", "cryo": "冰元素"}.get(element, element)

func _element_color(element: String) -> Color:
	return {"none": WHITE, "anemo": Color("#63e6c0"), "electro": Color("#bf83ff"), "pyro": Color("#ff745c"), "hydro": Color("#5ab8ff"), "geo": Color("#e8b94d"), "cryo": Color("#9de7f2")}.get(element, WHITE)

func _card_icon_path(effect: String) -> String:
	var file_name: String = {
		"attack_multiplier":"10_sword_slash_rgba.png", "squad_attack_multiplier":"10_sword_slash_rgba.png",
		"health_multiplier":"08_healing_heart_rgba.png", "squad_health_multiplier":"08_healing_heart_rgba.png", "crystal_heal":"08_healing_heart_rgba.png",
		"attack_rate_multiplier":"12_speed_boot_rgba.png", "squad_rate_multiplier":"12_speed_boot_rgba.png", "move_speed_flat":"12_speed_boot_rgba.png",
		"range_flat":"09_arrow_rain_rgba.png", "squad_range_flat":"09_arrow_rain_rgba.png",
		"armor_flat":"11_shield_rgba.png", "squad_armor_flat":"11_shield_rgba.png", "crystal_health_flat":"14_summon_crystal_rgba.png",
		"assign_traveler_element":"14_summon_crystal_rgba.png", "element_mastery_flat":"03_lightning_rgba.png", "squad_mastery_flat":"03_lightning_rgba.png",
		"element_technique":"06_laser_rgba.png", "special_upgrade":"15_explosion_rgba.png", "signature_upgrade":"15_explosion_rgba.png",
		"crit_flat":"10_sword_slash_rgba.png", "squad_crit_flat":"10_sword_slash_rgba.png", "squad_chain":"03_lightning_rgba.png", "last_stand":"11_shield_rgba.png",
		"reaction_overdrive":"15_explosion_rgba.png", "reaction_bonus":"01_fireball_rgba.png"
	}.get(effect, "14_summon_crystal_rgba.png")
	return "res://assets/ui/skill_icons_v64/" + file_name
