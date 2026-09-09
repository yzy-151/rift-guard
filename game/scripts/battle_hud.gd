extends CanvasLayer
signal reward_action(index: int)
signal primary_action
signal pause_action
signal restart_action
signal select_action(hero_id: int)
signal mute_action(enabled: bool)
signal reduce_action(enabled: bool)
signal compendium_action
signal squad_action
signal stage_action
signal skill_action
signal main_menu_action

const WHITE = Color("#f3e9df")
const MUTED = Color("#ae969f")
const TEAL = Color("#e3a2a5")
const HT_BUTTON = preload("res://assets/helltaker/ui/button.png")
const HT_BUTTON_HOVER = preload("res://assets/helltaker/ui/button hover.png")
const HT_BUTTON_ACTIVE = preload("res://assets/helltaker/ui/button active.png")
const HT_PANEL = preload("res://assets/helltaker/ui/button on.png")
const HT_HIGHLIGHT = preload("res://assets/helltaker/audio/button_menu_highlight_01.wav")
const HT_CONFIRM = preload("res://assets/helltaker/audio/button_menu_confirm_01.wav")
const HT_BOSS_WARNING = preload("res://assets/helltaker/audio/dialogue_start_epilogue_01.wav")
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
var modal_card: Panel
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
var buff_icons: Array[TextureRect] = []
var skill_button: Button
var skill_icon: TextureRect
var skill_aiming: bool = false
var boss_panel: Panel
var boss_name_label: Label
var boss_hp_bar: ProgressBar
var boss_hp_label: Label
var boss_alert: Label
var boss_warning: AudioStreamPlayer
var pause_details: Panel
var pause_menu_button: Button
var pause_buff_labels: Array[Label] = []
var pause_hero_labels: Array[Label] = []
var hero_hp_bars: Array[ProgressBar] = []
var ui_highlight: AudioStreamPlayer
var ui_confirm: AudioStreamPlayer

