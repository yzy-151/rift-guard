extends CanvasLayer
signal reward_action(index: int)
signal primary_action
signal pause_action
signal restart_action
signal select_action(hero_id: int)
signal mute_action(enabled: bool)
signal reduce_action(enabled: bool)
signal compendium_action
signal skill_action

const WHITE = Color("#f3e9df")
const MUTED = Color("#ae969f")
const TEAL = Color("#e3a2a5")
const HT_BUTTON = preload("res://assets/helltaker/ui/button.png")
const HT_BUTTON_HOVER = preload("res://assets/helltaker/ui/button hover.png")
const HT_BUTTON_ACTIVE = preload("res://assets/helltaker/ui/button active.png")
const HT_PANEL = preload("res://assets/helltaker/ui/button on.png")
const HT_HIGHLIGHT = preload("res://assets/helltaker/audio/button_menu_highlight_01.wav")
const HT_CONFIRM = preload("res://assets/helltaker/audio/button_menu_confirm_01.wav")
var config
var reward_panel
var progression_label: Label
var hero_details: Array[Label] = []
var base_label: Label
var wave_label: Label
var count_label: Label
var status_label: Label
var pause_button: Button
var hero_buttons: Array[Button] = []
var hero_name_labels: Array[Label] = []
var hero_statuses: Array[Label] = []
var overlay: ColorRect
var modal_title: Label
var modal_copy: Label
var modal_action: Button
var signature: String = ""
var reduced: bool = false
var muted: bool = false
var background_buttons: Array[Button] = []
var support_panel: Panel
var support_labels: Array[Label] = []
var buff_panel: Panel
var buff_labels: Array[Label] = []
var skill_button: Button
var skill_aiming: bool = false
var ui_highlight: AudioStreamPlayer
var ui_confirm: AudioStreamPlayer

