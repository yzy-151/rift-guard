extends CanvasLayer
const GeneratedIconCatalog = preload("res://scripts/content/generated_icon_catalog.gd")
const PausePresentation = preload("res://scripts/pause_presentation.gd")
signal reward_action(index: int, hero_id: int)
signal reroll_action
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
signal debug_reward_action

const WHITE = Color("#f3e9df")
const MUTED = Color("#ae969f")
const TEAL = Color("#e3a2a5")
const HT_BUTTON = preload("res://assets/helltaker/ui/button.png")
const HT_BUTTON_HOVER = preload("res://assets/helltaker/ui/button hover.png")
const HT_BUTTON_ACTIVE = preload("res://assets/helltaker/ui/button active.png")
const HT_PANEL = preload("res://assets/helltaker/ui/button on.png")
const HT_HIGHLIGHT = preload("res://assets/helltaker/audio/button_menu_highlight_01.wav")
const HT_CONFIRM = preload("res://assets/helltaker/audio/button_menu_confirm_01.wav")
const HT_BOSS_WARNING = preload("res://assets/sfx/boss/boss_warning_eva.wav")
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
var external_battle_audio: bool = false
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
var deployment_notice: Label
var deployment_queue: Array[String] = []
var deployment_notice_active := false
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
var boss_secondary_hp_bar: ProgressBar
var boss_shield_bar: ProgressBar
var boss_secondary_shield_bar: ProgressBar
var boss_hp_label: Label
var boss_phase_label: Label
var contract_notice: Panel
var contract_notice_label: Label
var contract_notice_tween: Tween
var boss_alert: Label
var boss_alert_frame: Panel
var boss_alert_ticker: Label
var boss_scene_tint: ColorRect
var boss_skill_warning_panel: Panel
var boss_skill_warning_icon: Label
var boss_skill_warning_title: Label
var boss_skill_warning_ticker: Label
var boss_skill_warning_tween: Tween
var boss_skill_flash_tween: Tween
var boss_warning: AudioStreamPlayer
var wave_timeline_panel: Panel
var wave_timeline_labels: Array[Label] = []
var formation_buttons: Dictionary = {}
var pause_details: Panel
var pause_presentation
var pause_continue_button: Button
var pause_menu_button: Button
var pause_status_label: Label
var pause_settings_button: Button
var pause_restart_button: Button
var restart_dialog: ConfirmationDialog
var pause_squad_button: Button
var pause_stage_button: Button
var pause_map_button: Button
var pause_help_button: Button
var pause_buff_labels: Array[Label] = []
var pause_hero_labels: Array[Label] = []
var hero_hp_bars: Array[ProgressBar] = []
var ui_highlight: AudioStreamPlayer
var ui_confirm: AudioStreamPlayer
var xp_bar: ProgressBar
var xp_shimmer: ColorRect
var shield_label: Label
var buff_title: Label
var buff_page_label: Label
var buff_previous: Button
var buff_next: Button
var buff_empty_label: Label
var buff_page := 0
var buff_page_count := 1
var buff_signature := ""
var buff_seen: Dictionary = {}
var hero_hp_trails: Array[ProgressBar] = []
var skill_charge: ProgressBar
var ultimate_charge: ProgressBar
var toast_queue: Array[Dictionary] = []
var active_toast: Dictionary = {}
var toast_remaining := 0.0
var danger_remaining := 0.0
var arrival_remaining := 0.0
var motion_pops: Dictionary = {}
var last_xp := -1
var shimmer_remaining := 0.0
var previous_selection := -99
var previous_q_ready := false
var previous_e_ready := false
var last_run_key := ""
var portrait_cache: Dictionary = {}
const BUFF_PAGE_SIZE := 10
const TOAST_LIMIT := 6


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
	top_rule.position = Vector2(16, 53)
	top_rule.size = Vector2(1248, 2)
	top_rule.color = Color("#b12b43")
	top_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_rule)
	var brand_accent := ColorRect.new()
	brand_accent.position = Vector2(27, 14)
	brand_accent.size = Vector2(3, 28)
	brand_accent.color = Color("#f24660")
	brand_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brand_accent)
	for separator_x in [376.0, 944.0, 1137.0]:
		var separator := ColorRect.new()
		separator.position = Vector2(separator_x, 14)
		separator.size = Vector2(1, 27)
		separator.color = Color("#612331")
		separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(separator)
	map_name_label = label(root, Vector2(40, 5), Vector2(321, 25), "", 18, WHITE)
	map_name_label.add_theme_font_override("font", DISPLAY_FONT)
	map_name_label.clip_text = true
	progression_label = label(root, Vector2(42, 28), Vector2(318, 18), "", 12, MUTED)
	progression_label.clip_text = true
	xp_bar = _meter(root, Rect2(42, 47, 318, 3), Color("#f04a65"))
	xp_shimmer = ColorRect.new()
	xp_shimmer.position = xp_bar.position
	xp_shimmer.size = Vector2(24, 3)
	xp_shimmer.color = Color("#ffe9d5")
	xp_shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_shimmer.hide()
	root.add_child(xp_shimmer)
	wave_label = label(root, Vector2(392, 6), Vector2(254, 23), "", 16, Color("#ff91a2"))
	wave_label.clip_text = true
	count_label = label(root, Vector2(392, 30), Vector2(538, 18), "", 12, MUTED)
	count_label.hide()
	base_label = label(root, Vector2(959, 7), Vector2(172, 21), "", 14, WHITE)
	base_label.clip_text = true
	shield_label = label(root, Vector2(959, 30), Vector2(172, 18), "", 12, MUTED)
	shield_label.clip_text = true
	status_label = label(root, Vector2.ZERO, Vector2.ZERO, "", 12, MUTED)
	status_label.hide()
	var archive_btn := button(root, UI_LAYOUT.battle_archive_rect, "图鉴  [F2]", false)
	archive_btn.pressed.connect(func(): compendium_action.emit())
	archive_btn.hide()
	pause_button = button(root, UI_LAYOUT.battle_pause_rect, "Ⅱ  暂停", false)
	apply_compact_hud_button_style(pause_button)
	bind(pause_button, "pause_button")
	pause_button.position = UI_LAYOUT.battle_pause_rect.position
	pause_button.size = UI_LAYOUT.battle_pause_rect.size
	pause_button.pressed.connect(func(): pause_action.emit())
	right_rail_shell = panel(root, UI_LAYOUT.battle_right_shell_rect, Color(0.024, 0.010, 0.018, 0.98), Color("#8d3f52"))
	right_rail_shell.add_theme_stylebox_override("panel", hud_shelf_style(Color(0.024, 0.010, 0.018, 0.98), Color("#7b2638"), 1))
	for separator_x in [566.0, 865.0, 966.0]:
		var deck_separator := ColorRect.new()
		deck_separator.position = Vector2(separator_x, 629)
		deck_separator.size = Vector2(1, 75)
		deck_separator.color = Color("#8d263a")
		deck_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(deck_separator)
	var right_rail_mark := label(right_rail_shell, Vector2(10, 574), Vector2(212, 18), "R I F T   C O M M A N D", 8, Color("#794452"))
	right_rail_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_rail_mark.hide()
	support_panel = panel(root, Rect2(654, 8, 218, 40), Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	support_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for i in 6:
		var column := int(i / 3)
		var row := i % 3
		var support_label := label(support_panel, Vector2(4 + column * 108, 2 + row * 12), Vector2(104, 12), "", 8, WHITE)
		support_label.mouse_filter = Control.MOUSE_FILTER_STOP
		support_label.gui_input.connect(_support_label_input.bind(i))
		support_labels.append(support_label)
		support_details.append({})
	support_panel.hide()
	buff_panel = panel(root, UI_LAYOUT.battle_buff_rect, Color(0.04, 0.018, 0.036, 0.90), Color("#65506f"))
	buff_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	buff_panel.clip_contents = true

	buff_title = label(buff_panel, Vector2(0, 0), Vector2(165, 20), "构筑 / 0", 12, WHITE)
	buff_empty_label = label(buff_panel, Vector2(0, 29), Vector2(255, 44), "击退敌人，升级水晶
收集强化，形成流派", 12, MUTED)
	for i in BUFF_PAGE_SIZE:
		var column := i % 5
		var row := int(i / 5)
		var buff_icon := icon(buff_panel, "res://assets/ui/icons/temporary/nieobie/card.svg", Rect2(column * 53, 23 + row * 34, 31, 31), WHITE)
		buff_icon.mouse_filter = Control.MOUSE_FILTER_STOP
		buff_icon.gui_input.connect(_buff_icon_input.bind(i))
		buff_icons.append(buff_icon)
		buff_details.append({})
		var stack := label(buff_panel, Vector2(30 + column * 53, 36 + row * 34), Vector2(22, 17), "", 11, WHITE)
		stack.clip_text = true
		buff_labels.append(stack)
	buff_previous = button(buff_panel, Rect2(176, 0, 22, 20), "‹", false)
	buff_next = button(buff_panel, Rect2(240, 0, 22, 20), "›", false)
	for navigation in [buff_previous, buff_next]:
		navigation.add_theme_font_size_override("font_size", 15)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			navigation.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	buff_page_label = label(buff_panel, Vector2(198, 1), Vector2(42, 18), "1/1", 11, MUTED)
	buff_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buff_previous.pressed.connect(func(): change_buff_page(-1))
	buff_next.pressed.connect(func(): change_buff_page(1))
	buff_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	buff_panel.gui_input.connect(_buff_scroll_input)
	buff_panel.hide()
	deployment_notice = label(root, UI_LAYOUT.battle_deployment_notice_rect.position, UI_LAYOUT.battle_deployment_notice_rect.size, "", 16, Color("#a7ffdd"))
	deployment_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deployment_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deployment_notice.z_index = 30
	deployment_notice.hide()
	info_popover = panel(root, Rect2(884, 430, 340, 142), Color(0.018, 0.022, 0.065, 0.68), Color("#d94f66"))
	info_popover.mouse_filter = Control.MOUSE_FILTER_STOP
	info_title = label(info_popover, Vector2(18, 14), Vector2(304, 28), "", 16, Color("#ffb3bd"))
	info_body = label(info_popover, Vector2(18, 45), Vector2(304, 82), "", 11, WHITE)
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_popover.hide()
	var boss_panel_rect: Rect2 = UI_LAYOUT.battle_boss_panel_rect
	boss_panel = panel(root, boss_panel_rect, Color(0.018, 0.012, 0.025, 0.98), Color("#ff3559"))
	var boss_style := StyleBoxFlat.new()
	boss_style.bg_color = Color(0.035, 0.025, 0.05, 0.72)
	boss_style.border_color = Color("#ff3559")
	boss_style.border_width_left = 4
	boss_style.border_width_top = 2
	boss_style.border_width_right = 4
	boss_style.border_width_bottom = 2
	boss_style.corner_radius_top_left = 2
	boss_style.corner_radius_top_right = 13
	boss_style.corner_radius_bottom_left = 13
	boss_style.corner_radius_bottom_right = 2
	boss_style.shadow_color = Color(0.8, 0.02, 0.12, 0.32)
	boss_style.shadow_size = 3
	boss_panel.add_theme_stylebox_override("panel", boss_style)
	var boss_badge := label(boss_panel, Vector2(6, 3), Vector2(50, 22), "BOSS", 10, Color("#ffcf42"))
	boss_badge.add_theme_font_override("font", DISPLAY_FONT)
	boss_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var boss_name_rect: Rect2 = UI_LAYOUT.battle_boss_name_rect
	boss_name_label = label(boss_panel, boss_name_rect.position, boss_name_rect.size, "", 14, Color("#fff1ee"))
	boss_name_label.clip_text = true
	boss_name_label.add_theme_color_override("font_shadow_color", Color("#8f102d"))
	boss_name_label.add_theme_constant_override("shadow_offset_y", 2)
	boss_phase_label = label(boss_panel, Vector2(335, 4), Vector2(106, 19), "", 10, Color("#ff8095"))
	boss_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_phase_label.add_theme_font_override("font", DISPLAY_FONT)
	boss_hp_bar = ProgressBar.new()
	var boss_bar_rect: Rect2 = UI_LAYOUT.battle_boss_bar_rect
	boss_hp_bar.position = boss_bar_rect.position
	boss_hp_bar.size = boss_bar_rect.size
	boss_hp_bar.show_percentage = false
	boss_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var boss_bg := StyleBoxFlat.new()
	boss_bg.bg_color = Color(0.14, 0.075, 0.12, 0.78)
	boss_bg.border_color = Color("#7b2a42")
	boss_bg.set_border_width_all(1)
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color("#ee3153")
	boss_fill.border_color = Color("#ff98a9")
	boss_fill.border_width_top = 2
	boss_hp_bar.add_theme_stylebox_override("background", boss_bg)
	boss_hp_bar.add_theme_stylebox_override("fill", boss_fill)
	boss_panel.add_child(boss_hp_bar)
	boss_secondary_hp_bar = ProgressBar.new()
	boss_secondary_hp_bar.position = boss_bar_rect.position
	boss_secondary_hp_bar.size = boss_bar_rect.size
	boss_secondary_hp_bar.show_percentage = false
	boss_secondary_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var secondary_boss_bg := boss_bg.duplicate()
	secondary_boss_bg.border_color = Color("#765391")
	var secondary_boss_fill := boss_fill.duplicate()
	secondary_boss_fill.bg_color = Color("#a779e8")
	secondary_boss_fill.border_color = Color("#f5d976")
	boss_secondary_hp_bar.add_theme_stylebox_override("background", secondary_boss_bg)
	boss_secondary_hp_bar.add_theme_stylebox_override("fill", secondary_boss_fill)
	boss_secondary_hp_bar.hide()
	boss_panel.add_child(boss_secondary_hp_bar)
	boss_shield_bar = ProgressBar.new()
	boss_shield_bar.position = Vector2(boss_bar_rect.position.x, boss_bar_rect.end.y + 3)
	boss_shield_bar.size = Vector2(boss_bar_rect.size.x, 25)
	boss_shield_bar.scale = Vector2(1.0, 0.20)
	boss_shield_bar.show_percentage = false
	boss_shield_bar.add_theme_font_size_override("font_size", 1)
	boss_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shield_bg := StyleBoxFlat.new()
	shield_bg.bg_color = Color("#0b1a26")
	var shield_fill := StyleBoxFlat.new()
	shield_fill.bg_color = Color("#5bd9ff")
	shield_fill.border_color = Color("#c3f5ff")
	shield_fill.border_width_top = 1
	boss_shield_bar.add_theme_stylebox_override("background", shield_bg)
	boss_shield_bar.add_theme_stylebox_override("fill", shield_fill)
	boss_panel.add_child(boss_shield_bar)
	boss_secondary_shield_bar = ProgressBar.new()
	boss_secondary_shield_bar.position = boss_shield_bar.position
	boss_secondary_shield_bar.size = boss_shield_bar.size
	boss_secondary_shield_bar.scale = boss_shield_bar.scale
	boss_secondary_shield_bar.show_percentage = false
	boss_secondary_shield_bar.add_theme_font_size_override("font_size", 1)
	boss_secondary_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_secondary_shield_bar.add_theme_stylebox_override("background", shield_bg.duplicate())
	var secondary_shield_fill := shield_fill.duplicate()
	secondary_shield_fill.bg_color = Color("#c39cff")
	boss_secondary_shield_bar.add_theme_stylebox_override("fill", secondary_shield_fill)
	boss_secondary_shield_bar.hide()
	boss_panel.add_child(boss_secondary_shield_bar)
	for segment in range(1, 10):
		var divider := ColorRect.new()
		divider.position = boss_bar_rect.position + Vector2(boss_bar_rect.size.x * float(segment) / 10.0, 1)
		divider.size = Vector2(1, boss_bar_rect.size.y - 2)
		divider.color = Color(0.03, 0.01, 0.02, 0.72)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_panel.add_child(divider)
	var boss_value_rect: Rect2 = UI_LAYOUT.battle_boss_value_rect
	boss_hp_label = label(boss_panel, boss_value_rect.position, boss_value_rect.size, "", 13, Color("#ffcf42"))
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_hp_label.add_theme_font_override("font", DISPLAY_FONT)
	for corner_data in [[Vector2(4, 4), Vector2(34, 2)], [Vector2(boss_panel_rect.size.x - 38, boss_panel_rect.size.y - 6), Vector2(34, 2)]]:
		var corner := ColorRect.new()
		corner.position = corner_data[0]
		corner.size = corner_data[1]
		corner.color = Color("#ffcf42")
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_panel.add_child(corner)
	boss_panel.hide()
	wave_timeline_panel = panel(root, UI_LAYOUT.battle_timeline_rect, Color(0.025, 0.010, 0.024, 0.94), Color("#d13b55"))
	wave_timeline_panel.add_theme_stylebox_override("panel", counter_badge_style())
	var timeline_item := label(wave_timeline_panel, Vector2(8, 0), Vector2(258, 23), "", 12, WHITE)
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
	boss_alert_frame = panel(root, Rect2(390, 126, 500, 64), Color(0.035, 0.025, 0.05, 0.68), Color("#ff3b36"))
	var alert_style := StyleBoxFlat.new()
	alert_style.bg_color = Color(0.035, 0.025, 0.05, 0.68)
	alert_style.border_color = Color("#ff3b36")
	alert_style.border_width_left = 4
	alert_style.border_width_top = 3
	alert_style.border_width_right = 2
	alert_style.border_width_bottom = 3
	alert_style.corner_radius_top_right = 18
	alert_style.corner_radius_bottom_left = 18
	alert_style.shadow_color = Color(1.0, 0.02, 0.04, 0.42)
	alert_style.shadow_size = 4
	boss_alert_frame.add_theme_stylebox_override("panel", alert_style)
	boss_alert_frame.clip_contents = true
	boss_alert_ticker = label(boss_alert_frame, Vector2(15, 88), Vector2(1320, 20), "CAUTION // HOSTILE LIFEFORM // IMPACT PREDICTION // CAUTION // HOSTILE LIFEFORM //", 9, Color("#ffcf42"))
	boss_alert_ticker.add_theme_font_override("font", DISPLAY_FONT)
	boss_alert_ticker.hide()
	boss_alert_frame.hide()
	boss_alert = label(root, Vector2(412, 132), Vector2(456, 48), "", 19, Color("#fff1ed"))
	boss_alert.add_theme_font_override("font", DISPLAY_FONT)
	boss_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_alert.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_alert.add_theme_color_override("font_shadow_color", Color("#9e203c"))
	boss_alert.add_theme_constant_override("shadow_offset_x", 4)
	boss_alert.add_theme_constant_override("shadow_offset_y", 4)
	boss_alert.hide()
	contract_notice = panel(root, Rect2(390, 30, 540, 20), Color(0.035, 0.025, 0.04, 0.96), Color("#ba4b62"))
	contract_notice_label = label(contract_notice, Vector2(8, 0), Vector2(524, 20), "", 12, Color("#c4ffe6"))
	contract_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	contract_notice_label.clip_text = true
	contract_notice.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	contract_notice.hide()
	boss_skill_warning_panel = panel(root, Rect2(430, 120, 420, 34), Color(0.035, 0.02, 0.035, 0.66), Color("#ff493f"))
	var skill_warning_style := StyleBoxFlat.new()
	skill_warning_style.bg_color = Color(0.035, 0.02, 0.035, 0.66)
	skill_warning_style.border_color = Color("#ff493f")
	skill_warning_style.border_width_left = 9
	skill_warning_style.border_width_top = 2
	skill_warning_style.border_width_right = 2
	skill_warning_style.border_width_bottom = 2
	skill_warning_style.corner_radius_top_right = 12
	skill_warning_style.corner_radius_bottom_right = 12
	boss_skill_warning_panel.add_theme_stylebox_override("panel", skill_warning_style)
	boss_skill_warning_panel.clip_contents = true
	boss_skill_warning_icon = label(boss_skill_warning_panel, Vector2(5, 3), Vector2(28, 26), "⚠", 19, Color("#ffcf42"))
	boss_skill_warning_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_skill_warning_title = label(boss_skill_warning_panel, Vector2(36, 3), Vector2(375, 27), "", 14, Color("#fff2ee"))
	boss_skill_warning_title.clip_text = true
	boss_skill_warning_ticker = label(boss_skill_warning_panel, Vector2(100, 58), Vector2(1240, 20), "EVA // DANGER // PATTERN LOCKED // EVA // DANGER // PATTERN LOCKED //", 9, Color("#ff665e"))
	boss_skill_warning_ticker.add_theme_font_override("font", DISPLAY_FONT)
	boss_skill_warning_ticker.hide()
	boss_skill_warning_panel.hide()
	command_rail = panel(root, UI_LAYOUT.battle_party_rect, Color(0.035, 0.014, 0.028, 0.84), Color("#b95868"))
	command_rail.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	bind(command_rail, "command_rail")
	action_rail = panel(root, UI_LAYOUT.battle_action_rect, Color(0.028, 0.012, 0.024, 0.88), Color("#73404f"))
	action_rail.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	skill_button = button(root, UI_LAYOUT.battle_skill_rect, "", true)
	ultimate_button = button(root, UI_LAYOUT.battle_ultimate_rect, "", true)
	for ability_button in [skill_button, ultimate_button]:
		ability_button.clip_contents = false
		ability_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			ability_button.add_theme_stylebox_override(state, _battle_card_style(Color("#713443") if state != "hover" else Color("#f04a65"), state == "hover"))
	skill_frame = TextureRect.new()
	ultimate_frame = TextureRect.new()
	skill_button.add_child(skill_frame)
	ultimate_button.add_child(ultimate_frame)
	skill_frame.hide()
	ultimate_frame.hide()
	skill_name_label = label(skill_button, Vector2(9, 4), Vector2(124, 19), "", 12, WHITE)
	ultimate_name_label = label(ultimate_button, Vector2(9, 4), Vector2(124, 19), "", 12, WHITE)
	skill_name_label.clip_text = true
	ultimate_name_label.clip_text = true
	skill_icon = icon(skill_button, "res://assets/ui/skill_icons_v64/10_sword_slash_rgba.png", Rect2(8, 24, 50, 50), WHITE)
	ultimate_icon = icon(ultimate_button, "res://assets/ui/skill_icons_v64/15_explosion_rgba.png", Rect2(8, 24, 50, 50), WHITE)
	skill_cooldown_overlay = ColorRect.new()
	ultimate_cooldown_overlay = ColorRect.new()
	for pair in [[skill_button, skill_cooldown_overlay], [ultimate_button, ultimate_cooldown_overlay]]:
		var shade: ColorRect = pair[1]
		shade.position = Vector2(8, 24)
		shade.size = Vector2(50, 50)
		shade.color = Color(0.01, 0.005, 0.01, 0.22)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair[0].add_child(shade)
	skill_key_label = label(skill_button, Vector2(68, 24), Vector2(61, 22), "Q 战技", 12, Color("#ff91a2"))
	ultimate_key_label = label(ultimate_button, Vector2(68, 24), Vector2(61, 22), "E 终极", 12, Color("#f3cd80"))
	skill_cd_label = label(skill_button, Vector2(68, 49), Vector2(65, 23), "就绪", 15, WHITE)
	ultimate_cd_label = label(ultimate_button, Vector2(68, 49), Vector2(65, 23), "充能", 15, WHITE)
	skill_charge = _meter(skill_button, Rect2(8, 79, 126, 3), Color("#ee526c"))
	ultimate_charge = _meter(ultimate_button, Rect2(8, 79, 126, 3), Color("#f3cd80"))
	skill_button.pressed.connect(func(): skill_action.emit())
	ultimate_button.pressed.connect(func(): ultimate_action.emit())
	skill_button.gui_input.connect(_ability_info_input.bind(false))
	ultimate_button.gui_input.connect(_ability_info_input.bind(true))
	var formation_specs := [["squad", "Z  全队"], ["follow", "X  跟随"], ["hold", "C  坚守"]]
	for i in formation_specs.size():
		var mode: String = str(formation_specs[i][0])
		var formation_btn := button(root, Rect2(UI_LAYOUT.battle_formation_rect.position + Vector2(0, i * 29), Vector2(82, 25)), str(formation_specs[i][1]), false)
		formation_btn.add_theme_font_size_override("font_size", 12)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			formation_btn.add_theme_stylebox_override(state, _battle_card_style(Color("#723143") if state != "hover" else Color("#ed5873"), false))
		formation_btn.pressed.connect(func(): formation_action.emit(mode))
		formation_buttons[mode] = formation_btn
	for i in 3:
		var hero_btn := button(root, Rect2(UI_LAYOUT.battle_hero_card_rect.position + UI_LAYOUT.battle_hero_card_gap * i, UI_LAYOUT.battle_hero_card_rect.size), "", true)
		hero_btn.name = "HeroCard%d" % (i + 1)
		hero_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hero_btn.pressed.connect(func(): select_action.emit(i))
		hero_btn.gui_input.connect(_hero_card_input.bind(i))
		hero_buttons.append(hero_btn)
		var hero_frame := TextureRect.new()
		hero_btn.add_child(hero_frame)
		hero_frame.hide()
		hero_card_frames.append(hero_frame)
		var portrait_frame := panel(hero_btn, Rect2(5, 7, 54, 72), Color("#ead9dc"), Color("#6d3445"))
		portrait_frame.add_theme_stylebox_override("panel", hud_shelf_style(Color("#ead9dc"), Color("#6d3445"), 2))
		portrait_frame.clip_contents = true
		var portrait_image := TextureRect.new()
		portrait_image.position = Vector2(2, 2)
		portrait_image.size = Vector2(50, 68)
		portrait_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_frame.add_child(portrait_image)
		hero_portraits.append(portrait_image)
		var key_badge := label(hero_btn, Vector2(7, 7), Vector2(18, 20), str(i + 1), 12, Color.WHITE)
		key_badge.add_theme_color_override("font_outline_color", Color("#140a0f"))
		key_badge.add_theme_constant_override("outline_size", 6)
		var lock_label := label(hero_btn, Vector2(8, 30), Vector2(48, 20), "锁定", 12, WHITE)
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.add_theme_color_override("font_outline_color", Color("#180b12"))
		lock_label.add_theme_constant_override("outline_size", 6)
		lock_label.hide()
		hero_lock_labels.append(lock_label)
		var hero_name := label(hero_btn, Vector2(66, 6), Vector2(103, 20), "未部署", 13, WHITE)
		hero_name.clip_text = true
		hero_name_labels.append(hero_name)
		var element_badge := label(hero_btn, Vector2(145, 31), Vector2(24, 18), "", 12, MUTED)
		element_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hero_element_labels.append(element_badge)
		hero_statuses.append(label(hero_btn, Vector2(66, 30), Vector2(81, 19), "待命", 12, WHITE))
		hero_hp_trails.append(_meter(hero_btn, Rect2(66, 55, 101, 6), Color("#fff1d2")))
		var hp := _meter(hero_btn, Rect2(66, 55, 101, 6), Color("#e85670"))
		hp.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		hero_hp_bars.append(hp)
		hero_details.append(label(hero_btn, Vector2(66, 63), Vector2(101, 17), "", 11, MUTED))
		hero_energy_bars.append(_meter(hero_btn, Rect2(66, 82, 101, 3), Color("#f3cd80")))
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
	pause_presentation = PausePresentation.new()
	overlay.add_child(pause_presentation)
	pause_presentation.build(self)
	pause_details = pause_presentation
	pause_status_label = pause_presentation.status
	pause_settings_button = pause_presentation.actions.settings
	pause_settings_button.pressed.connect(func(): settings_action.emit())
	pause_restart_button = pause_presentation.actions.restart
	pause_restart_button.pressed.connect(request_restart_confirmation)
	pause_presentation.actions.compendium.pressed.connect(func(): compendium_action.emit())
	pause_squad_button = pause_presentation.actions.squad
	pause_squad_button.pressed.connect(func(): squad_action.emit())
	pause_stage_button = pause_presentation.actions.stages
	pause_stage_button.pressed.connect(func(): stage_action.emit())
	pause_menu_button = pause_presentation.actions.menu
	pause_menu_button.pressed.connect(func(): main_menu_action.emit())
	pause_map_button = pause_presentation.actions.map
	pause_map_button.pressed.connect(func(): map_action.emit())
	pause_continue_button = pause_presentation.actions["continue"]
	pause_continue_button.pressed.connect(func(): primary_action.emit())
	# Keep the internal debug hook out of the player-facing pause presentation.
	pause_help_button = Button.new()
	pause_help_button.focus_mode = Control.FOCUS_NONE
	pause_help_button.pressed.connect(func(): debug_reward_action.emit())
	pause_details.add_child(pause_help_button)
	pause_help_button.hide()
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.title = "确认重开"
	restart_dialog.dialog_text = "确定放弃当前战斗进度并重新开始本关吗？"
	restart_dialog.ok_button_text = "重开本关"
	restart_dialog.cancel_button_text = "返回暂停"
	restart_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	restart_dialog.min_size = Vector2i(520, 210)
	restart_dialog.confirmed.connect(func(): restart_action.emit())
	overlay.add_child(restart_dialog)
	pause_details.hide()
	reward_panel = preload("res://scripts/reward_panel.gd").new()
	root.add_child(reward_panel)
	reward_panel.build(self)
	reward_panel.reroll_requested.connect(func(): reroll_action.emit())
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
	var run_key := str([sim.current_stage_id, sim.endless_layout_id, sim.run_seed])
	if not last_run_key.is_empty() and run_key != last_run_key:
		reset_transients()
	last_run_key = run_key
	last_sim = sim
	last_selected_id = selected_id
	if sim.state == "paused": refresh_pause_details(sim)
	var next_signature: String = str([sim.current_stage_id, sim.endless_layout_id, sim.run_state.buff_levels if sim.v2_mode else {}, sim.state, sim.base_hp, sim.base_max_hp, sim.wave, sim.kills, sim.enemies.size(), sim.reactions, sim.kill_streak, ceili(sim.wave_timer), selected_id, sim.team_level, sim.team_xp, sim.run_seed, sim.rewards.history, sim.supports, ceili(sim.traveler_skill_cooldown * 10.0), sim.geo_constructs.size(), skill_aiming, ultimate_aiming, sim.formation_mode, sim.crystal_shield, reduced, sim.contract_status()])
	for enemy: Dictionary in sim.enemies:
		if str(enemy.get("kind", "")).begins_with("boss_"):
			next_signature += str([ceili(float(enemy.hp)), ceili(float(enemy.get("shield", 0.0)))])
	if sim.v2_mode:
		var stage_clock := floori(sim.elapsed) if sim.endless_mode else floori(sim.stage_runtime.remaining_seconds())
		next_signature += str([sim.run_state.crystal_level, sim.run_state.crystal_xp, sim.run_state.traveler_element, sim.run_state.traveler_secondary_element, sim.run_state.luck, sim.run_state.pending_level_ups, sim.run_state.active_resonances, stage_clock, sim.upcoming_waves(3)])
	for hero in sim.heroes:
		next_signature += str([hero.name, ceili(hero.hp), hero.moving, hero.blocked, hero.get("deployed", true), roundi(float(hero.get("energy", 0.0))), roundi(float(hero.get("skill_cooldown", 0.0)) * 10.0), roundi(float(hero.get("ultimate_cooldown", 0.0)) * 10.0)])
	if next_signature == signature:
		return
	signature = next_signature
	if sim.endless_mode:
		var traveler: Dictionary = sim.heroes[0] if not sim.heroes.is_empty() else {}
		base_label.text = "生命  %d / %d" % [ceili(float(traveler.get("hp", 0.0))), ceili(float(traveler.get("max_hp", 0.0)))]
	else:
		base_label.text = "核心  %d / %d" % [sim.base_hp, sim.base_max_hp]
	shield_label.text = "护盾 %d  ·  击退 %d" % [ceili(sim.crystal_shield), sim.kills]
	if sim.v2_mode:
		var next_xp: int = sim.endless_next_threshold() if sim.endless_mode else sim.crystal.next_threshold(sim.run_state)
		xp_bar.max_value = maxi(1, next_xp)
		xp_bar.value = sim.run_state.crystal_xp if next_xp > 0 else xp_bar.max_value
		if last_xp >= 0 and last_xp != sim.run_state.crystal_xp:
			shimmer_remaining = 0.65 if not reduced else 0.0
		last_xp = sim.run_state.crystal_xp
		var xp_text: String = "MAX" if next_xp < 0 else "%d / %d" % [sim.run_state.crystal_xp, next_xp]
		var seconds: int = floori(sim.elapsed) if sim.endless_mode else ceili(sim.stage_runtime.remaining_seconds())
		var queued := "  +%d卡" % sim.run_state.pending_level_ups if sim.run_state.pending_level_ups > 0 and sim.state != "reward" else ""
		if sim.endless_mode:
			progression_label.text = "Lv.%d  ·  经验 %s%s" % [sim.run_state.crystal_level, xp_text, queued]
			wave_label.text = "威胁 %02d  ·  生存 %02d:%02d" % [maxi(1, floori(sim.elapsed / 45.0) + 1), seconds / 60, seconds % 60]
		else:
			progression_label.text = "水晶 Lv.%d  ·  经验 %s%s" % [sim.run_state.crystal_level, xp_text, queued]
			wave_label.text = "波次 %02d / %02d   ·   %02d:%02d" % [sim.wave, sim.stage_runtime.definition.get("waves", []).size(), seconds / 60, seconds % 60]
			wave_label.tooltip_text = sim.stage_runtime.pacing_text()
		map_name_label.text = str(sim.endless_forecast().layout_name) if sim.endless_mode else str(sim.database.stages.get(sim.current_stage_id, {}).get("name", sim.current_stage_id))
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
	_update_ticker()
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
		var hp_max := maxf(1.0, float(hero.max_hp))
		var hp_value := maxf(0.0, float(hero.hp))
		if hero_hp_trails[i].max_value != hp_max or hp_value > hero_hp_trails[i].value or reduced:
			hero_hp_trails[i].max_value = hp_max
			hero_hp_trails[i].value = hp_value
		hero_hp_bars[i].max_value = hp_max
		hero_hp_bars[i].value = hp_value
		hero_energy_bars[i].max_value = maxf(1.0, float(hero.get("max_energy", 100.0)))
		hero_energy_bars[i].value = maxf(0.0, float(hero.get("energy", 0.0)))
		hero_portraits[i].texture = portrait_texture(hero, sim)
		hero_name_labels[i].text = str(hero.name)
		hero_name_labels[i].tooltip_text = str(hero.name)
		hero_element_labels[i].text = "" if hero_lock_labels[i].visible else sim.element_name(str(hero.get("element", "none")))
		var hero_color: Color = element_color(str(hero.get("element", ""))) if hero.get("character_id", "") == "traveler" and hero.get("element", "") != "" else Color(hero.color)
		hero_element_labels[i].add_theme_color_override("font_color", hero_color)
		var is_down := hp_value <= 0.0
		var is_locked: bool = hero_lock_labels[i].visible
		var is_deployed: bool = bool(hero.get("deployed", true))
		var selected: bool = i == selected_id
		hero_buttons[i].modulate = Color.WHITE
		hero_portraits[i].modulate = Color(0.45, 0.36, 0.40) if is_down or is_locked else Color.WHITE
		var border := Color("#f25571") if selected else Color("#6c3445")
		if is_down: border = Color("#7b6b75")
		var card_state := str([selected, is_down, is_locked])
		if str(hero_buttons[i].get_meta("card_state", "")) != card_state:
			hero_buttons[i].set_meta("card_state", card_state)
			for state in ["normal", "pressed", "focus", "disabled"]:
				hero_buttons[i].add_theme_stylebox_override(state, _battle_card_style(border, selected))
			hero_buttons[i].add_theme_stylebox_override("hover", _battle_card_style(Color("#ff9caf"), true))
		var state_text := "倒地" if is_down else ("已部署" if is_deployed else "待命 · 拖出")
		if bool(hero.moving) and is_deployed and not is_down: state_text = "移动中"
		if is_locked: state_text = "Lv.%d 解锁" % sim.deployment_required_level(i)
		hero_statuses[i].text = state_text
		hero_statuses[i].add_theme_color_override("font_color", Color("#ff9cab") if is_down else (Color("#a1e3cb") if is_deployed else MUTED))
		hero_details[i].text = "%d / %d" % [ceili(hp_value), ceili(hp_max)]
		hero_buttons[i].tooltip_text = "%s · %s\n生命 %d/%d · 攻击 %.0f · 攻速 %.1f/s\n点击选中 / 拖出部署 / 右键撤回" % [hero.name, state_text, ceili(hp_value), ceili(hp_max), hero.damage, hero.rate]
	if selected_id != previous_selection:
		if selected_id >= 0 and selected_id < hero_buttons.size(): _pop(hero_portraits[selected_id], 0.12)
		previous_selection = selected_id
	var was_visible: bool = overlay.visible
	overlay.visible = sim.state in ["ready", "paused"]
	modal_card.visible = sim.state == "ready"
	for control in background_buttons:
		control.focus_mode = Control.FOCUS_NONE if overlay.visible or sim.state == "reward" else Control.FOCUS_ALL
	if sim.state == "reward":
		dismiss_info_popover()
		reward_panel.display(sim)
	else:
		reward_panel.hide()
	if overlay.visible:
		pause_details.visible = sim.state == "paused"
		if sim.state == "ready":
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
		if sim.state == "paused":
			if pause_details.is_visible_in_tree() and not restart_dialog.visible and (not was_visible or get_viewport().gui_get_focus_owner() not in pause_presentation.focus_order):
				pause_continue_button.grab_focus()
		elif not was_visible or get_viewport().gui_get_focus_owner() != modal_action:
			modal_action.grab_focus()

func refresh_boss(sim) -> void:
	var bosses: Array[Dictionary] = []
	for enemy: Dictionary in sim.enemies:
		var hidden_reinforcement := str(enemy.get("kind", "")) == "boss_galio" and not bool(enemy.get("galio_revealed", true))
		if str(enemy.get("kind", "")).begins_with("boss_") and float(enemy.get("hp", 0.0)) > 0.0 and not hidden_reinforcement:
			bosses.append(enemy)
	var active: Dictionary = bosses[0] if not bosses.is_empty() else {}
	boss_panel.visible = not active.is_empty() and sim.state in ["running", "paused"]
	if active.is_empty():
		boss_secondary_hp_bar.hide()
		boss_secondary_shield_bar.hide()
		return
	var secondary: Dictionary = bosses[1] if bosses.size() > 1 else {}
	var original_position := UI_LAYOUT.battle_boss_bar_rect.position
	var original_size := UI_LAYOUT.battle_boss_bar_rect.size
	var split_width := (original_size.x - 8.0) * 0.5
	boss_hp_bar.position = original_position
	boss_hp_bar.size = Vector2(split_width, original_size.y) if not secondary.is_empty() else original_size
	var shield: float = float(active.get("shield", 0.0))
	var hp: float = maxf(0.0, float(active.hp))
	boss_name_label.text = "%s  +  %s" % [str(active.get("name", "裂隙首领")), str(secondary.get("name", ""))] if not secondary.is_empty() else str(active.get("name", "裂隙首领"))
	boss_phase_label.text = "P%s / P%s" % [int(active.get("boss_phase", 1)), int(secondary.get("boss_phase", 1))] if not secondary.is_empty() else "PHASE %s" % ["I", "II", "III"][clampi(int(active.get("boss_phase", 1)) - 1, 0, 2)]
	boss_hp_bar.max_value = maxf(1.0, float(active.max_hp))
	boss_hp_bar.value = hp
	boss_shield_bar.position = Vector2(original_position.x, original_position.y + original_size.y + 3.0)
	boss_shield_bar.size = Vector2(split_width if not secondary.is_empty() else original_size.x, 25.0)
	boss_shield_bar.max_value = maxf(1.0, float(active.get("max_shield", shield)))
	boss_shield_bar.value = shield
	boss_shield_bar.visible = shield > 0.0
	var hp_percent := roundi(hp / maxf(1.0, float(active.max_hp)) * 100.0)
	if secondary.is_empty():
		boss_secondary_hp_bar.hide()
		boss_secondary_shield_bar.hide()
		boss_hp_label.text = "%03d%%" % hp_percent
		return
	var secondary_hp := maxf(0.0, float(secondary.hp))
	var secondary_shield := float(secondary.get("shield", 0.0))
	boss_secondary_hp_bar.position = original_position + Vector2(split_width + 8.0, 0.0)
	boss_secondary_hp_bar.size = Vector2(split_width, original_size.y)
	boss_secondary_hp_bar.max_value = maxf(1.0, float(secondary.max_hp))
	boss_secondary_hp_bar.value = secondary_hp
	boss_secondary_hp_bar.show()
	boss_secondary_shield_bar.position = Vector2(original_position.x + split_width + 8.0, original_position.y + original_size.y + 3.0)
	boss_secondary_shield_bar.size = Vector2(split_width, 25.0)
	boss_secondary_shield_bar.max_value = maxf(1.0, float(secondary.get("max_shield", secondary_shield)))
	boss_secondary_shield_bar.value = secondary_shield
	boss_secondary_shield_bar.visible = secondary_shield > 0.0
	var secondary_percent := roundi(secondary_hp / maxf(1.0, float(secondary.max_hp)) * 100.0)
	boss_hp_label.text = "K %03d%%  G %03d%%" % [hp_percent, secondary_percent]

func refresh_wave_timeline(sim) -> void:
	wave_timeline_panel.visible = sim.v2_mode and sim.state in ["running", "paused", "between"]
	if not wave_timeline_panel.visible:
		return
	if sim.endless_mode:
		var forecast: Dictionary = sim.endless_forecast()
		wave_timeline_labels[0].text = ("补给窗口 " if float(forecast.supply_remaining) > 0 else "首领预告 ") + "%s · %02ds" % [str(forecast.next_boss), ceili(float(forecast.eta))]
		wave_timeline_labels[0].add_theme_color_override("font_color", Color("#ffb0bb") if bool(forecast.warning) else MUTED)
		wave_timeline_panel.tooltip_text = "阶段 %d · 敌人 Lv.%d · 下一阶段 %s" % [int(forecast.phase), int(forecast.level), str(forecast.next_roster)]
		return
	var upcoming: Array[Dictionary] = sim.upcoming_waves(1)
	var alive: int = sim.enemies.filter(func(enemy: Dictionary) -> bool: return float(enemy.get("hp", 0.0)) > 0.0).size()
	if upcoming.is_empty():
		wave_timeline_labels[0].text = "场上 %02d  ·  最后防线" % alive
		wave_timeline_labels[0].add_theme_color_override("font_color", MUTED)
		return
	var item: Dictionary = upcoming[0]
	var eta := ceili(float(item.get("eta", 0.0)))
	var prefix := "BOSS" if bool(item.get("boss", false)) else "%02ds" % eta
	wave_timeline_labels[0].text = "场上 %02d  ·  增援 +%02d / %s" % [alive, int(item.get("count", 1)), prefix]
	wave_timeline_labels[0].add_theme_color_override("font_color", Color("#ff899c") if bool(item.get("boss", false)) else WHITE)
func refresh_formations(sim, selected_id: int) -> void:
	for mode: String in formation_buttons:
		var item: Button = formation_buttons[mode]
		item.visible = sim.v2_mode and sim.state in ["running", "between", "paused"]
		item.disabled = sim.state == "paused"
		var active: bool = (mode == "squad" and selected_id == -2) or (mode != "squad" and sim.formation_mode == mode)
		item.modulate = Color("#ffd3d7") if active else Color("#a38f98")

func announce_route_warning(event: Dictionary) -> void:
	if bool(event.get("boss", false)):
		_show_boss_alert("⚠  BOSS APPROACHING\n首领即将登场", 0.82, 1.6)
		return
	if boss_warning != null and not muted and not external_battle_audio:
		boss_warning.stop()
		boss_warning.pitch_scale = 0.82 if bool(event.get("boss", false)) else 1.18
		boss_warning.volume_db = -8.0 if bool(event.get("boss", false)) else -15.0
		boss_warning.play()


func _show_boss_alert(copy: String, pitch: float = 0.82, hold: float = 1.20) -> void:
	if danger_remaining > 0.0: return
	if boss_warning != null and not muted and not external_battle_audio:
		boss_warning.pitch_scale = pitch
		boss_warning.play()
	boss_alert_frame.position = Vector2(430, 120)
	boss_alert_frame.size = Vector2(420, 34)
	boss_alert.position = Vector2(442, 123)
	boss_alert.size = Vector2(396, 27)
	boss_alert.add_theme_font_size_override("font_size", 15)
	boss_alert.clip_text = true
	boss_alert.text = copy.replace("\n", " · ")
	boss_alert.modulate = Color.WHITE
	boss_alert.scale = Vector2.ONE
	boss_alert_frame.modulate = Color.WHITE
	boss_alert_frame.scale = Vector2.ONE
	boss_alert_frame.show()
	boss_alert.show()
	arrival_remaining = hold + 0.3
	_pop(boss_alert_frame, 0.035)

func announce_boss_skill_warning(name: String, duration: float, phase: int) -> void:
	arrival_remaining = 0.0
	boss_alert_frame.hide()
	boss_alert.hide()
	boss_scene_tint.hide()
	boss_skill_warning_title.text = "%s  ·  阶段 %d" % [name, phase]
	boss_skill_warning_title.tooltip_text = name
	boss_skill_warning_panel.position = Vector2(430, 120)
	boss_skill_warning_panel.modulate = Color.WHITE
	boss_skill_warning_panel.show()
	danger_remaining = clampf(duration, 0.35, 12.0)
	_pop(boss_skill_warning_panel, 0.04)

func announce_contract(name: String, reward: String) -> void:
	_queue_toast("契约达成 · %s · %s" % [name, reward], 3, 3.3)

func announce_boss(name: String) -> void:
	_show_boss_alert("首领降临 · " + name, 0.82, 1.85)

func announce_arena_event(kind: String, duration: float) -> void:
	arena_event_name = {"hazard":"危险区域启动", "wind":"风向改变", "spring":"泉台涌动"}.get(kind, kind.replace("_", " "))
	_queue_toast("场地变化 · " + arena_event_name, 2, minf(duration, 4.0))

func announce_boss_phase(name: String, phase: int) -> void:
	_show_boss_alert("阶段 %d · %s 狂暴" % [phase, name], 1.08, 1.5)

func result_grade(base_hp: int, streak: int) -> String:
	if base_hp >= 85 and streak >= 20:
		return "S"
	if base_hp >= 60 and streak >= 10:
		return "A"
	if base_hp >= 30:
		return "B"
	return "C"

func refresh_supports(sim) -> void:
	# Support cards already live in the buff dock; the legacy text overlaps the timeline.
	support_panel.visible = false
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
		support_details[row] = {"title": "%s · ×%d" % [info[0], int(support.stacks)], "body": "%s 威力 %d · 间隔 %.1fs · 下次 %.1fs" % [effect_text, int(float(support.get("power", 0))*(1.0 if key=="support_heal" else sim.SUPPORT_DAMAGE_SCALE)), float(support.get("interval", 0.0)), maxf(0.0, float(support.timer))]}
		row += 1

func resonance_summary(sim) -> String:
	var names: Array[String] = []
	for id: String in sim.run_state.active_resonances:
		var resonance: Dictionary = sim.database.team_resonances.get(id, {})
		if not resonance.is_empty():
			names.append(str(resonance.get("name", id)))
	return " / ".join(names)
func refresh_pause_details(sim) -> void:
	pause_presentation.refresh_content(sim, last_selected_id)

func refresh_buffs(sim) -> void:
	buff_panel.visible = sim.v2_mode and sim.state in ["running", "between", "paused"]
	if not buff_panel.visible: return
	var next_buff_signature := str([sim.run_state.buff_levels, buff_page])
	if next_buff_signature == buff_signature: return
	buff_signature = next_buff_signature
	var cards: Dictionary = {}
	for card: Dictionary in sim.database.cards: cards[str(card.id)] = card
	var rarity_rank := {"common": 0, "rare": 1, "epic": 2, "legendary": 3}
	var rarity_color := {"common": Color("#b7b8bd"), "rare": Color("#52b9ff"), "epic": Color("#c37cff"), "legendary": Color("#ffc55c")}
	var ids: Array = sim.run_state.buff_levels.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var rank_a := int(rarity_rank.get(str(cards.get(str(a), {}).get("rarity", "common")), 0))
		var rank_b := int(rarity_rank.get(str(cards.get(str(b), {}).get("rarity", "common")), 0))
		return rank_a > rank_b if rank_a != rank_b else str(a) < str(b))
	buff_page_count = maxi(1, ceili(float(ids.size()) / BUFF_PAGE_SIZE))
	buff_page = clampi(buff_page, 0, buff_page_count - 1)
	buff_title.text = "构筑 / %d" % ids.size()
	buff_page_label.text = "%d/%d" % [buff_page + 1, buff_page_count]
	buff_previous.disabled = buff_page == 0
	buff_next.disabled = buff_page >= buff_page_count - 1
	buff_empty_label.visible = ids.is_empty()
	for i in BUFF_PAGE_SIZE:
		buff_icons[i].hide()
		buff_labels[i].text = ""
		buff_details[i] = {}
		var index := buff_page * BUFF_PAGE_SIZE + i
		if index >= ids.size(): continue
		var id := str(ids[index])
		var card: Dictionary = cards.get(id, {})
		var level := int(sim.run_state.buff_levels[id])
		var card_icon := GeneratedIconCatalog.card_texture(card)
		buff_icons[i].texture = card_icon if card_icon != null else _buff_icon_for(str(card.get("effect", "")))
		buff_icons[i].modulate = Color.WHITE
		buff_icons[i].tooltip_text = "%s · ×%d\n%s\n点击查看详情 · 滚轮翻页" % [str(card.get("name", id)), level, str(card.get("description", ""))]
		buff_details[i] = {"id": id, "title": "%s · ×%d" % [str(card.get("name", id)), level], "body": str(card.get("description", "暂无说明"))}
		buff_icons[i].show()
		buff_labels[i].text = "×%d" % level
		buff_labels[i].tooltip_text = "叠加 %d 次" % level
		buff_labels[i].add_theme_color_override("font_color", rarity_color.get(str(card.get("rarity", "common")), WHITE))
		if int(buff_seen.get(id, 0)) < level: _pop(buff_icons[i], 0.25)
		buff_seen[id] = level

func change_buff_page(direction: int) -> void:
	buff_page = clampi(buff_page + direction, 0, buff_page_count - 1)
	if last_sim != null: refresh_buffs(last_sim)

func _buff_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			change_buff_page(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			get_viewport().set_input_as_handled()

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
	right_rail_shell.visible = sim.v2_mode
	ability_hint_label.hide()
	preview_hint_label.hide()

func set_skill_aiming(enabled: bool) -> void:
	skill_aiming = enabled
	signature = ""

func set_ultimate_aiming(enabled: bool) -> void:
	ultimate_aiming = enabled
	signature = ""

func refresh_skill(sim, selected_id: int) -> void:
	var active: bool = sim.v2_mode and sim.state in ["running", "between", "paused"]
	skill_button.visible = active
	ultimate_button.visible = active
	if not active: return
	var hero: Dictionary = sim.heroes[selected_id] if selected_id >= 0 and selected_id < sim.heroes.size() else {}
	if hero.is_empty():
		skill_button.disabled = true
		ultimate_button.disabled = true
		skill_name_label.text = "选择角色"
		ultimate_name_label.text = "选择角色"
		skill_cd_label.text = "—"
		ultimate_cd_label.text = "—"
		skill_icon.modulate = Color(1, 1, 1, 0.35)
		ultimate_icon.modulate = Color(1, 1, 1, 0.35)
		skill_charge.value = 0.0
		ultimate_charge.value = 0.0
		skill_cooldown_overlay.show()
		ultimate_cooldown_overlay.show()
		previous_q_ready = false
		previous_e_ready = false
		return
	var element := str(hero.get("element", "none"))
	var character_id := str(hero.get("character_id", ""))
	var q_texture := GeneratedIconCatalog.ability_texture(character_id, false)
	var e_texture := GeneratedIconCatalog.ability_texture(character_id, true)
	skill_icon.texture = q_texture if q_texture != null else skill_icon_for(element)
	ultimate_icon.texture = e_texture if e_texture != null else ultimate_icon_for(element)
	var cooldown := float(hero.get("skill_cooldown", 0.0))
	var ultimate_cooldown := float(hero.get("ultimate_cooldown", 0.0))
	var energy := float(hero.get("energy", 0.0))
	var maximum := maxf(1.0, float(hero.get("max_energy", 100.0)))
	var deployed := bool(hero.get("deployed", false)) and float(hero.hp) > 0.0
	var q_ready := cooldown <= 0.0 and deployed
	var e_ready := ultimate_cooldown <= 0.0 and energy >= maximum and deployed
	skill_icon.modulate = Color(1.0, 1.0, 1.0, 1.0 if q_ready else 0.62)
	ultimate_icon.modulate = Color(1.0, 1.0, 1.0, 1.0 if e_ready else 0.62)
	skill_name_label.text = sim.hero_skill_name(selected_id)
	ultimate_name_label.text = sim.hero_ultimate_name(selected_id)
	skill_button.tooltip_text = "Q · %s\n%s\n右键查看数值详情" % [skill_name_label.text, str(sim.hero_ability(selected_id, false).get("description", ""))]
	ultimate_button.tooltip_text = "E · %s\n%s\n右键查看数值详情" % [ultimate_name_label.text, str(sim.hero_ability(selected_id, true).get("description", ""))]
	skill_cd_label.text = "选落点" if skill_aiming else ("待部署" if not deployed else ("%.1fs" % cooldown if cooldown > 0.0 else "就绪"))
	ultimate_cd_label.text = "选落点" if ultimate_aiming else ("待部署" if not deployed else ("%.1fs" % ultimate_cooldown if ultimate_cooldown > 0.0 else ("就绪" if e_ready else "%d%%" % roundi(energy / maximum * 100.0))))
	skill_cd_label.add_theme_color_override("font_color", Color("#ff9eaa") if cooldown > 0.0 else WHITE)
	ultimate_cd_label.add_theme_color_override("font_color", Color("#f3cd80"))
	skill_key_label.text = "Q 战技"
	ultimate_key_label.text = "E 终极"
	skill_button.disabled = sim.state != "running" or not q_ready
	ultimate_button.disabled = sim.state != "running" or not e_ready
	skill_cooldown_overlay.visible = not q_ready
	ultimate_cooldown_overlay.visible = not e_ready
	var total_cooldown := maxf(0.1, float(sim.hero_ability(selected_id, false).get("cooldown", 1.0)))
	skill_charge.value = clampf(1.0 - cooldown / total_cooldown, 0.0, 1.0) * 100.0 if deployed else 0.0
	ultimate_charge.value = clampf(energy / maximum, 0.0, 1.0) * 100.0
	if selected_id == previous_selection:
		if q_ready and not previous_q_ready: _pop(skill_icon, 0.24)
		if e_ready and not previous_e_ready: _pop(ultimate_icon, 0.24)
	previous_q_ready = q_ready
	previous_e_ready = e_ready

func _ability_info_input(event: InputEvent, ultimate: bool) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_ability_info(ultimate)
		get_viewport().set_input_as_handled()

func skill_icon_for(element: String) -> Texture2D:
	return {"anemo": SKILL_ICON_TORNADO, "electro": SKILL_ICON_LIGHTNING, "pyro": SKILL_ICON_FIRE, "hydro": SKILL_ICON_WATER, "geo": SKILL_ICON_ROCK, "cryo": SKILL_ICON_ICE}.get(element, SKILL_ICON_SLASH)

func ultimate_icon_for(element: String) -> Texture2D:
	return {"anemo": SKILL_ICON_TORNADO, "electro": SKILL_ICON_LASER, "pyro": SKILL_ICON_EXPLOSION, "hydro": SKILL_ICON_WATER, "geo": SKILL_ICON_CRYSTAL, "cryo": SKILL_ICON_TIME}.get(element, SKILL_ICON_EXPLOSION)

func portrait_texture(hero: Dictionary, sim_ref = null) -> Texture2D:
	var character_id := str(hero.get("character_id", ""))
	if portrait_cache.has(character_id): return portrait_cache[character_id]
	if sim_ref != null and sim_ref.database != null:
		var character: Dictionary = sim_ref.database.characters.get(character_id, {})
		var asset: Dictionary = sim_ref.database.assets.get(str(character.get("asset_key", "")), {})
		var portrait_path := str(asset.get("portrait", ""))
		if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
			var portrait_resource: Resource = ResourceLoader.load(portrait_path)
			if portrait_resource is Texture2D:
				portrait_cache[character_id] = portrait_resource
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
	box.corner_radius_top_left = 0
	box.corner_radius_top_right = 9
	box.corner_radius_bottom_left = 5
	box.corner_radius_bottom_right = 0
	box.shadow_color = Color(0, 0, 0, 0.7)
	box.shadow_size = 2 if focused else 0
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
	_buff_scroll_input(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if index >= 0 and index < buff_details.size() and not buff_details[index].is_empty():
			_show_info(str(buff_details[index].get("title", "强化")), str(buff_details[index].get("body", "")))
		get_viewport().set_input_as_handled()

func _show_ability_info(ultimate: bool) -> void:
	if last_sim == null or last_selected_id < 0 or last_selected_id >= last_sim.heroes.size():
		return
	var hero: Dictionary = last_sim.heroes[last_selected_id]
	var data: Dictionary = last_sim.hero_ability(last_selected_id,ultimate)
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
	if kind in ["heal_gust", "healing_surge", "wind_cut", "thread_shelter", "renewing_breeze", "needle_barrage", "arcane_lance", "chimera", "salon_summon", "hydro_fanfare"]:
		effect = str(data.get("description", effect))
	var body_text := "%s · 威力 %d · 范围 %d · 冷却 %.1fs" % [effect, int(data.get("power", 0)), int(data.get("radius", 0)), float(data.get("cooldown", 0.0))]
	if kind == "columbia_tide_ring":
		body_text = "%s · 范围 %d · 冷却 %.1fs" % [str(data.get("description", effect)), int(data.get("radius", 0)), float(data.get("cooldown", 0.0))]
	elif kind == "columbia_tidal_benediction":
		body_text = "%s · 冷却 %.1fs" % [str(data.get("description", effect)), float(data.get("cooldown", 0.0))]
	if kind.begins_with("traveler_"):
		body_text = "%s\n单段威力：%d + %.0f%%攻击力（当前 %.0f）\n范围 %d · 冷却 %.1fs" % [str(data.description),int(data.power),float(data.attack_ratio)*100,(float(data.power)+float(hero.damage)*float(data.attack_ratio))*(1.0+last_sim.skill_power_bonus),int(data.radius),float(data.cooldown)]
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

func announce_deployment(character_name: String) -> void:
	_queue_toast("增援就绪 · %s  /  拖出角色卡部署" % character_name, 1, 4.0)

func _show_deployment_notice(character_name: String) -> void:
	announce_deployment(character_name)

func _meter(parent: Node, rect: Rect2, fill: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.position = rect.position
	# ProgressBar has an inherited theme minimum height even with text hidden.
	# Scale the actual control so the painted bar and hit rectangle stay thin.
	meter.size = Vector2(rect.size.x, 32.0)
	meter.scale.y = rect.size.y / 32.0
	meter.show_percentage = false
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_font_size_override("font_size", 1)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#301521")
	var foreground := StyleBoxFlat.new()
	foreground.bg_color = fill
	meter.add_theme_stylebox_override("background", background)
	meter.add_theme_stylebox_override("fill", foreground)
	parent.add_child(meter)
	return meter

func _pop(control: Control, strength: float) -> void:
	if reduced: return
	control.pivot_offset = control.size * 0.5
	motion_pops[control.get_instance_id()] = {"node": control, "age": 0.0, "strength": strength}

func _queue_toast(copy: String, priority: int, duration: float) -> void:
	var item := {"copy": copy, "priority": priority, "duration": maxf(0.3, duration)}
	if not active_toast.is_empty() and str(active_toast.copy) == copy: return
	for queued in toast_queue:
		if str(queued.copy) == copy: return
	if active_toast.is_empty() or priority > int(active_toast.priority):
		if not active_toast.is_empty() and toast_remaining > 0.8:
			active_toast.duration = toast_remaining
			toast_queue.append(active_toast)
		active_toast = item
		toast_remaining = float(item.duration)
		_pop(contract_notice_label, 0.018)
	else:
		toast_queue.append(item)
	toast_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.priority) > int(b.priority))
	while toast_queue.size() > TOAST_LIMIT: toast_queue.pop_back()
	_update_ticker()

func _update_ticker() -> void:
	if contract_notice == null: return
	contract_notice.visible = last_sim != null and last_sim.state in ["running", "between", "paused"]
	if not active_toast.is_empty():
		contract_notice_label.text = str(active_toast.copy)
		contract_notice_label.add_theme_color_override("font_color", Color("#b5f1cf") if int(active_toast.priority) >= 3 else Color("#edc5b2"))
	elif last_sim != null:
		contract_notice_label.text = "契约 · " + last_sim.contract_status()
		contract_notice_label.add_theme_color_override("font_color", MUTED)
	contract_notice_label.tooltip_text = contract_notice_label.text

func _process(delta: float) -> void:
	if last_sim == null or get_child_count() == 0 or not get_child(0).visible: return
	if last_sim.state not in ["running", "between"]: return
	for i in hero_buttons.size():
		var base: Vector2 = UI_LAYOUT.battle_hero_card_rect.position + UI_LAYOUT.battle_hero_card_gap * i
		var lift := -3.0 if i == last_selected_id or hero_buttons[i].is_hovered() else 0.0
		var goal := base + Vector2(0.0, lift if not reduced else 0.0)
		hero_buttons[i].position = hero_buttons[i].position.lerp(goal, minf(1.0, delta * 17.0)) if not reduced else goal
		if hero_hp_trails[i].value > hero_hp_bars[i].value:
			hero_hp_trails[i].value = move_toward(hero_hp_trails[i].value, hero_hp_bars[i].value, delta * hero_hp_bars[i].max_value * 0.5) if not reduced else hero_hp_bars[i].value
	for id in motion_pops.keys():
		var motion: Dictionary = motion_pops[id]
		var control: Control = motion.node
		if not is_instance_valid(control):
			motion_pops.erase(id)
			continue
		motion.age = float(motion.age) + delta
		var age := float(motion.age)
		if reduced or age > 0.45:
			control.scale = Vector2.ONE
			motion_pops.erase(id)
		else:
			control.scale = Vector2.ONE * (1.0 + sin(age / 0.45 * PI) * exp(-age * 5.0) * float(motion.strength))
	shimmer_remaining = maxf(0.0, shimmer_remaining - delta)
	xp_shimmer.visible = shimmer_remaining > 0.0 and not reduced
	if xp_shimmer.visible:
		xp_shimmer.position.x = xp_bar.position.x + (1.0 - shimmer_remaining / 0.65) * (xp_bar.size.x - xp_shimmer.size.x)
		xp_shimmer.modulate.a = sin(shimmer_remaining / 0.65 * PI)
	if toast_remaining > 0.0:
		toast_remaining -= delta
		if toast_remaining <= 0.0:
			active_toast.clear()
			if not toast_queue.is_empty():
				active_toast = toast_queue.pop_front()
				toast_remaining = float(active_toast.duration)
				_pop(contract_notice_label, 0.018)
			_update_ticker()
	if danger_remaining > 0.0:
		danger_remaining -= delta
		if danger_remaining <= 0.0: boss_skill_warning_panel.hide()
	if arrival_remaining > 0.0:
		arrival_remaining -= delta
		if arrival_remaining <= 0.0:
			boss_alert.hide()
			boss_alert_frame.hide()

func reset_transients() -> void:
	for motion: Dictionary in motion_pops.values():
		if is_instance_valid(motion.node): motion.node.scale = Vector2.ONE
	motion_pops.clear()
	toast_queue.clear()
	active_toast.clear()
	toast_remaining = 0.0
	danger_remaining = 0.0
	arrival_remaining = 0.0
	deployment_queue.clear()
	deployment_notice_active = false
	arena_event_until_ms = 0
	for transient in [deployment_notice, contract_notice, boss_alert, boss_alert_frame, boss_scene_tint, boss_skill_warning_panel, info_popover, xp_shimmer]:
		if is_instance_valid(transient): transient.hide()
	for old_tween in [contract_notice_tween, boss_skill_warning_tween, boss_skill_flash_tween]:
		if old_tween != null and old_tween.is_valid(): old_tween.kill()
	buff_page = 0
	buff_signature = ""
	buff_seen.clear()
	last_xp = -1
	shimmer_remaining = 0.0
	previous_selection = -99
	previous_q_ready = false
	previous_e_ready = false
	last_run_key = ""
	signature = ""
