extends Control
const GeneratedIconCatalog = preload("res://scripts/content/generated_icon_catalog.gd")
const CharacterBreathPreview = preload("res://scripts/character_breath_preview.gd")
signal chosen(index: int, hero_id: int)
signal reroll_requested
const Synergies = preload("res://scripts/rewards/card_synergies.gd")

const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")
const WHITE := Color("#f5f2ec")
const MUTED := Color("#aeb4c2")
const COMPONENT_SHADER := """
shader_type canvas_item;
uniform vec4 accent : source_color = vec4(0.35, 0.7, 1.0, 1.0);
uniform vec4 accent_secondary : source_color = vec4(0.35, 0.7, 1.0, 1.0);
uniform float gradient = 0.0;
void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float light = max(src.r, max(src.g, src.b));
	float edge = smoothstep(0.12, 0.82, light);
	vec3 hue = mix(accent.rgb, accent_secondary.rgb, gradient * UV.x);
	vec3 dark_fill = mix(vec3(0.012, 0.015, 0.026), hue * 0.12, clamp(light * 1.7, 0.0, 1.0));
	vec3 result = mix(dark_fill, hue, edge);
	COLOR = vec4(result, src.a);
}
"""

var current_sim
var reroll_button: Button
var synergy_button: Button
var synergy_hint: Label
var synergy_overlay: ColorRect
var synergy_rows: Array[Label] = []

var buttons: Array[Button] = []
var card_frames: Array[Sprite2D] = []
var glow_panels: Array[Panel] = []
var component_nodes: Array = []
var tags: Array[Label] = []
var titles: Array[Label] = []
var summary_labels: Array[Label] = []
var descriptions: Array[Label] = []
var action_labels: Array[Label] = []
var icons: Array[Sprite2D] = []
var title_rules: Array[ColorRect] = []
var action_index_labels: Array[Label] = []
var rarity_keys: Array[String] = ["common", "common", "common"]
var heading: Label
var history_label: Label
var hover_sound: AudioStreamPlayer
var confirm_sound: AudioStreamPlayer
var component_shader: Shader
var focus_tweens: Dictionary = {}
var focused_index := -1
var offer_key := ""
var target_overlay: ColorRect
var target_heading: Label
var target_buttons: Array[Button] = []
var target_previews: Array[Control] = []
var target_name_labels: Array[Label] = []
var target_hp_labels: Array[Label] = []
var target_card_index := -1