func _ready() -> void:
	ui_highlight = AudioStreamPlayer.new()
	ui_highlight.stream = HT_HIGHLIGHT
	ui_highlight.volume_db = -15.0
	ui_confirm = AudioStreamPlayer.new()
	ui_confirm.stream = HT_CONFIRM
	ui_confirm.volume_db = -13.0
	boss_warning = AudioStreamPlayer.new()
	boss_warning.stream = HT_BOSS_WARNING
	boss_warning.volume_db = -9.0
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ui_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	ui_theme.default_font = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
	ui_theme.default_font_size = 13
	root.theme = ui_theme
	add_child(root)
	add_child(ui_highlight)
	add_child(ui_confirm)
	add_child(boss_warning)
	label(root, Vector2(34, 7), Vector2(560, 22), "R I F T   G U A R D     /     边 境 防 线", 13, TEAL)
	bind(label(root, Vector2(32, 27), Vector2(700, 43), "模式一  /  裂隙守望", 32, WHITE), "game_title")
	bind(label(root, Vector2(207, 40), Vector2(500, 24), "城门之下 · 守至黎明", 14, MUTED), "game_subtitle")
	progression_label = label(root, Vector2(620, 47), Vector2(625, 22), "", 12, TEAL)
	progression_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var stage_btn := button(root, Rect2(400, 8, 156, 36), "关卡  [F4]", false)
	bind(stage_btn, "stage_button")
	stage_btn.pressed.connect(func(): stage_action.emit())
	var squad_btn := button(root, Rect2(570, 8, 156, 36), "编队  [F3]", false)
	bind(squad_btn, "squad_button")
	squad_btn.pressed.connect(func(): squad_action.emit())
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
		buff_icons.append(icon(buff_panel, "res://assets/ui/icons/temporary/nieobie/card.svg", Rect2(12, 29 + i * 18, 14, 14), Color("#d6b4f0")))
		buff_labels.append(label(buff_panel, Vector2(32, 28 + i * 18), Vector2(370, 18), "", 10, WHITE))
	buff_panel.hide()
	boss_panel = panel(root, Rect2(475, 106, 400, 72), Color(0.055, 0.025, 0.04, 0.96), Color("#be435c"))
	boss_name_label = label(boss_panel, Vector2(15, 7), Vector2(370, 22), "", 15, Color("#ff9cab"))
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.position = Vector2(18, 34)
	boss_hp_bar.size = Vector2(364, 20)
	boss_hp_bar.show_percentage = false
	var boss_bg := StyleBoxFlat.new()
	boss_bg.bg_color = Color("#26131c")
	boss_bg.border_color = Color("#64303d")
	boss_bg.set_border_width_all(2)
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color("#d94f66")
	boss_fill.border_color = Color("#ff9aa7")
	boss_fill.set_border_width_all(1)
	boss_hp_bar.add_theme_stylebox_override("background", boss_bg)
	boss_hp_bar.add_theme_stylebox_override("fill", boss_fill)
	boss_panel.add_child(boss_hp_bar)
	boss_hp_label = label(boss_panel, Vector2(18, 34), Vector2(364, 20), "", 12, WHITE)
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_panel.hide()
	boss_alert = label(root, Vector2(270, 248), Vector2(740, 96), "", 40, Color("#fff1ed"))
	boss_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_alert.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_alert.add_theme_color_override("font_shadow_color", Color("#9e203c"))
	boss_alert.add_theme_constant_override("shadow_offset_x", 4)
	boss_alert.add_theme_constant_override("shadow_offset_y", 4)
	boss_alert.hide()
	skill_button = button(root, Rect2(900, 540, 348, 62), "旅行者战技  [Q]", true)
	skill_button.add_theme_font_size_override("font_size", 14)
	var skill_icon_back := ColorRect.new()
	skill_icon_back.position = Vector2(12, 10)
	skill_icon_back.size = Vector2(40, 40)
	skill_icon_back.color = Color("#ead9dc")
	skill_icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_button.add_child(skill_icon_back)
	skill_icon = icon(skill_button, "res://assets/ui/icons/temporary/nieobie/skill.svg", Rect2(16, 14, 32, 32), WHITE)
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
		var portrait := panel(hero_btn, Rect2(10, 9, 48, 48), Color("#33232d"), TEAL)
		var portrait_back := ColorRect.new()
		portrait_back.position = Vector2(5, 5)
		portrait_back.size = Vector2(38, 38)
		portrait_back.color = Color("#ead9dc")
		portrait_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(portrait_back)
		icon(portrait, "res://assets/ui/icons/temporary/nieobie/character.svg", Rect2(9, 9, 30, 30), WHITE)
		hero_name_labels.append(label(hero_btn, Vector2(66, 5), Vector2(192, 23), "%d  未部署" % [i + 1], 14, WHITE))
		var hp_bar := ProgressBar.new()
		hp_bar.position = Vector2(66, 31)
		hp_bar.size = Vector2(190, 12)
		hp_bar.show_percentage = false
		var hp_bg := StyleBoxFlat.new()
		hp_bg.bg_color = Color("#251923")
		var hp_fill := StyleBoxFlat.new()
		hp_fill.bg_color = Color("#be5364")
		hp_bar.add_theme_stylebox_override("background", hp_bg)
		hp_bar.add_theme_stylebox_override("fill", hp_fill)
		hero_btn.add_child(hp_bar)
		hero_hp_bars.append(hp_bar)
		hero_statuses.append(label(hero_btn, Vector2(66, 43), Vector2(192, 18), "", 11, WHITE))
		var details: String = "阻挡 2 人 · 移动会放行" if i == 0 else ("火系普攻 · 与水触发蒸发" if i == 1 else "水系普攻 · 自动治疗队友")
		hero_details.append(label(hero_btn, Vector2(10, 64), Vector2(250, 18), details, 10, MUTED))
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
	background_buttons = [stage_btn, squad_btn, archive_btn, pause_button, reset_btn, mute_btn, reduce_btn, skill_button]
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
	modal_card = panel(overlay, Rect2(330, 170, 620, 375), Color("#241a26"), Color("#a34c60"))
	bind(ornament(modal_card, Rect2(-20, -25, 660, 420)), "menu_frame")
	panel(modal_card, Rect2(32, 52, 556, 203), Color("#241a26"), Color("#241a26"))
	label(modal_card, Vector2(48, 63), Vector2(472, 22), "RIFT GUARD   /   防线指令", 12, TEAL)
	modal_title = label(modal_card, Vector2(42, 112), Vector2(536, 45), "", 29, WHITE)
	modal_copy = label(modal_card, Vector2(42, 167), Vector2(536, 86), "", 16, Color("#b6c2c8"))
	modal_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_action = button(modal_card, Rect2(42, 281, 536, 47), "", true)
	modal_action.pressed.connect(func(): primary_action.emit())
	pause_details = panel(overlay, Rect2(82, 72, 1116, 576), Color("#171119"), Color("#a34c60"))
	ornament(pause_details, Rect2(-18, -18, 1152, 612))
	var pause_scrim := ColorRect.new()
	pause_scrim.position = Vector2(18, 12)
	pause_scrim.size = Vector2(1080, 546)
	pause_scrim.color = Color(0.035, 0.025, 0.045, 0.94)
	pause_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_details.add_child(pause_scrim)
	var build_column := ColorRect.new()
	build_column.position = Vector2(22, 92)
	build_column.size = Vector2(510, 408)
	build_column.color = Color(0.10, 0.065, 0.11, 0.96)
	build_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_details.add_child(build_column)
	var stats_column := ColorRect.new()
	stats_column.position = Vector2(548, 92)
	stats_column.size = Vector2(526, 408)
	stats_column.color = Color(0.12, 0.055, 0.075, 0.96)
	stats_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_details.add_child(stats_column)
	label(pause_details, Vector2(34, 22), Vector2(600, 20), "T A C T I C A L   R E C O R D   /   战 术 档 案", 11, TEAL)
	label(pause_details, Vector2(34, 50), Vector2(500, 36), "本关构筑与队伍数值", 25, WHITE)
	label(pause_details, Vector2(34, 100), Vector2(500, 22), "已 获 得 强 化", 13, Color("#d6b4f0"))
	for i in 12:
		pause_buff_labels.append(label(pause_details, Vector2(34, 132 + i * 27), Vector2(490, 24), "", 12, WHITE))
	label(pause_details, Vector2(560, 100), Vector2(500, 22), "当 前 角 色 数 值", 13, Color("#ffb0b7"))
	for i in 3:
		pause_hero_labels.append(label(pause_details, Vector2(560, 135 + i * 105), Vector2(510, 94), "", 12, WHITE))
	pause_menu_button = button(pause_details, Rect2(34, 468, 490, 48), "返回主菜单", false)
	pause_menu_button.pressed.connect(func(): main_menu_action.emit())
	var pause_continue := button(pause_details, Rect2(560, 468, 510, 48), "继续防守   [空格]", true)
	pause_continue.pressed.connect(func(): primary_action.emit())
	pause_details.hide()
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
	item.add_theme_font_size_override("font_size", 12)
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

