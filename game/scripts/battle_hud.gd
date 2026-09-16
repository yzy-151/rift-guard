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
signal ultimate_action
signal deploy_drag_action(hero_id: int, pressed: bool, screen_pos: Vector2)
signal recall_action(hero_id: int)
signal main_menu_action
signal formation_action(mode: String)
signal settings_action
signal map_action

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
const TRAVELER_PORTRAIT = preload("res://assets/characters/traveler_v18/idle.png")
const UNIT_ATLAS = preload("res://assets/tiny-dungeon.png")
const HUD_HERO_GRAY = preload("res://assets/ui/rift_v2/components/hud_hero_gray.png")
const HUD_HERO_RED = preload("res://assets/ui/rift_v2/components/hud_hero_red.png")
const HUD_SKILL_GRAY = preload("res://assets/ui/rift_v2/components/hud_skill_gray.png")
const HUD_SKILL_RED = preload("res://assets/ui/rift_v2/components/hud_skill_red.png")
const HUD_ULTIMATE_GRAY = preload("res://assets/ui/rift_v2/components/hud_ultimate_gray.png")
const HUD_ULTIMATE_RED = preload("res://assets/ui/rift_v2/components/hud_ultimate_red.png")
const ICON_SLASH = preload("res://assets/vfx/third_party/kenney_particle/slash_01.png")
const ICON_TRACE = preload("res://assets/vfx/third_party/kenney_particle/trace_05.png")
const ICON_SPARK = preload("res://assets/vfx/third_party/kenney_particle/spark_05.png")
const ICON_FIRE = preload("res://assets/vfx/third_party/kenney_particle/fire_01.png")
const ICON_CIRCLE = preload("res://assets/vfx/third_party/kenney_particle/circle_05.png")
const ICON_MAGIC = preload("res://assets/vfx/third_party/kenney_particle/magic_03.png")
const ICON_FLARE = preload("res://assets/vfx/third_party/kenney_particle/flare_01.png")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")
var config
var reward_panel
var progression_label: Label
var hero_details: Array[Label] = []
var base_label: Label
var wave_label: Label
var count_label: Label
var status_label: Label
var arena_event_name := ""
var arena_event_until_ms := 0
var pause_button: Button
var hero_buttons: Array[Button] = []
var hero_card_frames: Array[NinePatchRect] = []
var hero_name_labels: Array[Label] = []
var hero_element_labels: Array[Label] = []
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
var right_rail_shell: Panel
var support_panel: Panel
var command_rail: Panel
var action_rail: Panel
var support_labels: Array[Label] = []
var buff_panel: Panel
var buff_labels: Array[Label] = []
var buff_icons: Array[TextureRect] = []
var skill_button: Button
var skill_icon: TextureRect
var skill_frame: TextureRect
var skill_cooldown_overlay: ColorRect
var skill_cd_label: Label
var skill_name_label: Label
var skill_key_label: Label
var ultimate_button: Button
var ultimate_icon: TextureRect
var ultimate_frame: TextureRect
var ultimate_cooldown_overlay: ColorRect
var ultimate_cd_label: Label
var ultimate_name_label: Label
var ultimate_key_label: Label
var ability_hint_label: Label
var preview_hint_label: Label
var hero_energy_bars: Array[ProgressBar] = []
var hero_portraits: Array[TextureRect] = []
var skill_aiming: bool = false
var ultimate_aiming: bool = false
var boss_panel: Panel
var boss_name_label: Label
var boss_hp_bar: ProgressBar
var boss_hp_label: Label
var boss_alert: Label
var boss_warning: AudioStreamPlayer
var wave_timeline_panel: Panel
var wave_timeline_labels: Array[Label] = []
var formation_buttons: Dictionary = {}
var pause_details: Panel
var pause_menu_button: Button
var pause_status_label: Label
var pause_settings_button: Button
var pause_restart_button: Button
var pause_squad_button: Button
var pause_stage_button: Button
var pause_map_button: Button
var pause_buff_labels: Array[Label] = []
var pause_hero_labels: Array[Label] = []
var hero_hp_bars: Array[ProgressBar] = []
var ui_highlight: AudioStreamPlayer
var ui_confirm: AudioStreamPlayer

