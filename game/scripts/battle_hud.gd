extends CanvasLayer
const GeneratedIconCatalog = preload("res://scripts/content/generated_icon_catalog.gd")
signal reward_action(index: int, hero_id: int)
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
const SKILL_ICON_FIRE = preload("res://assets/ui/skill_icons_v64/01_fireball_rgba.png")
const SKILL_ICON_WATER = preload("res://assets/ui/skill_icons_v64/02_water_ring_rgba.png")
const SKILL_ICON_LIGHTNING = preload("res://assets/ui/skill_icons_v64/03_lightning_rgba.png")
const SKILL_ICON_ICE = preload("res://assets/ui/skill_icons_v64/04_ice_shard_rgba.png")
const SKILL_ICON_TORNADO = preload("res://assets/ui/skill_icons_v64/05_tornado_rgba.png")
const SKILL_ICON_LASER = preload("res://assets/ui/skill_icons_v64/06_laser_rgba.png")
const SKILL_ICON_ROCK = preload("res://assets/ui/skill_icons_v64/07_rock_meteor_rgba.png")
const SKILL_ICON_HEAL = preload("res://assets/ui/skill_icons_v64/08_healing_heart_rgba.png")
const SKILL_ICON_ARROW = preload("res://assets/ui/skill_icons_v64/09_arrow_rain_rgba.png")
const SKILL_ICON_SLASH = preload("res://assets/ui/skill_icons_v64/10_sword_slash_rgba.png")
const SKILL_ICON_SHIELD = preload("res://assets/ui/skill_icons_v64/11_shield_rgba.png")
const SKILL_ICON_SPEED = preload("res://assets/ui/skill_icons_v64/12_speed_boot_rgba.png")
const SKILL_ICON_POISON = preload("res://assets/ui/skill_icons_v64/13_poison_rgba.png")
const SKILL_ICON_CRYSTAL = preload("res://assets/ui/skill_icons_v64/14_summon_crystal_rgba.png")
const SKILL_ICON_EXPLOSION = preload("res://assets/ui/skill_icons_v64/15_explosion_rgba.png")
const SKILL_ICON_TIME = preload("res://assets/ui/skill_icons_v64/16_time_slow_rgba.png")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")
const DISPLAY_FONT = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
var config
var reward_panel
var progression_label: Label
var hero_details: Array[Label] = []
var base_label: Label
var wave_label: Label
var count_label: Label
var status_label: Label
var map_name_label: Label
var arena_event_name := ""
var arena_event_until_ms := 0
var pause_button: Button
var hero_buttons: Array[Button] = []
var hero_card_frames: Array[TextureRect] = []
var hero_name_labels: Array[Label] = []
var hero_element_labels: Array[Label] = []
var hero_statuses: Array[Label] = []
var hero_lock_labels: Array[Label] = []
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
var support_details: Array[Dictionary] = []
var buff_panel: Panel
var buff_labels: Array[Label] = []
var buff_icons: Array[TextureRect] = []
var buff_details: Array[Dictionary] = []
var info_popover: Panel
var info_title: Label
var info_body: Label
var last_sim
var last_selected_id := -1
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
var boss_alert_frame: TextureRect
var boss_scene_tint: ColorRect
var boss_warning: AudioStreamPlayer
var wave_timeline_panel: Panel
var wave_timeline_labels: Array[Label] = []
var formation_buttons: Dictionary = {}
var pause_details: Panel
var pause_menu_button: Button
var pause_status_label: Label
var pause_settings_button: Button
var pause_restart_button: Button
var restart_dialog: ConfirmationDialog
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
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	font.font_weight = 600
	ui_theme.default_font = font
	ui_theme.default_font_size = 13
	root.theme = ui_theme
	add_child(root)
	add_child(ui_highlight)
	add_child(ui_confirm)
	add_child(boss_warning)
	var topbar := Panel.new()
	topbar.position = UI_LAYOUT.battle_status_rect.position
	topbar.size = UI_LAYOUT.battle_status_rect.size
	topbar.add_theme_stylebox_override("panel", hud_shelf_style(Color(0.018, 0.007, 0.012, 0.97), Color("#a5273d"), 1))
	topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(topbar)
	var top_rule := ColorRect.new()
	top_rule.position = Vector2(16, 62)
	top_rule.size = Vector2(1248, 2)
	top_rule.color = Color("#ef3150")
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_rule)
	var brand_accent := ColorRect.new()
	brand_accent.position = UI_LAYOUT.battle_title_rect.position + Vector2(0, 8)
	brand_accent.size = Vector2(4, 39)
	brand_accent.color = Color("#ff3655")
	brand_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brand_accent)
	var brand_title := label(root, UI_LAYOUT.battle_title_rect.position + Vector2(13, -1), Vector2(184, 34), "裂 隙 守 望", 23, WHITE)
	brand_title.add_theme_font_override("font", DISPLAY_FONT)
	brand_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var brand_subtitle := label(root, UI_LAYOUT.battle_title_rect.position + Vector2(15, 34), Vector2(185, 14), "RIFT GUARD  /  CHAPTER I", 8, Color("#ff526a"))
	brand_subtitle.add_theme_constant_override("outline_size", 2)
	brand_subtitle.add_theme_color_override("font_outline_color", Color("#16070c"))
	for separator_x in [232.0, 830.0, 1138.0]:
		var separator := ColorRect.new()
		separator.position = Vector2(separator_x, 15)
		separator.size = Vector2(1, 42)
		separator.color = Color("#6e2637")
		separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(separator)
	progression_label = label(root, Vector2(250, 35), Vector2(335, 18), "", 9, WHITE)
	progression_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	progression_label.clip_text = true
	base_label = label(root, Vector2(400, 10), Vector2(185, 21), "", 10, TEAL)
	base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	base_label.clip_text = true
	wave_label = label(root, Vector2(590, 10), Vector2(110, 21), "", 10, Color("#ff7185"))
	wave_label.clip_text = true
	count_label = label(root, Vector2(590, 35), Vector2(125, 18), "", 9, WHITE)
	count_label.clip_text = true
	map_name_label = label(root, Vector2(250, 10), Vector2(140, 21), "", 11, Color("#e8b1b4"))
	map_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_name_label.clip_text = true
	status_label = label(root, Vector2(570, 35), Vector2(550, 18), "", 9, MUTED)
	status_label.hide()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.clip_text = true
	var archive_btn := button(root, UI_LAYOUT.battle_archive_rect, "图鉴  [F2]", false)
	archive_btn.pressed.connect(func(): compendium_action.emit())
	archive_btn.hide()
	pause_button = button(root, UI_LAYOUT.battle_pause_rect, "Ⅱ  暂停", false)
	apply_compact_hud_button_style(pause_button)
	bind(pause_button, "pause_button")
	pause_button.position = UI_LAYOUT.battle_pause_rect.position
	pause_button.size = UI_LAYOUT.battle_pause_rect.size
	pause_button.pressed.connect(func(): pause_action.emit())
	right_rail_shell = panel(root, UI_LAYOUT.battle_right_shell_rect, Color(0.018, 0.022, 0.065, 0.62), Color("#8d3f52"))
	right_rail_shell.add_theme_stylebox_override("panel", hud_shelf_style(Color(0.018, 0.022, 0.065, 0.62), Color("#7b2638"), 1))
	for separator_x in [670.0, 930.0]:
		var deck_separator := ColorRect.new()
		deck_separator.position = Vector2(separator_x, 596)
		deck_separator.size = Vector2(1, 88)
		deck_separator.color = Color("#8d263a")
		deck_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(deck_separator)
	var right_rail_mark := label(right_rail_shell, Vector2(10, 574), Vector2(212, 18), "R I F T   C O M M A N D", 8, Color("#794452"))
	right_rail_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_rail_mark.hide()
	support_panel = panel(root, Rect2(840, 9, 285, 48), Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	support_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for i in 6:
		var column := int(i / 3)
		var row := i % 3
		var support_label := label(support_panel, Vector2(8 + column * 141, 3 + row * 14), Vector2(137, 14), "", 8, WHITE)
		support_label.mouse_filter = Control.MOUSE_FILTER_STOP
		support_label.gui_input.connect(_support_label_input.bind(i))
		support_labels.append(support_label)
		support_details.append({})
	support_panel.hide()
	buff_panel = panel(root, UI_LAYOUT.battle_buff_rect, Color(0.04, 0.018, 0.036, 0.90), Color("#65506f"))
	buff_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	buff_panel.clip_contents = true

	for i in 15:
		var column := i % 5
		var row := int(i / 5)
		var buff_icon := icon(buff_panel, "res://assets/ui/icons/temporary/nieobie/card.svg", Rect2(7 + column * 61, 8 + row * 29, 18, 18), Color("#d6b4f0"))
		buff_icon.mouse_filter = Control.MOUSE_FILTER_STOP
		buff_icon.gui_input.connect(_buff_icon_input.bind(i))
		buff_icons.append(buff_icon)
		buff_details.append({})
		buff_labels.append(label(buff_panel, Vector2(29 + column * 61, 7 + row * 29), Vector2(30, 20), "", 8, WHITE))
	buff_panel.hide()
	info_popover = panel(root, Rect2(884, 430, 340, 142), Color(0.018, 0.022, 0.065, 0.68), Color("#d94f66"))
	info_popover.mouse_filter = Control.MOUSE_FILTER_STOP
	info_title = label(info_popover, Vector2(18, 14), Vector2(304, 28), "", 16, Color("#ffb3bd"))
	info_body = label(info_popover, Vector2(18, 45), Vector2(304, 82), "", 11, WHITE)
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_popover.hide()
	var boss_panel_rect: Rect2 = UI_LAYOUT.battle_boss_panel_rect
	boss_panel = panel(root, boss_panel_rect, Color(0.025, 0.010, 0.022, 0.96), Color("#d6415b"))
	var boss_frame := NinePatchRect.new()
	boss_frame.texture = UI_SKIN.hero_frame_red
	boss_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_frame.patch_margin_left = 42
	boss_frame.patch_margin_right = 42
	boss_frame.patch_margin_top = 24
	boss_frame.patch_margin_bottom = 24
	boss_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.add_child(boss_frame)
	var boss_name_rect: Rect2 = UI_LAYOUT.battle_boss_name_rect
	boss_name_label = label(boss_panel, boss_name_rect.position, boss_name_rect.size, "", 15, Color("#ffb1bc"))
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_override("font", DISPLAY_FONT)
	boss_name_label.add_theme_color_override("font_shadow_color", Color("#480714"))
	boss_name_label.add_theme_constant_override("shadow_offset_y", 2)
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
	wave_timeline_panel = panel(root, UI_LAYOUT.battle_timeline_rect, Color(0.025, 0.010, 0.024, 0.94), Color("#d13b55"))
	wave_timeline_panel.add_theme_stylebox_override("panel", counter_badge_style())
	var timeline_item := label(wave_timeline_panel, Vector2(10, 1), Vector2(188, 23), "", 10, WHITE)
	timeline_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timeline_item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_timeline_labels.append(timeline_item)
	wave_timeline_panel.hide()
	boss_scene_tint = ColorRect.new()
	boss_scene_tint.position = UI_LAYOUT.battle_playfield_rect.position
	boss_scene_tint.size = UI_LAYOUT.battle_playfield_rect.size
	boss_scene_tint.color = Color(0.48, 0.015, 0.045, 0.0)
	boss_scene_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_scene_tint)
	boss_alert_frame = TextureRect.new()
	boss_alert_frame.texture = UI_SKIN.choice_frame_red
	boss_alert_frame.position = Vector2(180, 235)
	boss_alert_frame.size = Vector2(920, 92)
	boss_alert_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boss_alert_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	boss_alert_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_alert_frame)
	boss_alert_frame.hide()
	boss_alert = label(root, Vector2(240, 234), Vector2(800, 108), "", 40, Color("#fff1ed"))
	boss_alert.add_theme_font_override("font", DISPLAY_FONT)
	boss_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_alert.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_alert.add_theme_color_override("font_shadow_color", Color("#9e203c"))
	boss_alert.add_theme_constant_override("shadow_offset_x", 4)
	boss_alert.add_theme_constant_override("shadow_offset_y", 4)
	boss_alert.hide()
	command_rail = panel(root, UI_LAYOUT.battle_party_rect, Color(0.035, 0.014, 0.028, 0.84), Color("#b95868"))
	command_rail.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	bind(command_rail, "command_rail")
	action_rail = panel(root, UI_LAYOUT.battle_action_rect, Color(0.028, 0.012, 0.024, 0.88), Color("#73404f"))
	action_rail.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	skill_button = button(root, UI_LAYOUT.battle_skill_rect, "", true)
	skill_button.clip_contents = true
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
	skill_frame.hide()
	skill_icon = icon(skill_button, "res://assets/ui/skill_icons_v64/10_sword_slash_rgba.png", Rect2(9, 10, 32, 32), WHITE)
	skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_cooldown_overlay = ColorRect.new()
	skill_cooldown_overlay.position = Vector2(9, 10)
	skill_cooldown_overlay.size = Vector2(32, 32)
	skill_cooldown_overlay.color = Color(0.015, 0.006, 0.018, 0.72)
	skill_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_button.add_child(skill_cooldown_overlay)
	skill_name_label = label(skill_button, Vector2.ZERO, Vector2.ZERO, "", 1, WHITE)
	skill_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_name_label.clip_text = true
	var skill_key_plate := ColorRect.new()
	skill_key_plate.position = Vector2(47, 27)
	skill_key_plate.size = Vector2(34, 18)
	skill_key_plate.color = Color(0, 0, 0, 0)
	skill_key_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_button.add_child(skill_key_plate)
	skill_cd_label = label(skill_button, Vector2(47, 3), Vector2(60, 22), "READY", 11, Color("#fff4ec"))
	skill_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skill_key_label = label(skill_button, Vector2(47, 27), Vector2(60, 18), "Q战技", 9, Color("#ffd9de"))
	skill_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_cd_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	skill_cd_label.add_theme_constant_override("shadow_offset_y", 2)
	skill_button.pressed.connect(func():
		_show_ability_info(false)
		skill_action.emit())
	ultimate_button = button(root, UI_LAYOUT.battle_ultimate_rect, "", true)
	ultimate_button.clip_contents = true
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
	ultimate_frame.hide()
	ultimate_icon = icon(ultimate_button, "res://assets/ui/skill_icons_v64/15_explosion_rgba.png", Rect2(9, 10, 32, 32), WHITE)
	ultimate_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_cooldown_overlay = ColorRect.new()
	ultimate_cooldown_overlay.position = Vector2(9, 10)
	ultimate_cooldown_overlay.size = Vector2(32, 32)
	ultimate_cooldown_overlay.color = Color(0.015, 0.006, 0.018, 0.72)
	ultimate_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_button.add_child(ultimate_cooldown_overlay)
	ultimate_name_label = label(ultimate_button, Vector2.ZERO, Vector2.ZERO, "", 1, WHITE)
	ultimate_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_name_label.clip_text = true
	var ultimate_key_plate := ColorRect.new()
	ultimate_key_plate.position = Vector2(47, 27)
	ultimate_key_plate.size = Vector2(34, 18)
	ultimate_key_plate.color = Color(0, 0, 0, 0)
	ultimate_key_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_button.add_child(ultimate_key_plate)
	ultimate_cd_label = label(ultimate_button, Vector2(47, 3), Vector2(60, 22), "READY", 11, Color("#ffe7a5"))
	ultimate_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ultimate_key_label = label(ultimate_button, Vector2(47, 27), Vector2(60, 18), "E终极", 9, Color("#fff0ae"))
	ultimate_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_cd_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	ultimate_cd_label.add_theme_constant_override("shadow_offset_y", 2)
	ultimate_button.pressed.connect(func():
		_show_ability_info(true)
		ultimate_action.emit())
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
		var hero_frame := TextureRect.new()
		hero_frame.texture = UI_SKIN.hero_frame_red if i == 0 else UI_SKIN.hero_frame_gray
		hero_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hero_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hero_btn.add_child(hero_frame)
		hero_frame.hide()
		hero_card_frames.append(hero_frame)
		hero_btn.pressed.connect(func(): select_action.emit(i))
		hero_btn.gui_input.connect(_hero_card_input.bind(i))
		hero_buttons.append(hero_btn)
		var lock_label := label(hero_btn, Vector2(8, 11), Vector2(44, 48), "🔒", 22, Color("#ff667b"))
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		lock_label.add_theme_constant_override("shadow_offset_y", 2)
		lock_label.hide()
		hero_lock_labels.append(lock_label)
		var portrait_frame := panel(hero_btn, Rect2(7, 10, 46, 50), Color("#33232d"), TEAL)
		var portrait_back := ColorRect.new()
		portrait_back.position = Vector2(3, 3)
		portrait_back.size = Vector2(40, 44)
		portrait_back.color = Color("#ead9dc")
		portrait_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_frame.add_child(portrait_back)
		var portrait_image := TextureRect.new()
		portrait_image.position = Vector2(3, 3)
		portrait_image.size = Vector2(40, 44)
		portrait_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_frame.add_child(portrait_image)
		hero_portraits.append(portrait_image)
		hero_name_labels.append(label(hero_btn, Vector2(58, 5), Vector2(96, 18), "%d  未部署" % [i + 1], 12, WHITE))
		var element_badge := label(hero_btn, Vector2(158, 5), Vector2(34, 18), "无", 10, MUTED)
		element_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		element_badge.add_theme_color_override("font_outline_color", Color("#160d14"))
		element_badge.add_theme_constant_override("outline_size", 2)
		hero_element_labels.append(element_badge)
		var hp_bar := ProgressBar.new()
		hp_bar.position = Vector2(58, 27)
		hp_bar.size = UI_LAYOUT.battle_hero_hp_bar_size
		hp_bar.show_percentage = false
		var hp_bg := StyleBoxFlat.new()
		hp_bg.bg_color = Color("#251923")
		var hp_fill := StyleBoxFlat.new()
		hp_fill.bg_color = Color("#be5364")
		hp_bar.add_theme_stylebox_override("background", hp_bg)
		hp_bar.add_theme_stylebox_override("fill", hp_fill)
		hero_btn.add_child(hp_bar)
		hp_bar.position = Vector2(58, 27)
		hp_bar.size = UI_LAYOUT.battle_hero_hp_bar_size
		hero_hp_bars.append(hp_bar)
		var energy_bar := ProgressBar.new()
		energy_bar.position = Vector2(58, 52)
		energy_bar.size = UI_LAYOUT.battle_hero_energy_bar_size
		energy_bar.show_percentage = false
		var energy_bg := StyleBoxFlat.new()
		energy_bg.bg_color = Color("#251923")
		var energy_fill := StyleBoxFlat.new()
		energy_fill.bg_color = Color("#f2bd5d")
		energy_bar.add_theme_stylebox_override("background", energy_bg)
		energy_bar.add_theme_stylebox_override("fill", energy_fill)
		hero_btn.add_child(energy_bar)
		energy_bar.position = Vector2(58, 52)
		energy_bar.size = UI_LAYOUT.battle_hero_energy_bar_size
		hero_energy_bars.append(energy_bar)
		hero_statuses.append(label(hero_btn, Vector2(58, 34), Vector2(134, 14), "", 9, WHITE))
		hero_details.append(label(hero_btn, Vector2(58, 56), Vector2(134, 10), "", 8, MUTED))
	ability_hint_label = label(root, Vector2.ZERO, Vector2.ZERO, "", 1, TEAL)
	preview_hint_label = label(root, Vector2.ZERO, Vector2.ZERO, "", 1, MUTED)
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
	var pause_scrim := ColorRect.new()
	pause_scrim.position = Vector2(18, 12)
	pause_scrim.size = Vector2(1134, 640)
	pause_scrim.color = Color(0.020, 0.012, 0.019, 0.985)
	pause_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_details.add_child(pause_scrim)
	var build_column := ColorRect.new()
	build_column.position = Vector2(22, 112)
	build_column.size = Vector2(520, 380)
	build_column.color = Color(0.060, 0.030, 0.050, 0.96)
	build_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_details.add_child(build_column)
	var stats_column := ColorRect.new()
	stats_column.position = Vector2(558, 112)
	stats_column.size = Vector2(590, 380)
	stats_column.color = Color(0.070, 0.025, 0.040, 0.96)
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
	pause_settings_button = button(pause_details, Rect2(34, 514, 340, 42), "⚙  设置", false)
	pause_settings_button.pressed.connect(func(): settings_action.emit())
	pause_restart_button = button(pause_details, Rect2(390, 514, 340, 42), "↻  重开", false)
	pause_restart_button.pressed.connect(request_restart_confirmation)
	pause_squad_button = button(pause_details, Rect2(746, 514, 362, 42), "▦  图鉴", false)
	pause_squad_button.pressed.connect(func(): compendium_action.emit())
	pause_stage_button = button(pause_details, Rect2(), "", false)
	pause_stage_button.hide()
	pause_menu_button = button(pause_details, Rect2(34, 574, 340, 46), "⌂  主菜单", false)
	pause_menu_button.pressed.connect(func(): main_menu_action.emit())
	pause_map_button = button(pause_details, Rect2(390, 574, 340, 46), "◇  路线", false)
	pause_map_button.pressed.connect(func(): map_action.emit())
	var pause_continue := button(pause_details, Rect2(746, 574, 362, 46), "▶  继续防守", true)
	pause_continue.pressed.connect(func(): primary_action.emit())
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.title = "确认重开"
	restart_dialog.dialog_text = "确定放弃当前战斗进度并重新开始本关吗？"
	restart_dialog.ok_button_text = "重开本关"
	restart_dialog.cancel_button_text = "返回设置"
	restart_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	restart_dialog.min_size = Vector2i(520, 210)
	restart_dialog.confirmed.connect(func(): restart_action.emit())
	overlay.add_child(restart_dialog)
	pause_details.hide()
	reward_panel = preload("res://scripts/reward_panel.gd").new()
	root.add_child(reward_panel)
	reward_panel.build(self)
	reward_panel.chosen.connect(func(index: int, hero_id: int): reward_action.emit(index, hero_id))

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