func icon(parent: Node, path: String, rect: Rect2, color: Color = Color.WHITE) -> TextureRect:
	var item := TextureRect.new()
	item.texture = load(path)
	item.position = rect.position
	item.size = rect.size
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.modulate = color
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func refresh(sim, selected_id: int) -> void:
	var next_signature: String = str([sim.state, sim.base_hp, sim.base_max_hp, sim.wave, sim.kills, sim.enemies.size(), sim.reactions, sim.kill_streak, ceili(sim.wave_timer), selected_id, sim.team_level, sim.team_xp, sim.run_seed, sim.rewards.history, sim.supports, ceili(sim.traveler_skill_cooldown * 10.0), sim.geo_constructs.size(), skill_aiming])
	for enemy: Dictionary in sim.enemies:
		if str(enemy.get("kind", "")).begins_with("boss_"):
			next_signature += str([ceili(float(enemy.hp)), ceili(float(enemy.get("shield", 0.0)))])
	if sim.v2_mode:
		var stage_clock := floori(sim.elapsed) if sim.endless_mode else floori(sim.stage_runtime.remaining_seconds())
		next_signature += str([sim.run_state.traveler_element, sim.run_state.traveler_secondary_element, sim.run_state.luck, sim.run_state.pending_level_ups, stage_clock])
	for hero in sim.heroes:
		next_signature += str([ceili(hero.hp), hero.moving, hero.blocked])
	if next_signature == signature:
		return
	signature = next_signature
	if sim.endless_mode:
		var traveler: Dictionary = sim.heroes[0] if not sim.heroes.is_empty() else {}
		base_label.text = "◆ 旅行者 HP %d/%d   ◇ 护盾 %03d" % [ceili(float(traveler.get("hp", 0.0))), ceili(float(traveler.get("max_hp", 0.0))), ceili(sim.crystal_shield)]
	else:
		base_label.text = "◆ 基地 %03d/%03d   ◇ 结晶盾 %03d" % [sim.base_hp, sim.base_max_hp, ceili(sim.crystal_shield)] if sim.v2_mode else "◆  基地完整度    %03d / %03d" % [sim.base_hp, sim.base_max_hp]
	if sim.v2_mode:
		var next_xp: int = sim.endless_next_threshold() if sim.endless_mode else sim.crystal.next_threshold(sim.run_state)
		var xp_text: String = "MAX" if next_xp < 0 else "%d / %d" % [sim.run_state.crystal_xp, next_xp]
		var seconds: int = floori(sim.elapsed) if sim.endless_mode else ceili(sim.stage_runtime.remaining_seconds())
		var queued := "  ·  待选 ×%d" % sim.run_state.pending_level_ups if sim.run_state.pending_level_ups > 0 and sim.state != "reward" else ""
		if sim.endless_mode:
			progression_label.text = "旅行者 Lv.%d  ·  EXP %s%s  ·  %s元素  ·  幸运 %.2f  ·  生存 %02d:%02d" % [sim.run_state.crystal_level, xp_text, queued, sim.traveler_element_display(), sim.run_state.luck, seconds / 60, seconds % 60]
			wave_label.text = "威胁等级   %02d" % maxi(1, floori(sim.elapsed / 45.0) + 1)
		else:
			progression_label.text = "水晶 Lv.%d  ·  EXP %s%s  ·  %s元素  ·  幸运 %.2f  ·  %02d:%02d" % [sim.run_state.crystal_level, xp_text, queued, sim.traveler_element_display(), sim.run_state.luck, seconds / 60, seconds % 60]
			wave_label.text = "波次   %02d / %02d" % [sim.wave, sim.stage_runtime.definition.get("waves", []).size()]
	else:
		progression_label.text = "小队 Lv.%d / 5    ·    经验 %d    ·    强化 %d    ·    种子 %d" % [sim.team_level, sim.team_xp, sim.rewards.history.size(), sim.run_seed]
		wave_label.text = "节点   %02d / 05" % sim.wave
	count_label.text = ("击退 %02d  ·  在场 %02d  ·  连杀 %02d" % [sim.kills, sim.enemies.size(), sim.kill_streak]) if sim.v2_mode else ("击退 %02d  ·  在场 %02d  ·  蒸发 %02d" % [sim.kills, sim.enemies.size(), sim.reactions])
	status_label.text = "无尽生存 · 右键移动 · 同行者自动跟随" if sim.endless_mode else "按 1/2/3 或点击角色卡选择"
	refresh_skill(sim)
	refresh_supports(sim)
	refresh_buffs(sim)
	refresh_boss(sim)
	if selected_id >= 0 and selected_id < sim.heroes.size():
		var hero: Dictionary = sim.heroes[selected_id]
		status_label.text = hero.name + (" · 已倒地，波末恢复" if hero.hp <= 0 else (" · 移动中，暂停攻击" if hero.moving else " · 自动攻击 / 右键走位"))
	if sim.state == "stage_exit":
		status_label.text = "通关区域 · 右键移动旅行者前往迎接新角色"
	if sim.state == "between":
		status_label.text = "队伍休整 · %d 秒后继续" % ceili(sim.wave_timer)
	pause_button.disabled = sim.state in ["ready", "won", "lost", "reward", "stage_exit"]
	pause_button.text = "继续  [空格]" if sim.state == "paused" else "暂停  [空格]"
	for i in hero_buttons.size():
		hero_buttons[i].visible = i < sim.heroes.size()
	for i in sim.heroes.size():
		var hero: Dictionary = sim.heroes[i]
		hero_hp_bars[i].max_value = maxf(1.0, float(hero.max_hp))
		hero_hp_bars[i].value = maxf(0.0, float(hero.hp))
		hero_name_labels[i].text = "%d  %s / %s" % [i + 1, hero.name, hero.role]
		var hero_color: Color = element_color(str(hero.get("element", ""))) if hero.get("character_id", "") == "traveler" and hero.get("element", "") != "" else Color(hero.color)
		hero_name_labels[i].add_theme_color_override("font_color", hero_color)
		hero_buttons[i].modulate = Color.WHITE if i == selected_id else Color("#91a0a8")
		var status: String = "倒地 · 本波无法行动" if hero.hp <= 0 else ("移动中" if hero.moving else ("阻挡 %d/%d" % [hero.blocked, hero.block] if i == 0 else "就绪"))
		var mechanics := "弹道%d · 穿透%d · 连锁%d" % [int(hero.get("projectile_count", 1)), int(hero.get("pierce", 0)), int(hero.get("chain_count", 0))]
		hero_details[i].text = "%s元素 · ATK %.0f · %.1f/s · %s" % [sim.element_name(str(hero.get("element", "none"))), hero.damage, hero.rate, mechanics]
		hero_statuses[i].text = "%d/%d · %s" % [ceili(hero.hp), ceili(hero.max_hp), status]
	var was_visible: bool = overlay.visible
	overlay.visible = sim.state in ["ready", "paused", "won", "lost"]
	for control in background_buttons:
		control.focus_mode = Control.FOCUS_NONE if overlay.visible or sim.state == "reward" else Control.FOCUS_ALL
	if sim.state == "reward":
		reward_panel.display(sim)
	else:
		reward_panel.hide()
	if overlay.visible:
		pause_details.visible = sim.state == "paused"
		modal_card.visible = sim.state != "paused"
		if sim.state == "paused":
			refresh_pause_details(sim)
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
				modal_title.text = "活下去" if sim.endless_mode else "守住最后一道防线"
				if sim.endless_mode:
					modal_copy.text = "猩红荒原 · 四屏开放战场\n敌人从四周追击旅行者，击杀升级并无限构筑。\n右键移动，同行者会跟随并在移动中攻击。"
				else:
					modal_copy.text = "%s  ·  %d分%02d秒\n击杀敌人升级水晶，三选一强化可无限叠加。\n选定元素后按 Q 释放战技，守住三条路线。" % [stage.get("name", "裂隙防线"), duration / 60, duration % 60] if sim.v2_mode else "1 守卫阻挡 · 2 火系输出 · 3 水系治疗\n火水交替命中，触发蒸发增伤。\n守住 5 个节点，节点之间三选一强化。"
				modal_action.text = "进入荒原   →   [Enter]" if sim.endless_mode else "开始防守   →   [Enter]"
			"paused":
				modal_title.text = "战术暂停"
				modal_copy.text = "战场、弹体和攻击冷却已冻结。\n准备好后，继续守住你的防线。"
				modal_action.text = "继续防守   →   [空格]"
			"won":
				var base_percent := roundi(float(sim.base_hp) / maxf(1.0, float(sim.base_max_hp)) * 100.0)
				var grade := result_grade(base_percent, sim.best_streak)
				var unlock_copy := "下一作战区域已解锁。" if sim.v2_mode and sim.current_stage_id != "stage_03" else "本章作战区域已全部完成。"
				modal_title.text = "防线守住了"
				modal_copy.text = "评级 %s  ·  击退 %d  ·  基地 %d%%  ·  最高连杀 %d\n元素反应 %d 次  ·  %s\n本关构筑将在进入下一关时重置，可按 F4 选择关卡。" % [grade, sim.kills, base_percent, sim.best_streak, sim.reactions, unlock_copy]
				modal_action.text = "再守一次   →   [Enter]"
			"lost":
				modal_title.text = "核心已经失守"
				modal_copy.text = "击退 %d 名敌人  ·  坚持到第 %d 波\n让火水射程重叠，守卫拦住压力最大的通道。\n倒地队员会在波次结束后半血归队。" % [sim.kills, sim.wave]
				modal_action.text = "重新布防   →   [Enter]"
		if not was_visible or get_viewport().gui_get_focus_owner() != modal_action:
			modal_action.grab_focus()