func _ready() -> void:
	ui_highlight = AudioStreamPlayer.new()
	ui_highlight.stream = HT_HIGHLIGHT
	ui_highlight.bus = "SFX"
	ui_highlight.volume_db = -15.0
	ui_confirm = AudioStreamPlayer.new()
	ui_confirm.stream = HT_CONFIRM
	ui_confirm.bus = "SFX"
	ui_confirm.volume_db = -13.0
	boss_warning = AudioStreamPlayer.new()
	boss_warning.stream = HT_BOSS_WARNING
	boss_warning.bus = "SFX"
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
	panel(root, UI_LAYOUT.battle_title_rect, Color(0.045, 0.025, 0.045, 0.86), Color("#a34c60"))
	label(root, Vector2(28, 8), Vector2(300, 16), "R I F T   G U A R D     /     边 境 防 线", 13, TEAL)
	bind(label(root, Vector2(26, 24), Vector2(300, 30), "模式一  /  裂隙守望", 24, WHITE), "game_title")
	bind(label(root, Vector2(178, 29), Vector2(154, 18), "城门之下 · 守至黎明", 11, MUTED), "game_subtitle")
	var compact_status := panel(root, UI_LAYOUT.battle_status_rect, Color(0.035, 0.018, 0.032, 0.94), Color("#713746"))
	progression_label = label(root, Vector2(366, 9), Vector2(382, 17), "", 10, TEAL)
	progression_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	progression_label.clip_text = true
	base_label = label(root, Vector2(366, 29), Vector2(208, 20), "", 11, WHITE)
	base_label.clip_text = true
	wave_label = label(root, Vector2(578, 29), Vector2(80, 20), "", 10, TEAL)
	wave_label.clip_text = true
	count_label = label(root, Vector2(660, 29), Vector2(104, 20), "", 9, MUTED)
	count_label.clip_text = true
	status_label = label(root, Vector2(24, 59), Vector2(996, 18), "", 10, Color("#d9afc9"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var archive_btn := button(root, UI_LAYOUT.battle_archive_rect, "图鉴  [F2]", false)
	archive_btn.pressed.connect(func(): compendium_action.emit())
	pause_button = button(root, UI_LAYOUT.battle_pause_rect, "暂停  [空格]", false)
	bind(pause_button, "pause_button")
	pause_button.position = UI_LAYOUT.battle_pause_rect.position
	pause_button.size = UI_LAYOUT.battle_pause_rect.size
	pause_button.pressed.connect(func(): pause_action.emit())
	right_rail_shell = panel(root, UI_LAYOUT.battle_right_shell_rect, Color(0.018, 0.010, 0.020, 0.96), Color("#8d3f52"))
	var right_rail_mark := label(right_rail_shell, Vector2(10, 574), Vector2(212, 18), "R I F T   C O M M A N D", 8, Color("#794452"))
	right_rail_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_rail_mark.hide()
	support_panel = panel(root, Rect2(1032, 646, 222, 48), Color(0.07, 0.045, 0.075, 0.92), Color("#864858"))
	label(support_panel, Vector2(10, 5), Vector2(204, 18), "场 外 支 援  /  SUPPORT", 11, TEAL)
	for i in 2:
		support_labels.append(label(support_panel, Vector2(10, 24 + i * 13), Vector2(202, 13), "", 10, WHITE))
	support_panel.hide()
	buff_panel = panel(root, UI_LAYOUT.battle_buff_rect, Color(0.07, 0.045, 0.075, 0.92), Color("#65506f"))
	label(buff_panel, Vector2(10, 5), Vector2(204, 18), "本 局 强 化  /  BUILD", 11, Color("#d6b4f0"))
	for i in 2:
		buff_icons.append(icon(buff_panel, "res://assets/ui/icons/temporary/nieobie/card.svg", Rect2(10, 25 + i * 13, 11, 11), Color("#d6b4f0")))
		buff_labels.append(label(buff_panel, Vector2(25, 23 + i * 13), Vector2(187, 14), "", 9, WHITE))
	buff_panel.hide()
	var boss_panel_rect: Rect2 = UI_LAYOUT.battle_boss_panel_rect
	boss_panel = panel(root, boss_panel_rect, Color(0.035, 0.018, 0.03, 0.93), Color("#a8334d"))
	var boss_name_rect: Rect2 = UI_LAYOUT.battle_boss_name_rect
	boss_name_label = label(boss_panel, boss_name_rect.position, boss_name_rect.size, "", 12, Color("#ff9cab"))
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_bar = ProgressBar.new()
	var boss_bar_rect: Rect2 = UI_LAYOUT.battle_boss_bar_rect
	boss_hp_bar.position = boss_bar_rect.position
	boss_hp_bar.size = boss_bar_rect.size
	boss_hp_bar.show_percentage = false
	boss_hp_bar.add_theme_font_size_override("font_size", 1)
	boss_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	boss_hp_bar.position = boss_bar_rect.position
	boss_hp_bar.size = boss_bar_rect.size
	var boss_value_rect: Rect2 = UI_LAYOUT.battle_boss_value_rect
	boss_hp_label = label(boss_panel, boss_value_rect.position, boss_value_rect.size, "", 10, WHITE)
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_panel.hide()
	wave_timeline_panel = panel(root, UI_LAYOUT.battle_timeline_rect, Color(0.055, 0.035, 0.065, 0.94), Color("#73556f"))
	label(wave_timeline_panel, Vector2(10, 2), Vector2(150, 14), "NEXT / 敌情", 8, Color("#d9afc9"))
	for i in 3:
		var timeline_item := label(wave_timeline_panel, Vector2(164 + i * 280, 2), Vector2(272, 33), "", 8, WHITE)
		timeline_item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		wave_timeline_labels.append(timeline_item)
	wave_timeline_panel.hide()
	boss_alert = label(root, Vector2(270, 248), Vector2(740, 96), "", 40, Color("#fff1ed"))
	boss_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_alert.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_alert.add_theme_color_override("font_shadow_color", Color("#9e203c"))
	boss_alert.add_theme_constant_override("shadow_offset_x", 4)
	boss_alert.add_theme_constant_override("shadow_offset_y", 4)
	boss_alert.hide()
	command_rail = panel(root, UI_LAYOUT.battle_party_rect, Color(0.045, 0.022, 0.038, 0.88), Color("#b95868"))
	bind(command_rail, "command_rail")
	label(command_rail, Vector2(10, 8), Vector2(204, 18), "P A R T Y  /  出 战 队 伍", 10, TEAL)
	label(command_rail, Vector2(10, 25), Vector2(204, 15), "点击切换 · WASD / 右键移动", 8, MUTED)
	action_rail = panel(root, UI_LAYOUT.battle_action_rect, Color(0.035, 0.018, 0.032, 0.90), Color("#73404f"))
	label(action_rail, Vector2(10, 7), Vector2(204, 16), "C O M B A T   /   战 斗 指 令", 9, Color("#d7aab0"))
	skill_button = button(root, UI_LAYOUT.battle_skill_rect, "", true)
	var ability_empty := StyleBoxEmpty.new()
	for ability_state in ["normal", "hover", "pressed", "focus", "disabled"]:
		skill_button.add_theme_stylebox_override(ability_state, ability_empty)
	skill_button.add_theme_font_size_override("font_size", 10)
	skill_frame = TextureRect.new()
	skill_frame.texture = UI_SKIN.skill_frame_red
	skill_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skill_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skill_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_button.add_child(skill_frame)
	skill_icon = icon(skill_button, "res://assets/vfx/third_party/kenney_particle/slash_01.png", Rect2(25, 22, 46, 46), WHITE)
	skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_cooldown_overlay = ColorRect.new()
	skill_cooldown_overlay.position = Vector2(5, 5)
	skill_cooldown_overlay.size = Vector2(86, 86)
	skill_cooldown_overlay.color = Color(0.015, 0.006, 0.018, 0.72)
	skill_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_button.add_child(skill_cooldown_overlay)
	skill_name_label = label(skill_button, Vector2(8, 5), Vector2(80, 17), "", 9, WHITE)
	skill_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_name_label.clip_text = true
	var skill_key_plate := ColorRect.new()
	skill_key_plate.position = Vector2(11, 68)
	skill_key_plate.size = Vector2(74, 20)
	skill_key_plate.color = Color(0.025, 0.010, 0.024, 0.86)
	skill_key_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_button.add_child(skill_key_plate)
	skill_cd_label = label(skill_button, Vector2(4, 31), Vector2(88, 34), "READY", 22, Color("#fff4ec"))
	skill_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skill_key_label = label(skill_button, Vector2(8, 70), Vector2(80, 18), "Q · 战技", 11, Color("#ffd9de"))
	skill_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_cd_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	skill_cd_label.add_theme_constant_override("shadow_offset_y", 2)
	skill_button.pressed.connect(func(): skill_action.emit())
	ultimate_button = button(root, UI_LAYOUT.battle_ultimate_rect, "", true)
	for ability_state in ["normal", "hover", "pressed", "focus", "disabled"]:
		ultimate_button.add_theme_stylebox_override(ability_state, ability_empty)
	ultimate_button.add_theme_font_size_override("font_size", 10)
	ultimate_frame = TextureRect.new()
	ultimate_frame.texture = UI_SKIN.ultimate_frame_red
	ultimate_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ultimate_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ultimate_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ultimate_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_button.add_child(ultimate_frame)
	ultimate_icon = icon(ultimate_button, "res://assets/vfx/third_party/kenney_particle/magic_03.png", Rect2(25, 22, 46, 46), WHITE)
	ultimate_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_cooldown_overlay = ColorRect.new()
	ultimate_cooldown_overlay.position = Vector2(5, 5)
	ultimate_cooldown_overlay.size = Vector2(86, 86)
	ultimate_cooldown_overlay.color = Color(0.015, 0.006, 0.018, 0.72)
	ultimate_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_button.add_child(ultimate_cooldown_overlay)
	ultimate_name_label = label(ultimate_button, Vector2(8, 5), Vector2(80, 17), "", 9, WHITE)
	ultimate_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_name_label.clip_text = true
	var ultimate_key_plate := ColorRect.new()
	ultimate_key_plate.position = Vector2(11, 68)
	ultimate_key_plate.size = Vector2(74, 20)
	ultimate_key_plate.color = Color(0.025, 0.010, 0.024, 0.86)
	ultimate_key_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_button.add_child(ultimate_key_plate)
	ultimate_cd_label = label(ultimate_button, Vector2(4, 31), Vector2(88, 34), "READY", 22, Color("#ffe7a5"))
	ultimate_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ultimate_key_label = label(ultimate_button, Vector2(8, 70), Vector2(80, 18), "E · 终结技", 11, Color("#fff0ae"))
	ultimate_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_cd_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	ultimate_cd_label.add_theme_constant_override("shadow_offset_y", 2)
	ultimate_button.pressed.connect(func(): ultimate_action.emit())
	var formation_specs := [["squad", "全队 Z"], ["follow", "跟随 X"], ["hold", "坚守 C"]]
	for i in formation_specs.size():
		var mode: String = str(formation_specs[i][0])
		var formation_btn := button(root, Rect2(UI_LAYOUT.battle_formation_rect.position + Vector2(i * 70, 0), Vector2(66, UI_LAYOUT.battle_formation_rect.size.y)), str(formation_specs[i][1]), false)
		formation_btn.add_theme_font_size_override("font_size", 9)
		formation_btn.pressed.connect(func(): formation_action.emit(mode))
		formation_buttons[mode] = formation_btn

	for i in 3:
		var hero_btn := button(root, Rect2(UI_LAYOUT.battle_hero_card_rect.position + UI_LAYOUT.battle_hero_card_gap * i, UI_LAYOUT.battle_hero_card_rect.size), "", true)
		bind(hero_btn, "hero_card_%d" % (i + 1))
		hero_btn.position = UI_LAYOUT.battle_hero_card_rect.position + UI_LAYOUT.battle_hero_card_gap * i
		hero_btn.size = UI_LAYOUT.battle_hero_card_rect.size
		hero_btn.name = "HeroCard%d" % (i + 1)
		var hero_empty := StyleBoxEmpty.new()
		for hero_state in ["normal", "hover", "pressed", "focus", "disabled"]:
			hero_btn.add_theme_stylebox_override(hero_state, hero_empty)
		var hero_frame := NinePatchRect.new()
		hero_frame.texture = UI_SKIN.hero_frame_red if i == 0 else UI_SKIN.hero_frame_gray
		hero_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hero_frame.patch_margin_left = 38
		hero_frame.patch_margin_right = 38
		hero_frame.patch_margin_top = 28
		hero_frame.patch_margin_bottom = 28
		hero_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hero_btn.add_child(hero_frame)
		hero_card_frames.append(hero_frame)
		var trim := Sprite2D.new()
		trim.texture = preload("res://assets/helltaker/ui/W_selection.png")
		trim.position = Vector2(194, 16)
		trim.scale = Vector2(0.075, 0.075)
		hero_btn.add_child(trim)
		hero_btn.pressed.connect(func(): select_action.emit(i))
		hero_btn.gui_input.connect(_hero_card_input.bind(i))
		hero_buttons.append(hero_btn)
		var portrait_frame := panel(hero_btn, Rect2(7, 7, 56, 58), Color("#33232d"), TEAL)
		var portrait_back := ColorRect.new()
		portrait_back.position = Vector2(4, 4)
		portrait_back.size = Vector2(48, 50)
		portrait_back.color = Color("#ead9dc")
		portrait_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_frame.add_child(portrait_back)
		var portrait_image := TextureRect.new()
		portrait_image.position = Vector2(4, 4)
		portrait_image.size = Vector2(48, 50)
		portrait_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_frame.add_child(portrait_image)
		hero_portraits.append(portrait_image)
		hero_name_labels.append(label(hero_btn, Vector2(70, 6), Vector2(88, 18), "%d  未部署" % [i + 1], 12, WHITE))
		var element_badge := label(hero_btn, Vector2(160, 6), Vector2(40, 18), "无", 10, MUTED)
		element_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		element_badge.add_theme_color_override("font_outline_color", Color("#160d14"))
		element_badge.add_theme_constant_override("outline_size", 2)
		hero_element_labels.append(element_badge)
		var hp_bar := ProgressBar.new()
		hp_bar.position = Vector2(70, 29)
		hp_bar.size = UI_LAYOUT.battle_hero_hp_bar_size
		hp_bar.show_percentage = false
		var hp_bg := StyleBoxFlat.new()
		hp_bg.bg_color = Color("#251923")
		var hp_fill := StyleBoxFlat.new()
		hp_fill.bg_color = Color("#be5364")
		hp_bar.add_theme_stylebox_override("background", hp_bg)
		hp_bar.add_theme_stylebox_override("fill", hp_fill)
		hero_btn.add_child(hp_bar)
		hero_hp_bars.append(hp_bar)
		var energy_bar := ProgressBar.new()
		energy_bar.position = Vector2(70, 56)
		energy_bar.size = UI_LAYOUT.battle_hero_energy_bar_size
		energy_bar.show_percentage = false
		var energy_bg := StyleBoxFlat.new()
		energy_bg.bg_color = Color("#251923")
		var energy_fill := StyleBoxFlat.new()
		energy_fill.bg_color = Color("#f2bd5d")
		energy_bar.add_theme_stylebox_override("background", energy_bg)
		energy_bar.add_theme_stylebox_override("fill", energy_fill)
		hero_btn.add_child(energy_bar)
		hero_energy_bars.append(energy_bar)
		hero_statuses.append(label(hero_btn, Vector2(70, 40), Vector2(130, 14), "", 9, WHITE))
		hero_details.append(label(hero_btn, Vector2(70, 62), Vector2(130, 10), "", 8, MUTED))
	ability_hint_label = label(root, UI_LAYOUT.battle_ability_hint_rect.position, UI_LAYOUT.battle_ability_hint_rect.size, "Q 战技 · E 终结技 · 右键取消", 8, TEAL)
	preview_hint_label = label(root, UI_LAYOUT.battle_preview_hint_rect.position, UI_LAYOUT.battle_preview_hint_rect.size, "F6 剧情 / F7 特效预览", 7, MUTED)
	background_buttons = [archive_btn, pause_button, skill_button, ultimate_button]
	background_buttons.append_array(formation_buttons.values())
	background_buttons.append_array(hero_buttons)
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.035, 0.05, 0.76)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var menu_background := TextureRect.new()
	menu_background.texture = UI_SKIN.battle_menu_background
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
	pause_details = panel(overlay, Rect2(55, 28, 1170, 664), Color("#171119"), Color("#a34c60"))
	ornament(pause_details, Rect2(-18, -18, 1206, 700))
	var pause_scrim := ColorRect.new()
	pause_scrim.position = Vector2(18, 12)
	pause_scrim.size = Vector2(1134, 640)
	pause_scrim.color = Color(0.035, 0.025, 0.045, 0.96)
	pause_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_details.add_child(pause_scrim)
	var build_column := ColorRect.new()
	build_column.position = Vector2(22, 112)
	build_column.size = Vector2(520, 380)
	build_column.color = Color(0.10, 0.065, 0.11, 0.96)
	build_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_details.add_child(build_column)
	var stats_column := ColorRect.new()
	stats_column.position = Vector2(558, 112)
	stats_column.size = Vector2(590, 380)
	stats_column.color = Color(0.12, 0.055, 0.075, 0.96)
	stats_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_details.add_child(stats_column)
	label(pause_details, Vector2(34, 20), Vector2(720, 20), "P A U S E   /   战 术 暂 停", 11, TEAL)
	label(pause_details, Vector2(34, 45), Vector2(500, 34), "作战状态与队伍构筑", 25, WHITE)
	pause_status_label = label(pause_details, Vector2(34, 80), Vector2(1090, 24), "", 12, Color("#e8b1b4"))
	label(pause_details, Vector2(34, 120), Vector2(500, 22), "已 获 得 强 化", 13, Color("#d6b4f0"))
	for i in 12:
		pause_buff_labels.append(label(pause_details, Vector2(34, 150 + i * 27), Vector2(496, 24), "", 12, WHITE))
	label(pause_details, Vector2(570, 120), Vector2(550, 22), "当 前 角 色 数 值", 13, Color("#ffb0b7"))
	for i in 3:
		pause_hero_labels.append(label(pause_details, Vector2(570, 151 + i * 108), Vector2(550, 98), "", 12, WHITE))
	pause_settings_button = button(pause_details, Rect2(34, 514, 258, 42), "设置 / 音量   [F10]", false)
	pause_settings_button.pressed.connect(func(): settings_action.emit())
	pause_restart_button = button(pause_details, Rect2(306, 514, 258, 42), "重新开始   [R]", false)
	pause_restart_button.pressed.connect(func(): restart_action.emit())
	pause_squad_button = button(pause_details, Rect2(578, 514, 258, 42), "调整编队   [F3]", false)
	pause_squad_button.pressed.connect(func(): squad_action.emit())
	pause_stage_button = button(pause_details, Rect2(850, 514, 258, 42), "选择关卡   [F4]", false)
	pause_stage_button.pressed.connect(func(): stage_action.emit())
	pause_menu_button = button(pause_details, Rect2(34, 574, 340, 46), "返回主菜单", false)
	pause_menu_button.pressed.connect(func(): main_menu_action.emit())
	pause_map_button = button(pause_details, Rect2(390, 574, 340, 46), "分支路线图   [F5]", false)
	pause_map_button.pressed.connect(func(): map_action.emit())
	var pause_continue := button(pause_details, Rect2(746, 574, 362, 46), "继续防守   [空格]", true)
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

func style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = 3
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 7
	box.corner_radius_top_right = 7
	box.corner_radius_bottom_left = 7
	box.corner_radius_bottom_right = 7
	box.content_margin_left = 10.0
	box.content_margin_top = 7.0
	box.content_margin_right = 10.0
	box.content_margin_bottom = 7.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 3)
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