func hud_shelf_style(fill: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.corner_radius_top_left = 3
	box.corner_radius_top_right = 3
	box.corner_radius_bottom_left = 3
	box.corner_radius_bottom_right = 3
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 2)
	return box

func counter_badge_style() -> StyleBoxFlat:
	var box := hud_shelf_style(Color(0.018, 0.006, 0.014, 0.95), Color("#c9324d"), 1)
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 12
	box.border_width_left = 3
	box.border_width_right = 3
	box.shadow_size = 3
	return box
func compact_hud_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 2)
	return box

func apply_compact_hud_button_style(item: Button) -> void:
	item.add_theme_font_override("font", DISPLAY_FONT)
	item.add_theme_font_size_override("font_size", 12)
	item.add_theme_color_override("font_color", WHITE)
	item.add_theme_color_override("font_hover_color", Color.WHITE)
	item.add_theme_color_override("font_pressed_color", Color.WHITE)
	item.add_theme_stylebox_override("normal", compact_hud_button_style(Color("#14090e"), Color("#c52f4a")))
	item.add_theme_stylebox_override("hover", compact_hud_button_style(Color("#2a0c16"), Color("#ff526a")))
	item.add_theme_stylebox_override("pressed", compact_hud_button_style(Color("#3a0d1a"), Color("#ff8b9b")))
	item.add_theme_stylebox_override("focus", compact_hud_button_style(Color("#220b13"), Color("#ff526a")))
	item.add_theme_stylebox_override("disabled", compact_hud_button_style(Color("#100c10"), Color("#51303a")))
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
	parent.add_child(item)
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	item.custom_minimum_size = Vector2.ZERO
	item.texture = load(path)
	item.set_anchors_preset(Control.PRESET_TOP_LEFT)
	item.position = rect.position
	item.size = rect.size
	item.modulate = color
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