func refresh_boss(sim) -> void:
	var active: Dictionary = {}
	for enemy: Dictionary in sim.enemies:
		if str(enemy.get("kind", "")).begins_with("boss_") and float(enemy.get("hp", 0.0)) > 0.0:
			active = enemy
			break
	boss_panel.visible = not active.is_empty() and sim.state in ["running", "paused"]
	if active.is_empty():
		return
	var shield: float = float(active.get("shield", 0.0))
	var hp: float = maxf(0.0, float(active.hp))
	boss_name_label.text = "◆  B O S S   /   %s   PHASE %s  ◆" % [str(active.get("name", "裂隙首领")), ["I", "II", "III"][clampi(int(active.get("boss_phase", 1)) - 1, 0, 2)]]
	boss_hp_bar.max_value = maxf(1.0, float(active.max_hp))
	boss_hp_bar.value = hp
	boss_hp_label.text = "%d / %d%s" % [ceili(hp), ceili(float(active.max_hp)), "   ◇ 护盾 %d" % ceili(shield) if shield > 0.0 else ""]

func announce_boss(name: String) -> void:
	if boss_warning != null and not muted:
		boss_warning.stop()
		boss_warning.play()
	boss_alert.text = "W A R N I N G\n%s  降 临" % name
	boss_alert.position = Vector2(270, 228)
	boss_alert.modulate = Color(1, 1, 1, 0)
	boss_alert.scale = Vector2(1.16, 1.16)
	boss_alert.pivot_offset = boss_alert.size * 0.5
	boss_alert.show()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(boss_alert, "modulate:a", 1.0, 0.16)
	tween.tween_property(boss_alert, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(0.72).timeout
	var out := create_tween()
	out.set_parallel(true)
	out.tween_property(boss_alert, "modulate:a", 0.0, 0.28)
	out.tween_property(boss_alert, "position:y", 210.0, 0.28)
	await out.finished
	boss_alert.hide()

func announce_boss_phase(name: String, phase: int) -> void:
	if boss_warning != null and not muted:
		boss_warning.stop()
		boss_warning.pitch_scale = 1.08 if phase == 2 else 0.88
		boss_warning.play()
	boss_alert.text = "%s\n%s  狂 暴 阶 段" % ["P H A S E   II" if phase == 2 else "F I N A L   P H A S E", name]
	boss_alert.position = Vector2(270, 228)
	boss_alert.modulate = Color(1, 1, 1, 0)
	boss_alert.scale = Vector2(1.20, 1.20)
	boss_alert.pivot_offset = boss_alert.size * 0.5
	boss_alert.show()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(boss_alert, "modulate:a", 1.0, 0.14)
	tween.tween_property(boss_alert, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(0.72).timeout
	var out := create_tween()
	out.tween_property(boss_alert, "modulate:a", 0.0, 0.26)
	await out.finished
	boss_alert.hide()
	if boss_warning != null:
		boss_warning.pitch_scale = 1.0

func result_grade(base_hp: int, streak: int) -> String:
	if base_hp >= 85 and streak >= 20:
		return "S"
	if base_hp >= 60 and streak >= 10:
		return "A"
	if base_hp >= 30:
		return "B"
	return "C"

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

func refresh_pause_details(sim) -> void:
	for item in pause_buff_labels:
		item.text = ""
	var card_names: Dictionary = {}
	if sim.database != null:
		for card: Dictionary in sim.database.cards:
			card_names[str(card.id)] = str(card.name)
	var ids: Array = sim.run_state.buff_levels.keys()
	ids.sort()
	for i in mini(ids.size(), pause_buff_labels.size()):
		var id := str(ids[i])
		pause_buff_labels[i].text = "◆  %s     Lv.%d" % [card_names.get(id, id), int(sim.run_state.buff_levels[id])]
	if ids.is_empty():
		pause_buff_labels[0].text = "尚未获得强化卡牌"
	for i in pause_hero_labels.size():
		pause_hero_labels[i].text = ""
		if i >= sim.heroes.size():
			continue
		var hero: Dictionary = sim.heroes[i]
		var element_text: String = str(sim.element_name(str(hero.get("element", "none"))))
		if not str(hero.get("secondary_element", "")).is_empty():
			element_text += " + " + sim.element_name(str(hero.secondary_element))
		pause_hero_labels[i].text = "%d  %s  /  %s  /  %s\nHP %d/%d    ATK %.0f    ASPD %.2f/s\n射程 %.0f    护甲 %.0f    移速 %.0f    弹道 %d" % [i + 1, hero.name, hero.role, element_text, ceili(hero.hp), ceili(hero.max_hp), hero.damage, hero.rate, hero.range, hero.armor, hero.speed, int(hero.get("projectile_count", 1))]

func refresh_buffs(sim) -> void:
	buff_panel.visible = sim.v2_mode and not sim.run_state.buff_levels.is_empty() and sim.state in ["running", "between", "paused"]
	for i in buff_labels.size():
		buff_labels[i].text = ""
		buff_icons[i].hide()
	if not buff_panel.visible:
		return
	var names: Dictionary = {}
	for card: Dictionary in sim.database.cards:
		names[str(card.id)] = str(card.get("name", card.id))
	var ids: Array = sim.run_state.buff_levels.keys()
	ids.reverse()
	for i in mini(buff_labels.size(), ids.size()):
		var id: String = str(ids[i])
		buff_icons[i].show()
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
	var icon_name: String = {"none": "attack", "anemo": "anemo", "electro": "electro", "pyro": "pyro", "hydro": "hydro", "geo": "geo", "cryo": "cryo"}.get(element, "skill")
	skill_icon.texture = load("res://assets/ui/icons/temporary/nieobie/%s.svg" % icon_name)
	skill_icon.modulate = color
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