func ability_style(fill: Color, border: Color, ultimate: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2 if not ultimate else 3)
	var radius: int = 28 if not ultimate else 38
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 52.0
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	box.shadow_size = 8 if ultimate else 5
	box.shadow_offset = Vector2(0, 3)
	return box

func apply_ability_style(item: Button, accent: Color, ultimate: bool) -> void:
	item.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item.add_theme_color_override("font_color", Color("#fff7f1"))
	item.add_theme_color_override("font_hover_color", Color.WHITE)
	item.add_theme_color_override("font_pressed_color", Color.WHITE)
	item.add_theme_stylebox_override("normal", ability_style(Color(0.08, 0.035, 0.06, 0.96), accent.darkened(0.12), ultimate))
	item.add_theme_stylebox_override("hover", ability_style(Color(0.18, 0.055, 0.09, 0.98), accent.lightened(0.18), ultimate))
	item.add_theme_stylebox_override("pressed", ability_style(Color(0.25, 0.045, 0.075, 1.0), Color.WHITE, ultimate))
	item.add_theme_stylebox_override("focus", ability_style(Color(0.16, 0.045, 0.08, 1.0), accent.lightened(0.30), ultimate))
	item.add_theme_stylebox_override("disabled", ability_style(Color(0.045, 0.035, 0.045, 0.84), Color(0.28, 0.23, 0.28, 0.72), ultimate))
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
	item.add_theme_stylebox_override("normal", button_style(UI_SKIN.common_button_normal, Color("#fff0f0") if accent else Color.WHITE))
	item.add_theme_stylebox_override("hover", button_style(UI_SKIN.common_button_hover))
	item.add_theme_stylebox_override("pressed", button_style(UI_SKIN.common_button_pressed))
	item.add_theme_stylebox_override("focus", button_style(UI_SKIN.common_button_hover, Color("#ffdddd")))
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
	var next_signature: String = str([sim.state, sim.base_hp, sim.base_max_hp, sim.wave, sim.kills, sim.enemies.size(), sim.reactions, sim.kill_streak, ceili(sim.wave_timer), selected_id, sim.team_level, sim.team_xp, sim.run_seed, sim.rewards.history, sim.supports, ceili(sim.traveler_skill_cooldown * 10.0), sim.geo_constructs.size(), skill_aiming, ultimate_aiming, sim.formation_mode])
	for enemy: Dictionary in sim.enemies:
		if str(enemy.get("kind", "")).begins_with("boss_"):
			next_signature += str([ceili(float(enemy.hp)), ceili(float(enemy.get("shield", 0.0)))])
	if sim.v2_mode:
		var stage_clock := floori(sim.elapsed) if sim.endless_mode else floori(sim.stage_runtime.remaining_seconds())
		next_signature += str([sim.run_state.traveler_element, sim.run_state.traveler_secondary_element, sim.run_state.luck, sim.run_state.pending_level_ups, sim.run_state.active_resonances, stage_clock, sim.upcoming_waves(3)])
	for hero in sim.heroes:
		next_signature += str([ceili(hero.hp), hero.moving, hero.blocked, hero.get("deployed", true), roundi(float(hero.get("energy", 0.0))), roundi(float(hero.get("skill_cooldown", 0.0)) * 10.0), roundi(float(hero.get("ultimate_cooldown", 0.0)) * 10.0)])
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
			progression_label.text = "旅行者 Lv.%d · EXP %s%s · %s元素 · %02d:%02d" % [sim.run_state.crystal_level, xp_text, queued, sim.traveler_element_display(), seconds / 60, seconds % 60]
			wave_label.text = "威胁等级   %02d" % maxi(1, floori(sim.elapsed / 45.0) + 1)
		else:
			progression_label.text = "水晶 Lv.%d · EXP %s%s · %s元素 · %02d:%02d" % [sim.run_state.crystal_level, xp_text, queued, sim.traveler_element_display(), seconds / 60, seconds % 60]
			wave_label.text = "波次   %02d / %02d" % [sim.wave, sim.stage_runtime.definition.get("waves", []).size()]
	else:
		progression_label.text = "小队 Lv.%d / 5    ·    经验 %d    ·    强化 %d    ·    种子 %d" % [sim.team_level, sim.team_xp, sim.rewards.history.size(), sim.run_seed]
		wave_label.text = "节点   %02d / 05" % sim.wave
	count_label.text = "击退%02d · 敌%02d" % [sim.kills, sim.enemies.size()]
	status_label.text = "无尽生存 · WASD / 右键移动 · 同行者自动跟随" if sim.endless_mode else "按 1/2/3 或点击右侧角色切换"
	if Time.get_ticks_msec() < arena_event_until_ms:
		status_label.text = "场地变化 · " + arena_event_name
	refresh_skill(sim, selected_id)
	refresh_supports(sim)
	refresh_buffs(sim)
	_layout_right_rail(sim)
	refresh_boss(sim)
	refresh_wave_timeline(sim)
	refresh_formations(sim, selected_id)
	if selected_id == -2:
		status_label.text = "全队移动 · 右键指定队形中心"
	if selected_id >= 0 and selected_id < sim.heroes.size():
		var hero: Dictionary = sim.heroes[selected_id]
		status_label.text = hero.name + (" · 已倒地，波末恢复" if hero.hp <= 0 else (" · 移动中，暂停攻击" if hero.moving else " · 自动攻击 / 右键走位"))
	if sim.state == "stage_exit":
		status_label.text = "通关区域 · 右键移动旅行者前往迎接新角色"
	if sim.state == "between":
		status_label.text = "队伍休整 · %d 秒后继续" % ceili(sim.wave_timer)
	var resonance_text: String = resonance_summary(sim)
	if not resonance_text.is_empty():
		status_label.text += " · 共鸣 " + resonance_text
	pause_button.disabled = sim.state in ["ready", "won", "lost", "reward", "stage_exit"]
	pause_button.text = "继续  [空格]" if sim.state == "paused" else "暂停  [空格]"
	for i in hero_buttons.size():
		hero_buttons[i].visible = i < sim.heroes.size()
		hero_buttons[i].disabled = i >= sim.heroes.size()
	for i in sim.heroes.size():
		var hero: Dictionary = sim.heroes[i]
		hero_hp_bars[i].max_value = maxf(1.0, float(hero.max_hp))
		hero_hp_bars[i].value = maxf(0.0, float(hero.hp))
		hero_energy_bars[i].max_value = maxf(1.0, float(hero.get("max_energy", 100.0)))
		hero_energy_bars[i].value = maxf(0.0, float(hero.get("energy", 0.0)))
		hero_portraits[i].texture = portrait_texture(hero, sim)
		hero_name_labels[i].text = "%d  %s" % [i + 1, hero.name]
		hero_element_labels[i].text = sim.element_name(str(hero.get("element", "none")))
		var hero_color: Color = element_color(str(hero.get("element", ""))) if hero.get("character_id", "") == "traveler" and hero.get("element", "") != "" else Color(hero.color)
		hero_name_labels[i].add_theme_color_override("font_color", hero_color)
		hero_element_labels[i].add_theme_color_override("font_color", hero_color)
		var hp_ratio := float(hero.hp) / maxf(1.0, float(hero.max_hp))
		hero_buttons[i].modulate = Color("#ff7888") if hp_ratio <= 0.25 and hero.hp > 0.0 else (Color.WHITE if i == selected_id else Color("#91a0a8"))
		hero_card_frames[i].texture = UI_SKIN.hero_frame_red if i == selected_id or hp_ratio <= 0.25 else UI_SKIN.hero_frame_gray
		var status: String = "倒地" if hero.hp <= 0 else (("同行中" if sim.endless_mode else "待部署 · 拖到战场") if not bool(hero.get("deployed", true)) else ("移动中" if hero.moving else "就绪"))
		hero_details[i].text = "ATK %.0f  ·  %.1f/s" % [hero.damage, hero.rate]
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
	boss_name_label.text = "◆  %s  ·  PHASE %s  ◆" % [str(active.get("name", "裂隙首领")), ["I", "II", "III"][clampi(int(active.get("boss_phase", 1)) - 1, 0, 2)]]
	boss_hp_bar.max_value = maxf(1.0, float(active.max_hp))
	boss_hp_bar.value = hp
	var hp_percent := roundi(hp / maxf(1.0, float(active.max_hp)) * 100.0)
	boss_hp_label.text = "HP %d%%   %d / %d%s" % [hp_percent, ceili(hp), ceili(float(active.max_hp)), "   ◇ %d" % ceili(shield) if shield > 0.0 else ""]