func refresh(sim, selected_id: int) -> void:
	last_sim = sim
	last_selected_id = selected_id
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
		base_label.text = "◆ HP %d/%d  ◇盾 %d" % [ceili(float(traveler.get("hp", 0.0))), ceili(float(traveler.get("max_hp", 0.0))), ceili(sim.crystal_shield)]
	else:
		base_label.text = "◆ 基地 %d/%d  ◇盾 %d" % [sim.base_hp, sim.base_max_hp, ceili(sim.crystal_shield)] if sim.v2_mode else "◆ 基地 %d/%d" % [sim.base_hp, sim.base_max_hp]
	if sim.v2_mode:
		var next_xp: int = sim.endless_next_threshold() if sim.endless_mode else sim.crystal.next_threshold(sim.run_state)
		var xp_text: String = "MAX" if next_xp < 0 else "%d / %d" % [sim.run_state.crystal_xp, next_xp]
		var seconds: int = floori(sim.elapsed) if sim.endless_mode else ceili(sim.stage_runtime.remaining_seconds())
		var queued := "  +%d卡" % sim.run_state.pending_level_ups if sim.run_state.pending_level_ups > 0 and sim.state != "reward" else ""
		if sim.endless_mode:
			progression_label.text = "等级 Lv.%d  •  EXP %s%s  •  %02d:%02d" % [sim.run_state.crystal_level, xp_text, queued, seconds / 60, seconds % 60]
			wave_label.text = "威胁等级   %02d" % maxi(1, floori(sim.elapsed / 45.0) + 1)
		else:
			progression_label.text = "水晶 Lv.%d  •  EXP %s%s  •  %02d:%02d" % [sim.run_state.crystal_level, xp_text, queued, seconds / 60, seconds % 60]
			wave_label.text = "波次   %02d / %02d" % [sim.wave, sim.stage_runtime.definition.get("waves", []).size()]
		map_name_label.text = str(sim.database.stages.get(sim.current_stage_id, {}).get("name", sim.current_stage_id))
	else:
		progression_label.text = "小队 Lv.%d / 5    ·    经验 %d    ·    强化 %d    ·    种子 %d" % [sim.team_level, sim.team_xp, sim.rewards.history.size(), sim.run_seed]
		wave_label.text = "节点   %02d / 05" % sim.wave
	count_label.text = "击退%02d · 敌%02d" % [sim.kills, sim.enemies.size()]
	status_label.text = "无尽生存 · WASD / 右键移动 · 同行者自动跟随" if sim.endless_mode else "按 1/2/3 或点击底部角色卡切换"
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
	pause_button.text = "▶  继续" if sim.state == "paused" else "Ⅱ  暂停"
	for i in hero_buttons.size():
		hero_buttons[i].visible = i < sim.heroes.size()
		hero_buttons[i].disabled = i >= sim.heroes.size() or (i < sim.heroes.size() and not sim.deployment_slot_unlocked(i))
	for i in sim.heroes.size():
		var hero: Dictionary = sim.heroes[i]
		hero_lock_labels[i].visible = not sim.deployment_slot_unlocked(i)
		if hero_lock_labels[i].visible:
			hero_lock_labels[i].move_to_front()
		hero_hp_bars[i].max_value = maxf(1.0, float(hero.max_hp))
		hero_hp_bars[i].value = maxf(0.0, float(hero.hp))
		hero_energy_bars[i].max_value = maxf(1.0, float(hero.get("max_energy", 100.0)))
		hero_energy_bars[i].value = maxf(0.0, float(hero.get("energy", 0.0)))
		hero_portraits[i].texture = portrait_texture(hero, sim)
		hero_name_labels[i].text = "%d  %s" % [i + 1, hero.name]
		hero_element_labels[i].text = "Lv.%d" % [1, 3, 10][i] if hero_lock_labels[i].visible else sim.element_name(str(hero.get("element", "none")))
		var hero_color: Color = element_color(str(hero.get("element", ""))) if hero.get("character_id", "") == "traveler" and hero.get("element", "") != "" else Color(hero.color)
		hero_name_labels[i].add_theme_color_override("font_color", hero_color)
		hero_element_labels[i].add_theme_color_override("font_color", hero_color)
		var hp_ratio := float(hero.hp) / maxf(1.0, float(hero.max_hp))
		hero_buttons[i].modulate = Color("#ff7888") if hp_ratio <= 0.25 and hero.hp > 0.0 else (Color.WHITE if i == selected_id else Color("#91a0a8"))
		hero_card_frames[i].texture = UI_SKIN.hero_frame_red if i == selected_id or hp_ratio <= 0.25 else UI_SKIN.hero_frame_gray
		for hero_state in ["normal", "hover", "pressed", "focus", "disabled"]:
			hero_buttons[i].add_theme_stylebox_override(hero_state, _battle_card_style(hero_color if i == selected_id else Color("#74414d"), i == selected_id))
		var status: String = "倒地" if hero.hp <= 0 else (("同行" if sim.endless_mode else "待命") if not bool(hero.get("deployed", true)) else ("移动中" if hero.moving else "就绪"))
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
		modal_card.visible = sim.state not in ["paused", "lost"]
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
				modal_copy.text = "评级 %s  ·  击退 %d  ·  基地 %d  ·  最高连杀 %d\n元素反应 %d 次  ·  %s\n本关构筑将在进入下一关时重置，可按 F4 选择关卡。" % [grade, sim.kills, base_percent, sim.best_streak, sim.reactions, unlock_copy]
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
	var upcoming: Array[Dictionary] = sim.upcoming_waves(1)
	var alive: int = sim.enemies.filter(func(enemy: Dictionary) -> bool: return float(enemy.get("hp", 0.0)) > 0.0).size()
	if upcoming.is_empty():
		wave_timeline_labels[0].text = "◆  怪物 %02d / %02d" % [alive, alive]
		wave_timeline_labels[0].add_theme_color_override("font_color", MUTED)
		return
	var item: Dictionary = upcoming[0]
	var eta := ceili(float(item.get("eta", 0.0)))
	var prefix := "BOSS" if bool(item.get("boss", false)) else "%02ds" % eta
	wave_timeline_labels[0].text = "◆  怪物 %02d / %02d  ·  %s" % [alive, alive + int(item.get("count", 1)), prefix]
	wave_timeline_labels[0].add_theme_color_override("font_color", Color("#ff899c") if bool(item.get("boss", false)) else WHITE)
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