func _ready() -> void:
	ui_highlight = AudioStreamPlayer.new()
	ui_highlight.stream = HT_HIGHLIGHT
	ui_highlight.volume_db = -15.0
	ui_confirm = AudioStreamPlayer.new()
	ui_confirm.stream = HT_CONFIRM
	ui_confirm.volume_db = -13.0
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	ui_theme.default_font = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
	ui_theme.default_font_size = 15
	root.theme = ui_theme
	add_child(root)
	add_child(ui_highlight)
	add_child(ui_confirm)
	label(root, Vector2(34, 7), Vector2(560, 22), "R I F T   G U A R D     /     边 境 防 线", 13, TEAL)
	bind(label(root, Vector2(32, 27), Vector2(700, 43), "模式一  /  裂隙守望", 32, WHITE), "game_title")
	bind(label(root, Vector2(207, 40), Vector2(500, 24), "城门之下 · 守至黎明", 14, MUTED), "game_subtitle")
	progression_label = label(root, Vector2(620, 47), Vector2(625, 22), "", 12, TEAL)
	progression_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var archive_btn := button(root, Rect2(740, 8, 156, 36), "图鉴  [F2]", false)
	archive_btn.pressed.connect(func(): compendium_action.emit())
	pause_button = button(root, Rect2(911, 8, 156, 36), "暂停  [空格]", false)
	bind(pause_button, "pause_button")
	pause_button.pressed.connect(func(): pause_action.emit())
	var reset_btn := button(root, Rect2(1080, 8, 168, 36), "重新开始  [R]", false)
	bind(reset_btn, "restart_button")
	reset_btn.pressed.connect(func(): restart_action.emit())
	panel(root, Rect2(32, 74, 1216, 25), Color("#261d27"), Color("#543640"))
	base_label = label(root, Vector2(48, 75), Vector2(240, 27), "", 15, TEAL)
	wave_label = label(root, Vector2(333, 75), Vector2(180, 27), "", 15, WHITE)
	count_label = label(root, Vector2(535, 75), Vector2(280, 27), "", 14, MUTED)
	status_label = label(root, Vector2(879, 75), Vector2(340, 27), "", 14, TEAL)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	support_panel = panel(root, Rect2(886, 106, 362, 106), Color(0.07, 0.045, 0.075, 0.92), Color("#864858"))
	label(support_panel, Vector2(12, 6), Vector2(335, 20), "场 外 支 援  /  SUPPORT", 11, TEAL)
	for i in 4:
		support_labels.append(label(support_panel, Vector2(12, 28 + i * 18), Vector2(335, 18), "", 12, WHITE))
	support_panel.hide()
	buff_panel = panel(root, Rect2(32, 106, 430, 124), Color(0.07, 0.045, 0.075, 0.92), Color("#65506f"))
	label(buff_panel, Vector2(12, 6), Vector2(405, 20), "本 局 强 化  /  BUILD", 11, Color("#d6b4f0"))
	for i in 5:
		buff_labels.append(label(buff_panel, Vector2(12, 28 + i * 18), Vector2(405, 18), "", 12, WHITE))
	buff_panel.hide()
	skill_button = button(root, Rect2(900, 540, 348, 62), "旅行者战技  [Q]", true)
	skill_button.add_theme_font_size_override("font_size", 17)
	skill_button.pressed.connect(func(): skill_action.emit())

	for i in 3:
		var hero_btn := button(root, Rect2(32 + i * 284, 616, 272, 88), "", true)
		bind(hero_btn, "hero_card_%d" % (i + 1))
		hero_btn.name = "HeroCard%d" % (i + 1)
		var trim := Sprite2D.new()
		trim.texture = preload("res://assets/helltaker/ui/W_selection.png")
		trim.position = Vector2(242, 19)
		trim.scale = Vector2(0.10, 0.10)
		hero_btn.add_child(trim)
		hero_btn.pressed.connect(func(): select_action.emit(i))
		hero_buttons.append(hero_btn)
		hero_name_labels.append(label(hero_btn, Vector2(14, 7), Vector2(250, 28), "%d  未部署" % [i + 1], 16, WHITE))
		hero_statuses.append(label(hero_btn, Vector2(14, 34), Vector2(250, 23), "", 13, WHITE))
		var details: String = "阻挡 2 人 · 移动会放行" if i == 0 else ("火系普攻 · 与水触发蒸发" if i == 1 else "水系普攻 · 自动治疗队友")
		hero_details.append(label(hero_btn, Vector2(14, 62), Vector2(250, 20), details, 12, MUTED))
	label(root, Vector2(900, 656), Vector2(348, 23), "1/2/3 选人 · 右键移动", 13, TEAL)
	label(root, Vector2(900, 684), Vector2(348, 21), "M5 · F6 对话预览 / F7 特效预览", 12, MUTED)
	var mute_btn := button(root, Rect2(900, 617, 155, 32), "声音：开", false)
	mute_btn.pressed.connect(func():
		muted = not muted
		mute_btn.text = "声音：关" if muted else "声音：开"
		mute_action.emit(muted))
	var reduce_btn := button(root, Rect2(1067, 617, 181, 32), "反馈：标准", false)
	reduce_btn.pressed.connect(func():
		reduced = not reduced
		reduce_btn.text = "反馈：减弱" if reduced else "反馈：标准"
		reduce_action.emit(reduced))
	background_buttons = [archive_btn, pause_button, reset_btn, mute_btn, reduce_btn, skill_button]
	background_buttons.append_array(hero_buttons)
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.035, 0.05, 0.76)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var menu_background := TextureRect.new()
	menu_background.texture = preload("res://assets/helltaker/backgrounds/chapterBG0001.png")
	menu_background.position = Vector2.ZERO
	menu_background.size = Vector2(1280, 720)
	menu_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_background.show()
	overlay.add_child(menu_background)
	bind(menu_background, "menu_background")
	var card := panel(overlay, Rect2(330, 170, 620, 375), Color("#241a26"), Color("#a34c60"))
	bind(ornament(card, Rect2(-20, -25, 660, 420)), "menu_frame")
	panel(card, Rect2(32, 52, 556, 203), Color("#241a26"), Color("#241a26"))
	label(card, Vector2(48, 63), Vector2(472, 22), "RIFT GUARD   /   防线指令", 12, TEAL)
	modal_title = label(card, Vector2(42, 112), Vector2(536, 45), "", 29, WHITE)
	modal_copy = label(card, Vector2(42, 167), Vector2(536, 86), "", 16, Color("#b6c2c8"))
	modal_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_action = button(card, Rect2(42, 281, 536, 47), "", true)
	modal_action.pressed.connect(func(): primary_action.emit())
	reward_panel = preload("res://scripts/reward_panel.gd").new()
	root.add_child(reward_panel)
	reward_panel.build(self)
	reward_panel.chosen.connect(func(index: int): reward_action.emit(index))