func refresh_wave_timeline(sim) -> void:
	var active_boss := boss_panel.visible
	wave_timeline_panel.visible = sim.v2_mode and not sim.endless_mode and sim.state in ["running", "paused", "between"] and not active_boss
	if not wave_timeline_panel.visible:
		return
	var upcoming: Array[Dictionary] = sim.upcoming_waves(3)
	var route_names := {"upper": "上路", "main": "中路", "lower": "下路", "air": "空路", "zigzag": "折线", "flank": "侧路"}
	for i in wave_timeline_labels.size():
		if i >= upcoming.size():
			wave_timeline_labels[i].text = "—  暂无后续敌情"
			wave_timeline_labels[i].add_theme_color_override("font_color", MUTED)
			continue
		var item: Dictionary = upcoming[i]
		var eta := ceili(float(item.get("eta", 0.0)))
		var prefix := "BOSS" if bool(item.get("boss", false)) else ("%02d:%02d" % [eta / 60, eta % 60])
		wave_timeline_labels[i].text = "%s   %s   %s ×%d" % [prefix, route_names.get(str(item.get("route_id", "main")), str(item.get("route_id", "main"))), str(item.get("enemy_name", "敌军")), int(item.get("count", 1))]
		wave_timeline_labels[i].add_theme_color_override("font_color", Color("#ff8398") if bool(item.get("boss", false)) else WHITE)