func build(hud) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	component_shader = Shader.new()
	component_shader.code = COMPONENT_SHADER

	var background := TextureRect.new()
	background.texture = UI_SKIN.reward_background
	background.position = UI_LAYOUT.reward_background_rect.position
	background.size = UI_LAYOUT.reward_background_rect.size
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.016, 0.012, 0.023, 0.91)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var header_glow := ColorRect.new()
	header_glow.position = UI_LAYOUT.reward_header_rect.position
	header_glow.size = UI_LAYOUT.reward_header_rect.size
	header_glow.color = Color(0.12, 0.018, 0.05, 0.18)
	header_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_glow)
	hud.label(self, Vector2(96, 40), Vector2(1088, 20), "R I F T   G U A R D     /     战 地 补 给", 13, Color("#e9a5ad"))
	hud.bind(hud.label(self, Vector2(92, 72), Vector2(920, 38), "选择这一次的突破", 28, WHITE), "reward_title")
	heading = hud.label(self, Vector2(96, 154), Vector2(1088, 18), "", 11, MUTED)

	for i in 3:
		_build_card(hud, i)

	history_label = hud.label(self, UI_LAYOUT.reward_history_rect.position, UI_LAYOUT.reward_history_rect.size, "", 13, Color("#c2b4bf"))
	history_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	history_label.max_lines_visible = 1
	history_label.clip_text = true
	history_label.size = UI_LAYOUT.reward_history_rect.size
	var footer: Label = hud.label(self, UI_LAYOUT.reward_footer_rect.position, UI_LAYOUT.reward_footer_rect.size, "鼠标悬停预览高亮  ·  点击卡牌或按 1 / 2 / 3 选择  ·  强化持续到本局结束", 11, Color("#887c89"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_reward_tools(hud)
	_build_target_picker(hud)

	hover_sound = AudioStreamPlayer.new()
	hover_sound.stream = preload("res://assets/helltaker/audio/button_dialogue_highlight_01.wav")
	hover_sound.bus = "SFX"
	hover_sound.volume_db = -6.0
	add_child(hover_sound)
	confirm_sound = AudioStreamPlayer.new()
	confirm_sound.stream = preload("res://assets/helltaker/audio/button_dialogue_confirm_01.wav")
	confirm_sound.bus = "SFX"
	confirm_sound.volume_db = -3.0
	add_child(confirm_sound)
	hide()

func _build_card(hud, index: int) -> void:
	var rect := Rect2(UI_LAYOUT.reward_grid_origin + Vector2(index * (UI_LAYOUT.reward_card_size.x + UI_LAYOUT.reward_card_gap.x), 0), UI_LAYOUT.reward_card_size)
	var card: Button = hud.button(self, rect, "", false)
	hud.bind(card, "reward_card_%d" % (index + 1))
	card.position = rect.position
	card.size = rect.size
	card.pivot_offset = rect.size * 0.5
	card.clip_contents = true
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	buttons.append(card)

	var glow := Panel.new()
	glow.position = Vector2(-5, -5)
	glow.size = rect.size + Vector2(10, 10)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.hide()
	card.add_child(glow)
	glow_panels.append(glow)

	var frame: Sprite2D = _scaled_sprite(card, UI_SKIN.reward_frame_common, Rect2(Vector2.ZERO, rect.size))
	frame.z_index = 20
	card_frames.append(frame)

	component_nodes.append([])
	_add_component(card, UI_SKIN.reward_component_icon_slot, UI_LAYOUT.reward_icon_slot_rect, index)
	_add_component(card, UI_SKIN.reward_component_summary, UI_LAYOUT.reward_preview_rect, index)
	_add_component(card, UI_SKIN.reward_component_detail, UI_LAYOUT.reward_description_rect, index)
	_add_component(card, UI_SKIN.reward_component_action, UI_LAYOUT.reward_action_rect, index)

	var tag: Label = hud.label(card, UI_LAYOUT.reward_tag_rect.position, UI_LAYOUT.reward_tag_rect.size, "", 10, WHITE)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tags.append(tag)
	var title: Label = hud.label(card, UI_LAYOUT.reward_title_rect.position, UI_LAYOUT.reward_title_rect.size, "", 19, WHITE)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titles.append(title)
	var title_rule := ColorRect.new()
	title_rule.position = Vector2(35, 111)
	title_rule.size = Vector2(136, 2)
	title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title_rule)
	title_rules.append(title_rule)

	var icon: Sprite2D = _scaled_sprite(card, UI_SKIN.reward_icon_summon_crystal, UI_LAYOUT.reward_icon_rect)
	icons.append(icon)

	var summary: Label = hud.label(card, UI_LAYOUT.reward_preview_rect.position + Vector2(12, 6), UI_LAYOUT.reward_preview_rect.size - Vector2(24, 12), "", 11, WHITE)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.clip_text = true
	summary.max_lines_visible = 2
	summary_labels.append(summary)
	var description: Label = hud.label(card, UI_LAYOUT.reward_description_rect.position + Vector2(12, 10), UI_LAYOUT.reward_description_rect.size - Vector2(24, 20), "", 11, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descriptions.append(description)
	var action: Label = hud.label(card, UI_LAYOUT.reward_action_rect.position + Vector2(12, 5), Vector2(170, UI_LAYOUT.reward_action_rect.size.y - 10), "选择并继续", 11, WHITE)
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_labels.append(action)
	var action_index: Label = hud.label(card, UI_LAYOUT.reward_action_rect.position + Vector2(184, 5), Vector2(36, UI_LAYOUT.reward_action_rect.size.y - 10), "", 12, WHITE)
	action_index.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action_index.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_index_labels.append(action_index)

	card.focus_entered.connect(_focus_card.bind(index))
	card.mouse_entered.connect(func(): card.grab_focus())
	card.pressed.connect(_commit_choice.bind(index))

func _add_component(card: Button, texture: Texture2D, rect: Rect2, index: int) -> void:
	var component: Sprite2D = _scaled_sprite(card, texture, rect)
	component_nodes[index].append(component)

func _scaled_sprite(parent: CanvasItem, texture: Texture2D, rect: Rect2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = rect.position
	var texture_size := texture.get_size()
	var uniform_scale := minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	sprite.scale = Vector2.ONE * uniform_scale
	parent.add_child(sprite)
	return sprite

func display(sim) -> void:
	current_sim = sim
	reroll_button.visible = sim.v2_mode
	synergy_button.visible = sim.v2_mode
	synergy_hint.visible = sim.v2_mode
	if sim.v2_mode:
		reroll_button.text = "刷新 %d/2  [R]" % sim.rewards.rerolls_left
		reroll_button.disabled = sim.rewards.rerolls_left <= 0 or target_overlay.visible
	var key := (str(sim.rewards.offer_revision) if sim.v2_mode else "") + str([sim.run_seed, sim.wave, sim.rewards.history, sim.rewards.offered])
	var opened := not visible
	show()
	if offer_key != key:
		close_target_picker()
		synergy_overlay.hide()
		offer_key = key
		if sim.v2_mode:
			heading.text = "任务完成 · 连续三次选卡 · 第 %d / 3 次" % (4-sim.expedition.cards_remaining) if sim.endless_mode and sim.expedition.cards_remaining>0 else "水晶 Lv.%d  ·  幸运 %.2f" % [sim.run_state.crystal_level, sim.run_state.luck]
		else:
			heading.text = "节点 %d / 5 已完成  ·  小队 Lv.%d  ·  三项中选择一项  ·  本局种子 %d" % [sim.wave, sim.team_level, sim.run_seed]
		for i in 3:
			buttons[i].visible = i < sim.rewards.offered.size()
			if buttons[i].visible:
				_apply_offer(i, sim.rewards.offered[i], sim)
		history_label.text = "已经获得  " + ("尚无强化，这是你的第一次选择。" if sim.rewards.history.is_empty() else "  /  ".join(sim.rewards.history))
	for i in 3:
		buttons[i].focus_next = buttons[(i + 1) % 3].get_path()
		buttons[i].focus_previous = buttons[(i + 2) % 3].get_path()
		buttons[i].focus_neighbor_right = buttons[(i + 1) % 3].get_path()
		buttons[i].focus_neighbor_left = buttons[(i + 2) % 3].get_path()
		buttons[i].focus_neighbor_top = buttons[i].get_path()
		buttons[i].focus_neighbor_bottom = buttons[i].get_path()
	_update_synergy_hint()
	if opened:
		focused_index = -1
		buttons[0].grab_focus()
		_focus_card(0)

func _apply_offer(index: int, card: Dictionary, sim) -> void:
	var rarity := _normalize_rarity(str(card.get("rarity", "common")))
	rarity_keys[index] = rarity
	var accent := _rarity_color(rarity)
	var accent_secondary := _rarity_secondary(rarity)
	card_frames[index].texture = _rarity_frame(rarity)
	var tint_material := _component_material(accent, accent_secondary, rarity == "genesis")
	for component: Sprite2D in component_nodes[index]:
		component.material = tint_material
	icons[index].texture = _icon_for(card)
	var icon_size := icons[index].texture.get_size()
	var icon_bounds: Rect2 = UI_LAYOUT.reward_icon_rect
	var icon_scale := minf(icon_bounds.size.x / icon_size.x, icon_bounds.size.y / icon_size.y)
	icons[index].scale = Vector2.ONE * icon_scale
	icons[index].position = icon_bounds.position + (icon_bounds.size - icon_size * icon_scale) * 0.5
	tags[index].text = "%02d  /  %s" % [index + 1, _rarity_name(rarity)]
	tags[index].add_theme_color_override("font_color", accent)
	titles[index].text = str(card.get("name", card.get("id", "强化")))
	titles[index].add_theme_color_override("font_color", WHITE if rarity != "genesis" else Color("#fff0bd"))
	title_rules[index].color = accent
	var current := 0
	if sim.v2_mode:
		current = int(sim.run_state.buff_levels.get(card.get("id", ""), 0))
		var target := "全队" if sim.endless_mode else "全队 / 水晶"
		if str(card.get("effect", "")) == "assign_traveler_element":
			target = "旅行者"
		elif card.get("target", "global") == "character":
			target = "选定角色"
		tags[index].text = "%02d / %s · %s" % [index + 1, target, _rarity_name(rarity)]
		summary_labels[index].text = sim.rewards.preview(card, sim)
		var card_description := str(card.get("description", "获得强化"))
		if sim.endless_mode:
			card_description = card_description.replace("并修复水晶", "").replace("水晶", "旅行者")
		descriptions[index].text = card_description + "\n\n当前层数 %d / ∞" % current
	else:
		var target := str(sim.heroes[card.target].name) if int(card.get("target", -1)) >= 0 else "全队 / 基地"
		current = int(sim.rewards.levels.get(card.get("id", ""), 0))
		tags[index].text = "%02d / %s · %s" % [index + 1, target, str(card.get("tag", _rarity_name(rarity)))]
		summary_labels[index].text = sim.rewards.preview(card, sim)
		descriptions[index].text = str(card.get("desc", "获得强化")) + ("\n\n当前层数 %d / %d" % [current, int(card.get("max", 0))] if int(card.get("max", 0)) > 0 and int(card.get("max", 0)) < 99 else "")
	action_labels[index].text = "选择角色" if sim.v2_mode and card.get("target", "global") == "character" else "选择并继续"
	action_labels[index].add_theme_color_override("font_color", WHITE)
	action_index_labels[index].text = "[%d]" % (index + 1)
	action_index_labels[index].add_theme_color_override("font_color", accent)
	glow_panels[index].add_theme_stylebox_override("panel", _glow_style(accent))

func _focus_card(index: int) -> void:
	if index < 0 or index >= buttons.size():
		return
	var changed := focused_index != index
	focused_index = index
	_update_synergy_hint()
	if changed and visible:
		_play(hover_sound)
	for i in buttons.size():
		var selected := i == index
		if focus_tweens.has(i):
			var old_tween: Tween = focus_tweens[i]
			if old_tween != null and old_tween.is_valid():
				old_tween.kill()
		var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		focus_tweens[i] = tween
		tween.tween_property(buttons[i], "scale", Vector2.ONE * (1.045 if selected else 0.965), 0.13)
		tween.tween_property(buttons[i], "modulate", Color(0.82, 0.82, 0.84, 1.0) if selected else Color(0.50, 0.50, 0.54, 0.88), 0.13)
		buttons[i].z_index = 3 if selected else i
		glow_panels[i].visible = false

func _commit_choice(index: int) -> void:
	if target_overlay.visible or synergy_overlay.visible:
		return
	_play(confirm_sound)
	chosen.emit(index, -1)

func _build_target_picker(hud) -> void:
	target_overlay = ColorRect.new()
	target_overlay.color = Color("#0b1020")
	target_overlay.z_index = 100
	target_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(target_overlay)
	var panel := Panel.new()
	panel.position = Vector2(122, 112)
	panel.size = Vector2(1036, 500)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#101522")
	frame.border_color = Color("#e55569")
	frame.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", frame)
	target_overlay.add_child(panel)
	target_heading = hud.label(panel, Vector2(54, 28), Vector2(928, 40), "选择强化目标", 25, WHITE)
	target_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 3:
		var button: Button = hud.button(panel, Rect2(50 + i * 323, 94, 290, 330), "", false)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.clip_contents = true
		var preview: Control = CharacterBreathPreview.new()
		preview.transparent_background = true
		preview.position = UI_LAYOUT.battle_reward_target_portrait_rect.position
		preview.size = UI_LAYOUT.battle_reward_target_portrait_rect.size
		button.add_child(preview)
		target_previews.append(preview)
		var name_label: Label = hud.label(button, UI_LAYOUT.battle_reward_target_name_rect.position, UI_LAYOUT.battle_reward_target_name_rect.size, "", 18, WHITE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		target_name_labels.append(name_label)
		var hp_label: Label = hud.label(button, UI_LAYOUT.battle_reward_target_stats_rect.position, UI_LAYOUT.battle_reward_target_stats_rect.size, "", 12, MUTED)
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		target_hp_labels.append(hp_label)
		button.pressed.connect(_pick_target.bind(i))
		button.mouse_entered.connect(func(): _play(hover_sound); button.modulate = Color(1.16, 1.16, 1.16))
		button.mouse_exited.connect(func(): button.modulate = Color.WHITE)
		target_buttons.append(button)
	var back: Button = hud.button(panel, Rect2(410, 445, 216, 42), "返回卡牌", false)
	back.pressed.connect(close_target_picker)
	target_overlay.hide()

func show_target_picker(index: int, sim) -> void:
	if index < 0 or index >= sim.rewards.offered.size():
		return
	target_card_index = index
	target_heading.text = "选择「%s」的目标角色" % str(sim.rewards.offered[index].get("name", "强化"))
	for i in target_buttons.size():
		var exists: bool = i < sim.heroes.size()
		target_buttons[i].visible = exists
		if not exists:
			continue
		var hero: Dictionary = sim.heroes[i]
		var character_id := str(hero.get("character_id", ""))
		var character: Dictionary = sim.database.characters.get(character_id, {})
		var asset: Dictionary = sim.database.assets.get(str(character.get("asset_key", "")), {})
		var element := str(character.get("element", "none"))
		var color: Color = {"hydro":Color("#70bdff"),"pyro":Color("#ff785f"),"anemo":Color("#7bdec6"),"cryo":Color("#a4e4fa"),"electro":Color("#d49aff"),"geo":Color("#e3bd71")}.get(element, Color("#f4d9ad"))
		target_previews[i].configure(character_id, asset, color, false)
		target_name_labels[i].text = "%d  %s" % [i + 1, str(hero.get("name", "角色"))]
		target_name_labels[i].add_theme_color_override("font_color", color)
		target_hp_labels[i].text = "HP %d / %d" % [int(hero.get("hp", 0)), int(hero.get("max_hp", 0))]
		var benefit := preload("res://scripts/card_benefit_preview.gd").hero_lines(sim.rewards.offered[index], hero)
		target_hp_labels[i].text += "\n" + (benefit if not benefit.is_empty() else sim.rewards.preview(sim.rewards.offered[index],sim))
		target_hp_labels[i].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		target_buttons[i].tooltip_text = Synergies.preview(sim.rewards.offered[index], sim, i)
	reroll_button.disabled = true
	target_overlay.show()
	for button: Button in target_buttons:
		if button.visible:
			button.grab_focus()
			break

func close_target_picker() -> void:
	target_overlay.hide()
	target_card_index = -1
	if current_sim != null and current_sim.v2_mode:
		reroll_button.disabled = current_sim.rewards.rerolls_left <= 0
	if visible and not buttons.is_empty():
		buttons[0].grab_focus()

func _pick_target(hero_id: int) -> void:
	if not target_overlay.visible or hero_id < 0 or hero_id >= target_buttons.size() or not target_buttons[hero_id].visible:
		return
	_play(confirm_sound)
	var picked_card := target_card_index
	target_overlay.hide()
	target_card_index = -1
	chosen.emit(picked_card, hero_id)

func _component_material(accent: Color, secondary: Color, use_gradient: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = component_shader
	material.set_shader_parameter("accent", accent)
	material.set_shader_parameter("accent_secondary", secondary)
	material.set_shader_parameter("gradient", 1.0 if use_gradient else 0.0)
	return material

func _glow_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.012)
	style.border_color = Color(accent, 0.55)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(accent, 0.45)
	style.shadow_size = 12
	return style

func _normalize_rarity(rarity: String) -> String:
	if rarity in ["mythic", "genesis"]:
		return "genesis"
	if rarity in ["common", "rare", "epic", "legendary"]:
		return rarity
	return "common"

func _rarity_name(rarity: String) -> String:
	return {"common":"普通", "rare":"稀有", "epic":"史诗", "legendary":"传奇", "genesis":"创世"}.get(rarity, "普通")

func _rarity_color(rarity: String) -> Color:
	return {"common":Color("#d9dee3"), "rare":Color("#3c91c7"), "epic":Color("#a64bc4"), "legendary":Color("#d28a35"), "genesis":Color("#58bec8")}.get(rarity, Color("#eef3f8"))

func _rarity_secondary(rarity: String) -> Color:
	return Color("#c95f91") if rarity == "genesis" else _rarity_color(rarity)

func _rarity_frame(rarity: String) -> Texture2D:
	return {
		"common":UI_SKIN.reward_frame_common,
		"rare":UI_SKIN.reward_frame_rare,
		"epic":UI_SKIN.reward_frame_epic,
		"legendary":UI_SKIN.reward_frame_legendary,
		"genesis":UI_SKIN.reward_frame_genesis
	}.get(rarity, UI_SKIN.reward_frame_common)

func _icon_for(card: Dictionary) -> Texture2D:
	var generated := GeneratedIconCatalog.card_texture(card)
	if generated != null:
		return generated
	var effect := str(card.get("effect", ""))
	if effect in ["assign_traveler_element", "element_technique"]:
		var element := str(card.get("requires_element", card.get("value", "")))
		return _element_icon(element)
	return {
		"attack_multiplier":UI_SKIN.reward_icon_sword_slash,
		"squad_attack_multiplier":UI_SKIN.reward_icon_sword_slash,
		"health_multiplier":UI_SKIN.reward_icon_healing_heart,
		"squad_health_multiplier":UI_SKIN.reward_icon_healing_heart,
		"attack_rate_multiplier":UI_SKIN.reward_icon_arrow_rain,
		"lethal_tempo":UI_SKIN.reward_icon_arrow_rain,
		"conqueror":UI_SKIN.reward_icon_sword_slash,
		"heartsteel":UI_SKIN.reward_icon_healing_heart,
		"warmogs_armor":UI_SKIN.reward_icon_healing_heart,
		"solo_leveling":UI_SKIN.reward_icon_summon_crystal,
		"squad_rate_multiplier":UI_SKIN.reward_icon_arrow_rain,
		"range_flat":UI_SKIN.reward_icon_laser,
		"squad_range_flat":UI_SKIN.reward_icon_laser,
		"armor_flat":UI_SKIN.reward_icon_shield,
		"squad_armor_flat":UI_SKIN.reward_icon_shield,
		"move_speed_flat":UI_SKIN.reward_icon_speed_boot,
		"element_mastery_flat":UI_SKIN.reward_icon_summon_crystal,
		"squad_mastery_flat":UI_SKIN.reward_icon_summon_crystal,
		"special_upgrade":UI_SKIN.reward_icon_explosion,
		"signature_upgrade":UI_SKIN.reward_icon_summon_crystal,
		"reaction_bonus":UI_SKIN.reward_icon_explosion,
		"reaction_overdrive":UI_SKIN.reward_icon_explosion,
		"crystal_health_flat":UI_SKIN.reward_icon_summon_crystal,
		"crystal_heal":UI_SKIN.reward_icon_healing_heart,
		"crit_flat":UI_SKIN.reward_icon_sword_slash,
		"squad_crit_flat":UI_SKIN.reward_icon_sword_slash,
		"squad_chain":UI_SKIN.reward_icon_lightning,
		"last_stand":UI_SKIN.reward_icon_shield
	}.get(effect, UI_SKIN.reward_icon_summon_crystal)

func _element_icon(element: String) -> Texture2D:
	return {
		"pyro":UI_SKIN.reward_icon_fireball,
		"hydro":UI_SKIN.reward_icon_water_ring,
		"electro":UI_SKIN.reward_icon_lightning,
		"cryo":UI_SKIN.reward_icon_ice_shard,
		"anemo":UI_SKIN.reward_icon_tornado,
		"geo":UI_SKIN.reward_icon_rock_meteor
	}.get(element, UI_SKIN.reward_icon_summon_crystal)

func _play(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.stop()
	player.play()

func _build_reward_tools(hud) -> void:
	reroll_button = hud.button(self, UI_LAYOUT.battle_reward_reroll_rect, "刷新 2/2  [R]", false)
	reroll_button.pressed.connect(request_reroll)
	reroll_button.tooltip_text = "每轮免费刷新2次；尽量避开本轮已见卡牌，不消耗选卡机会。"
	synergy_button = hud.button(self, UI_LAYOUT.battle_reward_synergy_button_rect, "联动图鉴", false)
	synergy_button.pressed.connect(show_synergies)
	synergy_hint = hud.label(self, UI_LAYOUT.battle_reward_synergy_preview_rect.position, UI_LAYOUT.battle_reward_synergy_preview_rect.size, "", 12, Color("#85e6cd"))
	synergy_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	synergy_hint.clip_text = true
	synergy_hint.max_lines_visible = 2
	synergy_hint.size = UI_LAYOUT.battle_reward_synergy_preview_rect.size
	synergy_overlay = ColorRect.new()
	synergy_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	synergy_overlay.color = Color(0.015, 0.018, 0.045, 0.98)
	synergy_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	synergy_overlay.z_index = 110
	add_child(synergy_overlay)
	var area: Rect2 = UI_LAYOUT.battle_reward_synergy_overlay_rect
	hud.label(synergy_overlay, area.position + Vector2(20, 8), Vector2(780, 34), "卡牌联动 · 每组只激活一次", 24, WHITE)
	hud.label(synergy_overlay, area.position + Vector2(20, 48), Vector2(850, 24), "角色联动需由同一角色持有两张卡；全队联动可由不同角色持有。", 14, MUTED)
	var close_button: Button = hud.button(synergy_overlay, Rect2(area.end - Vector2(172, area.size.y - 8), Vector2(152, 34)), "返回选卡 [Esc]", false)
	close_button.pressed.connect(close_synergies)
	for index in Synergies.RECIPES.size():
		var row: Label = hud.label(synergy_overlay, area.position + Vector2(20, 88 + index * 64), Vector2(area.size.x - 40, 60), "", 14, WHITE)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.clip_text = true
		synergy_rows.append(row)
	synergy_overlay.hide()

func request_reroll() -> void:
	if not visible or target_overlay.visible or synergy_overlay.visible or reroll_button.disabled:
		return
	_play(confirm_sound)
	reroll_requested.emit()

func _update_synergy_hint() -> void:
	if current_sim == null or not current_sim.v2_mode: return
	var index := maxi(0, focused_index)
	if index < current_sim.rewards.offered.size():
		synergy_hint.text = Synergies.preview(current_sim.rewards.offered[index], current_sim)

func show_synergies() -> void:
	if current_sim == null or not current_sim.v2_mode or target_overlay.visible: return
	for index in Synergies.RECIPES.size():
		var recipe: Dictionary = Synergies.RECIPES[index]
		var state := Synergies.status(recipe, current_sim)
		synergy_rows[index].text = "%s  ·  %s  +  %s  [%s]\n%s" % [recipe.name, recipe.names[0], recipe.names[1], state, recipe.description]
		synergy_rows[index].add_theme_color_override("font_color", Color("#85e6cd") if state.begins_with("已激活") else WHITE)
	synergy_overlay.show()

func close_synergies() -> void:
	synergy_overlay.hide()
	if not buttons.is_empty(): buttons[maxi(0, focused_index)].grab_focus()