func label(parent: Node, at: Vector2, dimensions: Vector2, text: String, size: int, color: Color) -> Label:
	var item := Label.new()
	item.position = at
	item.size = dimensions
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func style(fill: Color, border: Color) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = HT_PANEL
	box.modulate_color = fill.lightened(0.32)
	box.texture_margin_left = 5.0
	box.texture_margin_top = 5.0
	box.texture_margin_right = 5.0
	box.texture_margin_bottom = 5.0
	box.content_margin_left = 8.0
	box.content_margin_top = 6.0
	box.content_margin_right = 8.0
	box.content_margin_bottom = 6.0
	return box

func button_style(texture: Texture2D, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.modulate_color = tint
	box.texture_margin_left = 5.0
	box.texture_margin_top = 5.0
	box.texture_margin_right = 5.0
	box.texture_margin_bottom = 5.0
	box.content_margin_left = 9.0
	box.content_margin_right = 9.0
	return box

func panel(parent: Node, rect: Rect2, fill: Color, border: Color) -> Panel:
	var item := Panel.new()
	item.position = rect.position
	item.size = rect.size
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_stylebox_override("panel", style(fill, border))
	parent.add_child(item)
	return item

func button(parent: Node, rect: Rect2, text: String, accent: bool) -> Button:
	var item := Button.new()
	item.position = rect.position
	item.size = rect.size
	item.text = text
	item.add_theme_color_override("font_color", WHITE)
	item.add_theme_color_override("font_hover_color", Color.WHITE)
	item.add_theme_font_size_override("font_size", 14)
	item.add_theme_stylebox_override("normal", button_style(HT_BUTTON, Color("#fff0f0") if accent else Color.WHITE))
	item.add_theme_stylebox_override("hover", button_style(HT_BUTTON_HOVER))
	item.add_theme_stylebox_override("pressed", button_style(HT_BUTTON_ACTIVE))
	item.add_theme_stylebox_override("focus", button_style(HT_BUTTON_HOVER, Color("#ffdddd")))
	item.mouse_entered.connect(func():
		if ui_highlight != null and not bool(item.get_meta("dialogue_sound", false)):
			ui_highlight.stop()
			ui_highlight.play())
	item.pressed.connect(func():
		if ui_confirm != null and not bool(item.get_meta("dialogue_sound", false)):
			ui_confirm.stop()
			ui_confirm.play())
	parent.add_child(item)
	return item

func refresh(sim, selected_id: int) -> void:
	var next_signature: String = str([sim.state, sim.base_hp, sim.wave, sim.kills, sim.enemies.size(), sim.reactions, ceili(sim.wave_timer), selected_id, sim.team_level, sim.team_xp, sim.run_seed, sim.rewards.history, sim.supports, ceili(sim.traveler_skill_cooldown * 10.0), sim.geo_constructs.size(), skill_aiming])
	if sim.v2_mode:
		next_signature += str([sim.run_state.traveler_element, sim.run_state.pending_level_ups, floori(sim.stage_runtime.remaining_seconds())])
	for hero in sim.heroes:
		next_signature += str([ceili(hero.hp), hero.moving, hero.blocked])
	if next_signature == signature:
		return
	signature = next_signature
	base_label.text = "◆ 基地 %03d/100   ◇ 结晶盾 %03d" % [sim.base_hp, ceili(sim.crystal_shield)] if sim.v2_mode else "◆  基地完整度    %03d / 100" % sim.base_hp
	if sim.v2_mode:
		var next_xp: int = sim.crystal.next_threshold(sim.run_state)
		var xp_text: String = "MAX" if next_xp < 0 else "%d / %d" % [sim.run_state.crystal_xp, next_xp]
		var seconds: int = ceili(sim.stage_runtime.remaining_seconds())
		progression_label.text = "水晶 Lv.%d  ·  EXP %s  ·  旅行者：%s元素  ·  %02d:%02d" % [sim.run_state.crystal_level, xp_text, sim.element_name(sim.run_state.traveler_element), seconds / 60, seconds % 60]
		wave_label.text = "波次   %02d / %02d" % [sim.wave, sim.stage_runtime.definition.get("waves", []).size()]
	else:
		progression_label.text = "小队 Lv.%d / 5    ·    经验 %d    ·    强化 %d    ·    种子 %d" % [sim.team_level, sim.team_xp, sim.rewards.history.size(), sim.run_seed]
		wave_label.text = "节点   %02d / 05" % sim.wave
	count_label.text = ("击退 %02d  ·  在场 %02d  ·  强化 %02d" % [sim.kills, sim.enemies.size(), sim.rewards.history.size()]) if sim.v2_mode else ("击退 %02d  ·  在场 %02d  ·  蒸发 %02d" % [sim.kills, sim.enemies.size(), sim.reactions])
	status_label.text = "按 1/2/3 或点击角色卡选择"
	refresh_skill(sim)
	refresh_supports(sim)
	refresh_buffs(sim)
	if selected_id >= 0 and selected_id < sim.heroes.size():
		var hero: Dictionary = sim.heroes[selected_id]
		status_label.text = hero.name + (" · 已倒地，波末恢复" if hero.hp <= 0 else (" · 移动中，暂停攻击" if hero.moving else " · 自动攻击 / 右键走位"))
	if sim.state == "between":
		status_label.text = "队伍休整 · %d 秒后继续" % ceili(sim.wave_timer)
	pause_button.disabled = sim.state in ["ready", "won", "lost", "reward"]
	pause_button.text = "继续  [空格]" if sim.state == "paused" else "暂停  [空格]"
	for i in hero_buttons.size():
		hero_buttons[i].visible = i < sim.heroes.size()
	for i in sim.heroes.size():
		var hero: Dictionary = sim.heroes[i]
		hero_name_labels[i].text = "%d  %s / %s" % [i + 1, hero.name, hero.role]
		var hero_color: Color = element_color(str(hero.get("element", ""))) if hero.get("character_id", "") == "traveler" and hero.get("element", "") != "" else Color(hero.color)
		hero_name_labels[i].add_theme_color_override("font_color", hero_color)
		hero_buttons[i].modulate = Color.WHITE if i == selected_id else Color("#91a0a8")
		var status: String = "倒地 · 本波无法行动" if hero.hp <= 0 else ("移动中" if hero.moving else ("阻挡 %d/%d" % [hero.blocked, hero.block] if i == 0 else "就绪"))
		var mechanics := "弹道%d · 穿透%d · 连锁%d" % [int(hero.get("projectile_count", 1)), int(hero.get("pierce", 0)), int(hero.get("chain_count", 0))]
		hero_details[i].text = "%s元素 · ATK %.0f · %.1f/s · %s" % [sim.element_name(str(hero.get("element", "none"))), hero.damage, hero.rate, mechanics]
		hero_statuses[i].text = "HP %d/%d · %s" % [ceili(hero.hp), ceili(hero.max_hp), status]
	var was_visible: bool = overlay.visible
	overlay.visible = sim.state in ["ready", "paused", "won", "lost"]
	for control in background_buttons:
		control.focus_mode = Control.FOCUS_NONE if overlay.visible or sim.state == "reward" else Control.FOCUS_ALL
	if sim.state == "reward":
		reward_panel.display(sim)
	else:
		reward_panel.hide()
	if overlay.visible:
		modal_action.focus_next = modal_action.get_path()
		modal_action.focus_previous = modal_action.get_path()
		modal_action.focus_neighbor_top = modal_action.get_path()
		modal_action.focus_neighbor_bottom = modal_action.get_path()
		modal_action.focus_neighbor_left = modal_action.get_path()
		modal_action.focus_neighbor_right = modal_action.get_path()
		match sim.state:
			"ready":
				var stage: Dictionary = sim.database.stages.get(sim.current_stage_id, {}) if sim.v2_mode else {}
				var duration: int = int(stage.get("duration_seconds", 330))
				modal_title.text = "守住最后一道防线"
				modal_copy.text = "%s  ·  %d分%02d秒\n击杀敌人升级水晶，三选一强化可无限叠加。\n选定元素后按 Q 释放战技，守住三条路线。" % [stage.get("name", "裂隙防线"), duration / 60, duration % 60] if sim.v2_mode else "1 守卫阻挡 · 2 火系输出 · 3 水系治疗\n火水交替命中，触发蒸发增伤。\n守住 5 个节点，节点之间三选一强化。"
				modal_action.text = "开始防守   →   [Enter]"
			"paused":
				modal_title.text = "战术暂停"
				modal_copy.text = "战场、弹体和攻击冷却已冻结。\n准备好后，继续守住你的防线。"
				modal_action.text = "继续防守   →   [空格]"
			"won":
				modal_title.text = "防线守住了"
				modal_copy.text = "击退 %d 名敌人  ·  基地剩余 %d%%\n触发元素反应 %d 次\n本关构筑将在进入下一关时重置。" % [sim.kills, sim.base_hp, sim.reactions]
				modal_action.text = "再守一次   →   [Enter]"
			"lost":
				modal_title.text = "核心已经失守"
				modal_copy.text = "击退 %d 名敌人  ·  坚持到第 %d 波\n让火水射程重叠，守卫拦住压力最大的通道。\n倒地队员会在波次结束后半血归队。" % [sim.kills, sim.wave]
				modal_action.text = "重新布防   →   [Enter]"
		if not was_visible or get_viewport().gui_get_focus_owner() != modal_action:
			modal_action.grab_focus()

func refresh_supports(sim) -> void:
	support_panel.visible = sim.v2_mode and not sim.supports.is_empty() and sim.state in ["running", "between", "paused"]
	for item in support_labels:
		item.text = ""
	if not support_panel.visible:
		return
	var names := {
		"support_barrage": ["赤月炮击", Color("#ff776d")],
		"support_crossfire": ["交叉火力", Color("#ffc06e")],
		"support_heal": ["潮汐急救", Color("#71e5d3")],
		"support_finale": ["终幕齐射", Color("#d89cff")],
	}
	var row := 0
	for key: String in sim.supports:
		if row >= support_labels.size():
			break
		var support: Dictionary = sim.supports[key]
		var info: Array = names.get(key, [key, WHITE])
		support_labels[row].text = "◆ %s   ×%d   %.1fs" % [info[0], int(support.stacks), maxf(0.0, float(support.timer))]
		support_labels[row].add_theme_color_override("font_color", info[1])
		row += 1

func refresh_buffs(sim) -> void:
	buff_panel.visible = sim.v2_mode and not sim.run_state.buff_levels.is_empty() and sim.state in ["running", "between", "paused"]
	for item in buff_labels:
		item.text = ""
	if not buff_panel.visible:
		return
	var names: Dictionary = {}
	for card: Dictionary in sim.database.cards:
		names[str(card.id)] = str(card.get("name", card.id))
	var ids: Array = sim.run_state.buff_levels.keys()
	ids.reverse()
	for i in mini(buff_labels.size(), ids.size()):
		var id: String = str(ids[i])
		buff_labels[i].text = "◆ %s   Lv.%d" % [names.get(id, id), int(sim.run_state.buff_levels[id])]
	if ids.size() > buff_labels.size():
		buff_labels[-1].text = "◆ 另有 %d 项强化正在生效" % (ids.size() - buff_labels.size() + 1)

func set_skill_aiming(enabled: bool) -> void:
	skill_aiming = enabled
	signature = ""

func refresh_skill(sim) -> void:
	skill_button.visible = sim.v2_mode and sim.state in ["running", "between", "paused"]
	if not skill_button.visible:
		return
	var element: String = sim.traveler_skill_element()
	var glyph: String = str({"none": "剑", "anemo": "风", "electro": "雷", "pyro": "火", "hydro": "水", "geo": "岩", "cryo": "冰"}.get(element, "技"))
	var color := element_color(element)
	var growth := ""
	if sim.skill_power_bonus > 0.0 or sim.skill_area_bonus > 0.0:
		growth = "  威力+%d%% 范围+%d%%" % [roundi(sim.skill_power_bonus * 100.0), roundi(sim.skill_area_bonus * 100.0)]
	skill_button.add_theme_color_override("font_color", color)
	if skill_aiming:
		skill_button.text = "%s  %s%s  ·  点击战场释放" % [glyph, sim.traveler_skill_name(), growth]
	elif sim.traveler_skill_cooldown > 0.0:
		skill_button.text = "%s  %s%s  ·  %.1fs" % [glyph, sim.traveler_skill_name(), growth, sim.traveler_skill_cooldown]
	else:
		skill_button.text = "%s  %s%s  ·  [Q]" % [glyph, sim.traveler_skill_name(), growth]
	skill_button.disabled = sim.state != "running" or sim.traveler_skill_cooldown > 0.0

func element_color(element: String) -> Color:
	return {"anemo": Color("#63e6c0"), "electro": Color("#bf83ff"), "pyro": Color("#ff745c"), "hydro": Color("#5ab8ff"), "geo": Color("#e8b94d"), "cryo": Color("#9de7f2")}.get(element, WHITE)

func ornament(parent: Node, rect: Rect2) -> NinePatchRect:
	var frame := NinePatchRect.new()
	frame.texture = preload("res://assets/helltaker/ui/button0003.png")
	frame.position = rect.position
	frame.size = rect.size
	frame.patch_margin_left = 115
	frame.patch_margin_right = 115
	frame.patch_margin_top = 36
	frame.patch_margin_bottom = 36
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	return frame

func bind(control: Control, id: String) -> Control:
	control.name = id
	if config != null:
		config.apply_ui(control, id)
	return control