func refresh_formations(sim, selected_id: int) -> void:
	for mode: String in formation_buttons:
		var item: Button = formation_buttons[mode]
		item.visible = sim.v2_mode and sim.state in ["running", "between", "paused"]
		item.disabled = sim.state == "paused"
		var active: bool = (mode == "squad" and selected_id == -2) or (mode != "squad" and sim.formation_mode == mode)
		item.modulate = Color("#ffd3d7") if active else Color("#a38f98")

func announce_route_warning(event: Dictionary) -> void:
	if boss_warning != null and not muted:
		boss_warning.stop()
		boss_warning.pitch_scale = 0.82 if bool(event.get("boss", false)) else 1.18
		boss_warning.volume_db = -8.0 if bool(event.get("boss", false)) else -15.0
		boss_warning.play()


func announce_contract(name: String, reward: String) -> void:
	if boss_warning != null and not muted:
		boss_warning.stop()
		boss_warning.pitch_scale = 1.22
		boss_warning.volume_db = -11.0
		boss_warning.play()
	boss_alert.text = "C O N T R A C T   C L E A R
%s  ·  %s" % [name, reward]
	boss_alert.position = Vector2(270, 228)
	boss_alert.modulate = Color(1,1,1,0)
	boss_alert.scale = Vector2(1.12,1.12)
	boss_alert.pivot_offset = boss_alert.size*0.5
	boss_alert.show()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(boss_alert,"modulate:a",1.0,0.14)
	tween.tween_property(boss_alert,"scale",Vector2.ONE,0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(0.82).timeout
	var out := create_tween()
	out.tween_property(boss_alert,"modulate:a",0.0,0.24)
	await out.finished
	boss_alert.hide()


func announce_boss(name: String) -> void:
	if boss_warning != null and not muted:
		boss_warning.stop()
		boss_warning.pitch_scale = 0.82
		boss_warning.volume_db = -8.0
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

func announce_arena_event(kind: String, duration: float) -> void:
	arena_event_name = kind.replace("_", " ").to_upper()
	arena_event_until_ms = Time.get_ticks_msec() + roundi(minf(duration, 6.0) * 1000.0)

func announce_boss_phase(name: String, phase: int) -> void:
	if boss_warning != null and not muted:
		boss_warning.stop()
		boss_warning.pitch_scale = 1.08 if phase == 2 else 0.88
		boss_warning.volume_db = -8.0
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

func resonance_summary(sim) -> String:
	var names: Array[String] = []
	for id: String in sim.run_state.active_resonances:
		var resonance: Dictionary = sim.database.team_resonances.get(id, {})
		if not resonance.is_empty():
			names.append(str(resonance.get("name", id)))
	return " / ".join(names)
func refresh_pause_details(sim) -> void:
	var stage: Dictionary = sim.database.stages.get(sim.current_stage_id, {}) if sim.v2_mode else {}
	var mode_name := "无尽生存" if sim.endless_mode else "裂隙守望"
	var time_value := floori(sim.elapsed) if sim.endless_mode else ceili(sim.stage_runtime.remaining_seconds())
	var time_text := "%02d:%02d" % [time_value / 60, time_value % 60]
	pause_status_label.text = "%s · %s · %s · 击退%d · 敌%d · Lv.%d · 幸运%.2f · 契约 %s · PERF %d%% / 丢弃%d" % [mode_name, str(stage.get("name", sim.current_stage_id)), time_text, sim.kills, sim.enemies.size(), sim.run_state.crystal_level, sim.run_state.luck, sim.contract_status(), roundi(sim.performance_budget.quality_scale*100.0), sim.culled_spawns]
	var active_resonance_text: String = resonance_summary(sim)
	if not active_resonance_text.is_empty():
		pause_status_label.text += " · 共鸣 " + active_resonance_text
	for item in pause_buff_labels:
		item.text = ""
	var card_names: Dictionary = {}
	if sim.database != null:
		for card: Dictionary in sim.database.cards:
			card_names[str(card.id)] = str(card.name)
	var ids: Array = sim.run_state.buff_levels.keys()
	ids.sort()
	var buff_start: int = 0
	if not active_resonance_text.is_empty():
		pause_buff_labels[0].text = "◇  队伍共鸣     " + active_resonance_text
		pause_buff_labels[0].add_theme_color_override("font_color", Color("#f4c873"))
		buff_start = 1
	for i in mini(ids.size(), pause_buff_labels.size() - buff_start):
		var id := str(ids[i])
		pause_buff_labels[i + buff_start].text = "◆  %s     Lv.%d" % [card_names.get(id, id), int(sim.run_state.buff_levels[id])]
		pause_buff_labels[i + buff_start].add_theme_color_override("font_color", WHITE)
	if ids.is_empty() and buff_start == 0:
		pause_buff_labels[0].text = "尚未获得强化卡牌"
	for i in pause_hero_labels.size():
		pause_hero_labels[i].text = ""
		if i >= sim.heroes.size():
			pause_hero_labels[i].text = "%d  未部署角色\nHP --/--    ATK --    ASPD --\n射程 --    护甲 --    移速 --    弹道 --" % [i + 1]
			pause_hero_labels[i].add_theme_color_override("font_color", MUTED)
			continue
		var hero: Dictionary = sim.heroes[i]
		var element_text: String = str(sim.element_name(str(hero.get("element", "none"))))
		if not str(hero.get("secondary_element", "")).is_empty():
			element_text += " + " + sim.element_name(str(hero.secondary_element))
		pause_hero_labels[i].text = "%d  %s  /  %s  /  %s\nHP %d/%d    ATK %.0f    ASPD %.2f/s\n射程 %.0f    护甲 %.0f    移速 %.0f    弹道 %d" % [i + 1, hero.name, hero.role, element_text, ceili(hero.hp), ceili(hero.max_hp), hero.damage, hero.rate, hero.range, hero.armor, hero.speed, int(hero.get("projectile_count", 1))]

func refresh_buffs(sim) -> void:
	buff_panel.visible = sim.v2_mode and sim.state in ["running", "between", "paused"]
	for i in buff_labels.size():
		buff_labels[i].text = ""
		buff_icons[i].hide()
	if not buff_panel.visible:
		return
	if sim.run_state.buff_levels.is_empty():
		buff_labels[0].text = "◇ 等待首张强化卡"
		buff_labels[0].add_theme_color_override("font_color", MUTED)
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

func _layout_right_rail(sim) -> void:
	# The former right rail is now a compact bottom command deck, leaving the full width for combat.
	right_rail_shell.position = UI_LAYOUT.battle_right_shell_rect.position
	right_rail_shell.size = UI_LAYOUT.battle_right_shell_rect.size
	command_rail.position = UI_LAYOUT.battle_party_rect.position
	command_rail.size = UI_LAYOUT.battle_party_rect.size
	for i in hero_buttons.size():
		hero_buttons[i].position = UI_LAYOUT.battle_hero_card_rect.position + UI_LAYOUT.battle_hero_card_gap * i
		hero_buttons[i].size = UI_LAYOUT.battle_hero_card_rect.size
	action_rail.position = UI_LAYOUT.battle_action_rect.position
	action_rail.size = UI_LAYOUT.battle_action_rect.size
	skill_button.position = UI_LAYOUT.battle_skill_rect.position
	skill_button.size = UI_LAYOUT.battle_skill_rect.size
	ultimate_button.position = UI_LAYOUT.battle_ultimate_rect.position
	ultimate_button.size = UI_LAYOUT.battle_ultimate_rect.size
	ability_hint_label.position = UI_LAYOUT.battle_ability_hint_rect.position
	ability_hint_label.size = UI_LAYOUT.battle_ability_hint_rect.size
	var formation_width := UI_LAYOUT.battle_formation_rect.size.x / 3.0 - 3.0
	for i in formation_buttons.size():
		var mode: String = ["squad", "follow", "hold"][i]
		formation_buttons[mode].position = UI_LAYOUT.battle_formation_rect.position + Vector2(i * (formation_width + 4.5), 0)
		formation_buttons[mode].size = Vector2(formation_width, UI_LAYOUT.battle_formation_rect.size.y)
	preview_hint_label.position = UI_LAYOUT.battle_preview_hint_rect.position
	preview_hint_label.size = UI_LAYOUT.battle_preview_hint_rect.size
	buff_panel.position = UI_LAYOUT.battle_buff_rect.position
	buff_panel.size = UI_LAYOUT.battle_buff_rect.size
	support_panel.position = UI_LAYOUT.battle_buff_rect.position + Vector2(0, 56)
	support_panel.size = Vector2(UI_LAYOUT.battle_buff_rect.size.x, 48)
	right_rail_shell.visible = sim.v2_mode

func set_skill_aiming(enabled: bool) -> void:
	skill_aiming = enabled
	signature = ""

func set_ultimate_aiming(enabled: bool) -> void:
	ultimate_aiming = enabled
	signature = ""

func refresh_skill(sim, selected_id: int) -> void:
	var visible: bool = sim.v2_mode and sim.state in ["running", "between", "paused"]
	skill_button.visible = visible
	ultimate_button.visible = visible
	if not visible:
		return
	var hero: Dictionary = sim.heroes[selected_id] if selected_id >= 0 and selected_id < sim.heroes.size() else {}
	if hero.is_empty():
		skill_button.disabled = true
		ultimate_button.disabled = true
		return
	var element := str(hero.get("element", "none"))
	var color := element_color(element)
	skill_icon.texture = skill_icon_for(element)
	ultimate_icon.texture = ultimate_icon_for(element)
	skill_frame.texture = UI_SKIN.skill_frame_red if skill_aiming else UI_SKIN.skill_frame_gray
	ultimate_frame.texture = UI_SKIN.ultimate_frame_red if ultimate_aiming else UI_SKIN.ultimate_frame_gray
	var cooldown := float(hero.get("skill_cooldown", 0.0))
	skill_icon.modulate = Color(color.r, color.g, color.b, 0.22 if cooldown > 0.0 else 0.72)
	ultimate_icon.modulate = Color(color.lightened(0.18).r, color.lightened(0.18).g, color.lightened(0.18).b, 0.58)
	var deployed := bool(hero.get("deployed", false))
	skill_button.text = ""
	skill_button.tooltip_text = ""
	skill_name_label.text = sim.hero_skill_name(selected_id)
	skill_cooldown_overlay.visible = cooldown > 0.0 or not deployed
	skill_cd_label.text = "落点" if skill_aiming else ("%.1fs" % cooldown if cooldown > 0.0 else "READY")
	skill_key_label.text = "Q · CD" if cooldown > 0.0 else "Q · 战技"
	skill_cd_label.add_theme_color_override("font_color", Color("#ff9eaa") if cooldown > 0.0 else Color("#fff4ec"))
	skill_button.disabled = sim.state != "running" or cooldown > 0.0 or not deployed
	var energy := float(hero.get("energy", 0.0))
	var maximum := float(hero.get("max_energy", 100.0))
	var ultimate_cooldown := float(hero.get("ultimate_cooldown", 0.0))
	var energy_ready := energy >= maximum
	var ultimate_status := "冷却 %.1fs" % ultimate_cooldown if ultimate_cooldown > 0.0 else "E · %d/%d" % [roundi(energy), roundi(maximum)]
	ultimate_button.text = ""
	ultimate_button.tooltip_text = ""
	ultimate_name_label.text = sim.hero_ultimate_name(selected_id)
	ultimate_cooldown_overlay.visible = ultimate_cooldown > 0.0 or not energy_ready or not deployed
	ultimate_frame.modulate = Color("#fff2b4") if energy_ready and ultimate_cooldown <= 0.0 else Color.WHITE
	ultimate_cd_label.text = "落点" if ultimate_aiming else ("%.1fs" % ultimate_cooldown if ultimate_cooldown > 0.0 else ("READY" if energy_ready else "%d%%" % roundi(energy / maxf(1.0, maximum) * 100.0)))
	ultimate_key_label.text = "E · CD" if ultimate_cooldown > 0.0 else ("E · 终结技" if energy_ready else "E · 充能")
	ultimate_cd_label.add_theme_color_override("font_color", Color("#ff9eaa") if ultimate_cooldown > 0.0 else Color("#fff0a8") if energy_ready else Color("#ffe7a5"))
	ultimate_button.disabled = sim.state != "running" or ultimate_cooldown > 0.0 or not energy_ready or not deployed

func skill_icon_for(element: String) -> Texture2D:
	return {
		"anemo": ICON_TRACE,
		"electro": ICON_SPARK,
		"pyro": ICON_FIRE,
		"hydro": ICON_CIRCLE,
		"geo": ICON_MAGIC,
		"cryo": ICON_SPARK,
	}.get(element, ICON_SLASH)

func ultimate_icon_for(element: String) -> Texture2D:
	return {
		"anemo": ICON_MAGIC,
		"electro": ICON_SPARK,
		"pyro": ICON_FLARE,
		"hydro": ICON_CIRCLE,
		"geo": ICON_MAGIC,
		"cryo": ICON_FLARE,
	}.get(element, ICON_FLARE)

func portrait_texture(hero: Dictionary, sim_ref = null) -> Texture2D:
	var character_id := str(hero.get("character_id", ""))
	if sim_ref != null and sim_ref.database != null:
		var character: Dictionary = sim_ref.database.characters.get(character_id, {})
		var asset: Dictionary = sim_ref.database.assets.get(str(character.get("asset_key", "")), {})
		var portrait_path := str(asset.get("portrait", ""))
		if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
			var portrait_resource: Resource = ResourceLoader.load(portrait_path)
			if portrait_resource is Texture2D:
				return portrait_resource
	if character_id == "hero_03":
		var latest_portrait_path := "res://assets/characters/sequences/hero_03/portrait.png"
		if ResourceLoader.exists(latest_portrait_path):
			return ResourceLoader.load(latest_portrait_path)
	var tile: Vector2 = hero.get("tile", Vector2.ZERO)
	var fallback := AtlasTexture.new()
	fallback.atlas = UNIT_ATLAS
	fallback.region = Rect2(tile, Vector2(16, 16))
	return fallback

func _hero_card_input(event: InputEvent, hero_id: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		deploy_drag_action.emit(hero_id, event.pressed, get_viewport().get_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		recall_action.emit(hero_id)

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