func _show_boss_alert(copy: String, pitch: float = 0.82, hold: float = 1.20) -> void:
	if boss_warning != null and not muted:
		boss_warning.stop()
		boss_warning.pitch_scale = pitch
		boss_warning.volume_db = -8.0
		boss_warning.play()
	boss_alert.text = copy
	boss_alert.position = Vector2(240, 234)
	boss_alert.modulate = Color(1, 1, 1, 0)
	boss_alert.scale = Vector2(1.12, 1.12)
	boss_alert.pivot_offset = boss_alert.size * 0.5
	boss_alert_frame.position = Vector2(180, 235)
	boss_alert_frame.modulate = Color(1, 1, 1, 0)
	boss_alert_frame.scale = Vector2(0.94, 0.94)
	boss_alert_frame.pivot_offset = boss_alert_frame.size * 0.5
	boss_scene_tint.color.a = 0.0
	boss_scene_tint.show()
	boss_alert_frame.show()
	boss_alert.show()
	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(boss_scene_tint, "color:a", 0.24, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	entrance.tween_property(boss_alert_frame, "modulate:a", 1.0, 0.12)
	entrance.tween_property(boss_alert_frame, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.tween_property(boss_alert, "modulate:a", 1.0, 0.12).set_delay(0.04)
	entrance.tween_property(boss_alert, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await entrance.finished
	await get_tree().create_timer(hold).timeout
	var out := create_tween().set_parallel(true)
	out.tween_property(boss_alert, "modulate:a", 0.0, 0.24)
	out.tween_property(boss_alert_frame, "modulate:a", 0.0, 0.24)
	out.tween_property(boss_scene_tint, "color:a", 0.0, 0.32)
	await out.finished
	boss_alert.hide()
	boss_alert_frame.hide()
	boss_scene_tint.hide()

func announce_contract(name: String, reward: String) -> void:
	await _show_boss_alert("C O N T R A C T   C L E A R\n%s  ·  %s" % [name, reward], 1.22, 0.82)

func announce_boss(name: String) -> void:
	await _show_boss_alert("W A R N I N G\n%s  降 临" % name, 0.82, 1.85)
func announce_arena_event(kind: String, duration: float) -> void:
	arena_event_name = kind.replace("_", " ").to_upper()
	arena_event_until_ms = Time.get_ticks_msec() + roundi(minf(duration, 6.0) * 1000.0)

func announce_boss_phase(name: String, phase: int) -> void:
	var header := "P H A S E   II" if phase == 2 else "F I N A L   P H A S E"
	await _show_boss_alert("%s\n%s  狂 暴 阶 段" % [header, name], 1.08 if phase == 2 else 0.88, 1.20)
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
	for i in support_labels.size():
		support_labels[i].text = ""
		support_details[i] = {}
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
		support_labels[row].text = "◆ %s ×%d %.1fs" % [info[0], int(support.stacks), maxf(0.0, float(support.timer))]
		support_labels[row].add_theme_color_override("font_color", info[1])
		var effect_text: String = {
			"support_barrage": "周期锁定最高生命目标，炮击椭圆范围内的敌人。",
			"support_crossfire": "交叉火力周期齐射场上的敌人。",
			"support_heal": "潮汐急救周期治疗队伍并修复基地。",
			"support_finale": "终幕齐射周期集中攻击所有敌人。",
		}.get(key, "持续提供场外支援。")
		support_details[row] = {"title": "%s · ×%d" % [info[0], int(support.stacks)], "body": "%s 威力 %d · 间隔 %.1fs · 下次 %.1fs" % [effect_text, int(support.get("power", 0)), float(support.get("interval", 0.0)), maxf(0.0, float(support.timer))]}
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
		pause_hero_labels[i].text = "%d  %s  ·  %s  ·  %s\nHP  %4d / %-4d     ATK  %4.0f     ASPD  %.2f/s\nRNG %4.0f          DEF  %4.0f     SPD   %4.0f     ×%d" % [i + 1, hero.name, hero.role, element_text, ceili(hero.hp), ceili(hero.max_hp), hero.damage, hero.rate, hero.range, hero.armor, hero.speed, int(hero.get("projectile_count", 1))]

func refresh_buffs(sim) -> void:
	buff_panel.visible = sim.v2_mode and sim.state in ["running", "between", "paused"]
	for i in buff_labels.size():
		buff_labels[i].text = ""
		buff_icons[i].hide()
		buff_details[i] = {}
	if not buff_panel.visible or sim.run_state.buff_levels.is_empty():
		return
	var cards: Dictionary = {}
	for card: Dictionary in sim.database.cards:
		cards[str(card.id)] = card
	var rarity_rank := {"common": 0, "rare": 1, "epic": 2, "legendary": 3}
	var rarity_color := {"common": Color("#b7b8bd"), "rare": Color("#52b9ff"), "epic": Color("#c37cff"), "legendary": Color("#ffc55c")}
	var ids: Array = sim.run_state.buff_levels.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_id := str(a); var b_id := str(b)
		var a_card: Dictionary = cards.get(a_id, {}); var b_card: Dictionary = cards.get(b_id, {})
		var a_rank: int = int(rarity_rank.get(str(a_card.get("rarity", "common")), 0)); var b_rank: int = int(rarity_rank.get(str(b_card.get("rarity", "common")), 0))
		if a_rank != b_rank: return a_rank > b_rank
		var a_level := int(sim.run_state.buff_levels.get(a_id, 0)); var b_level := int(sim.run_state.buff_levels.get(b_id, 0))
		return a_level > b_level if a_level != b_level else a_id < b_id)
	for i in mini(buff_labels.size(), ids.size()):
		var id := str(ids[i]); var card: Dictionary = cards.get(id, {})
		var rarity := str(card.get("rarity", "common")); var effect := str(card.get("effect", ""))
		var card_icon := GeneratedIconCatalog.card_texture(card)
		buff_icons[i].texture = card_icon if card_icon != null else _buff_icon_for(effect)
		buff_icons[i].modulate = Color.WHITE
		var level := int(sim.run_state.buff_levels[id])
		buff_icons[i].tooltip_text = "%s · Lv.%d" % [str(card.get("name", id)), level]
		buff_details[i] = {"title": "%s  ·  Lv.%d" % [str(card.get("name", id)), level], "body": str(card.get("description", "暂无说明"))}
		buff_icons[i].show()
		buff_labels[i].text = "Lv.%d" % int(sim.run_state.buff_levels[id])
		buff_labels[i].add_theme_color_override("font_color", rarity_color.get(rarity, WHITE))

func _buff_icon_for(effect: String) -> Texture2D:
	if "speed" in effect or "rate" in effect: return SKILL_ICON_SPEED
	if "fire" in effect or "pyro" in effect or "burn" in effect: return SKILL_ICON_FIRE
	if "hydro" in effect or "heal" in effect: return SKILL_ICON_HEAL
	if "electro" in effect or "chain" in effect: return SKILL_ICON_LIGHTNING
	if "cryo" in effect or "freeze" in effect or "slow" in effect: return SKILL_ICON_ICE
	if "shield" in effect or "armor" in effect or "hp" in effect: return SKILL_ICON_SHIELD
	if "summon" in effect or "construct" in effect: return SKILL_ICON_CRYSTAL
	if "crit" in effect or "blast" in effect or "explosion" in effect: return SKILL_ICON_EXPLOSION
	if "range" in effect or "projectile" in effect: return SKILL_ICON_ARROW
	if "element" in effect or "reaction" in effect: return SKILL_ICON_LASER
	return SKILL_ICON_SLASH

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
	var formation_width := 72.0
	for i in formation_buttons.size():
		var mode: String = ["squad", "follow", "hold"][i]
		formation_buttons[mode].position = UI_LAYOUT.battle_formation_rect.position + Vector2(i * (formation_width + 7.0), 0)
		formation_buttons[mode].size = Vector2(formation_width, UI_LAYOUT.battle_formation_rect.size.y)
	preview_hint_label.position = UI_LAYOUT.battle_preview_hint_rect.position
	preview_hint_label.size = UI_LAYOUT.battle_preview_hint_rect.size
	buff_panel.position = UI_LAYOUT.battle_buff_rect.position
	buff_panel.size = UI_LAYOUT.battle_buff_rect.size
	support_panel.position = Vector2(840, 9)
	support_panel.size = Vector2(285, 48)
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
	var character_id := str(hero.get("character_id", ""))
	var q_texture := GeneratedIconCatalog.ability_texture(character_id, false)
	var e_texture := GeneratedIconCatalog.ability_texture(character_id, true)
	skill_icon.texture = q_texture if q_texture != null else skill_icon_for(element)
	ultimate_icon.texture = e_texture if e_texture != null else ultimate_icon_for(element)
	skill_frame.texture = UI_SKIN.skill_frame_red if skill_aiming else UI_SKIN.skill_frame_gray
	ultimate_frame.texture = UI_SKIN.ultimate_frame_red if ultimate_aiming else UI_SKIN.ultimate_frame_gray
	var cooldown := float(hero.get("skill_cooldown", 0.0))
	skill_icon.modulate = Color(1.0, 1.0, 1.0, 0.22 if cooldown > 0.0 else 0.86)
	ultimate_icon.modulate = Color(1.0, 1.0, 1.0, 0.86)
	var deployed := bool(hero.get("deployed", false))
	skill_button.text = ""
	skill_button.tooltip_text = ""
	skill_name_label.text = sim.hero_skill_name(selected_id)
	skill_cooldown_overlay.visible = cooldown > 0.0 or not deployed
	skill_cd_label.text = "落点" if skill_aiming else ("%.1fs" % cooldown if cooldown > 0.0 else "READY")
	skill_key_label.text = "Q冷却" if cooldown > 0.0 else "Q战技"
	skill_cd_label.add_theme_color_override("font_color", Color("#ff9eaa") if cooldown > 0.0 else Color("#fff4ec"))
	skill_button.disabled = sim.state != "running"
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
	ultimate_key_label.text = "E冷却" if ultimate_cooldown > 0.0 else ("E终极" if energy_ready else "E充能")
	ultimate_cd_label.add_theme_color_override("font_color", Color("#ff9eaa") if ultimate_cooldown > 0.0 else Color("#fff0a8") if energy_ready else Color("#ffe7a5"))
	ultimate_button.disabled = sim.state != "running"

func skill_icon_for(element: String) -> Texture2D:
	return {"anemo": SKILL_ICON_TORNADO, "electro": SKILL_ICON_LIGHTNING, "pyro": SKILL_ICON_FIRE, "hydro": SKILL_ICON_WATER, "geo": SKILL_ICON_ROCK, "cryo": SKILL_ICON_ICE}.get(element, SKILL_ICON_SLASH)

func ultimate_icon_for(element: String) -> Texture2D:
	return {"anemo": SKILL_ICON_TORNADO, "electro": SKILL_ICON_LASER, "pyro": SKILL_ICON_EXPLOSION, "hydro": SKILL_ICON_WATER, "geo": SKILL_ICON_CRYSTAL, "cryo": SKILL_ICON_TIME}.get(element, SKILL_ICON_EXPLOSION)

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
	if last_sim != null and not last_sim.deployment_slot_unlocked(hero_id):
		return
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









func _battle_card_style(border: Color, focused: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.045, 0.022, 0.034, 0.98)
	box.border_color = border
	box.set_border_width_all(2 if focused else 1)
	box.border_width_left = 4 if focused else 2
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	box.shadow_color = Color(border, 0.22 if focused else 0.0)
	box.shadow_size = 6 if focused else 0
	return box

func request_restart_confirmation() -> void:
	if restart_dialog == null:
		return
	restart_dialog.popup_centered(Vector2i(520, 210))



func _support_label_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if index >= 0 and index < support_details.size() and not support_details[index].is_empty():
			_show_info(str(support_details[index].get("title", "场外支援")), str(support_details[index].get("body", "")))
			get_viewport().set_input_as_handled()

func _buff_icon_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if index >= 0 and index < buff_details.size() and not buff_details[index].is_empty():
			_show_info(str(buff_details[index].get("title", "强化")), str(buff_details[index].get("body", "")))
		get_viewport().set_input_as_handled()

func _show_ability_info(ultimate: bool) -> void:
	if last_sim == null or last_selected_id < 0 or last_selected_id >= last_sim.heroes.size():
		return
	var hero: Dictionary = last_sim.heroes[last_selected_id]
	var data: Dictionary = hero.get("ultimate" if ultimate else "active_skill", {})
	var title_text := ("E · " if ultimate else "Q · ") + str(data.get("name", "终极技能" if ultimate else "元素战技"))
	var kind := str(data.get("kind", ""))
	var effect: String = {
		"blade_wave":"贯穿剑气击退沿途敌人", "columbia_tide_ring":"点按后水环环绕自身10秒，持续伤敌并治疗自身", "heal_gust":"治疗队友并赋予风盾与加速",
		"salon_summon":"沙龙成员持续追击并附着水元素", "hydro_burst":"水浪造成范围伤害与水元素附着", "sonic_wave":"音浪造成火元素范围伤害并击退",
		"arcane_lance":"穿透长枪压制直线目标", "frost_bloom":"冰花冻结区域并持续造成伤害", "echo_shot":"回响弹在目标间追加弹射",
		"tribbie_gate":"量子门复制弹道并折跃攻击", "mon3tr":"Mon3tr 冲锋拦截并撕裂敌阵", "bangboo":"邦布协同射击并标记目标",
		"starfall":"星落大范围轰击并强击退", "frozen_forest":"冻结领域持续冰封并造成多段伤害", "columbia_tidal_benediction":"全队攻击力提高哥伦比亚攻击力的100%，持续25秒", "anemo_domain":"风域牵引敌人并强化队友",
		"hydro_fanfare":"万众狂欢强化全队并引爆水元素", "storm_field":"雷暴领域连续落雷触发感电", "team_concert":"演唱会强化全队攻速与暴击",
		"chimera":"奇美拉范围碾压并持续压制", "fate_symphony":"焰色交响领域强化全队暴击", "encore":"安可复制支援并提升弹道数量",
		"trinity_field":"三重共鸣领域复制攻击与反应", "meltdown":"Mon3tr 熔毁造成巨额范围爆发", "network_overdrive":"邦布网络超频提升射速并齐射"
	}.get(kind, "释放角色专属能力")
	if kind in ["healing_surge", "wind_cut", "thread_shelter", "renewing_breeze", "needle_barrage"]:
		effect = str(data.get("description", effect))
	var body_text := "%s · 威力 %d · 范围 %d · 冷却 %.1fs" % [effect, int(data.get("power", 0)), int(data.get("radius", 0)), float(data.get("cooldown", 0.0))]
	if kind == "columbia_tide_ring":
		body_text = "%s · 范围 %d · 冷却 %.1fs" % [str(data.get("description", effect)), int(data.get("radius", 0)), float(data.get("cooldown", 0.0))]
	elif kind == "columbia_tidal_benediction":
		body_text = "%s · 冷却 %.1fs" % [str(data.get("description", effect)), float(data.get("cooldown", 0.0))]
	if ultimate:
		body_text += " · 能量 %d" % int(data.get("energy_cost", 0))
	_show_info(title_text, body_text)

func _show_info(title_text: String, body_text: String) -> void:
	info_title.text = title_text
	info_body.text = body_text
	info_popover.show()
	info_popover.move_to_front()

func dismiss_info_popover() -> void:
	if info_popover != null:
		info_popover.hide()

func _input(event: InputEvent) -> void:
	if info_popover == null or not info_popover.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered == null or (hovered != info_popover and not info_popover.is_ancestor_of(hovered)):
			info_popover.hide()
