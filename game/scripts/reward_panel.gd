extends Control
signal chosen(index: int)

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
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer: Label = hud.label(self, UI_LAYOUT.reward_footer_rect.position, UI_LAYOUT.reward_footer_rect.size, "鼠标悬停预览高亮  ·  点击卡牌或按 1 / 2 / 3 选择  ·  强化持续到本局结束", 11, Color("#887c89"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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
	var key := str([sim.run_seed, sim.wave, sim.rewards.history, sim.rewards.offered])
	var opened := not visible
	show()
	if offer_key != key:
		offer_key = key
		if sim.v2_mode:
			heading.text = "水晶 Lv.%d  ·  幸运 %.2f" % [sim.run_state.crystal_level, sim.run_state.luck]
		else:
			heading.text = "节点 %d / 5 已完成  ·  小队 Lv.%d  ·  三项中选择一项  ·  本局种子 %d" % [sim.wave, sim.team_level, sim.run_seed]
		for i in 3:
			_apply_offer(i, sim.rewards.offered[i], sim)
		history_label.text = "已经获得  " + ("尚无强化，这是你的第一次选择。" if sim.rewards.history.is_empty() else "  /  ".join(sim.rewards.history))
	for i in 3:
		buttons[i].focus_next = buttons[(i + 1) % 3].get_path()
		buttons[i].focus_previous = buttons[(i + 2) % 3].get_path()
		buttons[i].focus_neighbor_right = buttons[(i + 1) % 3].get_path()
		buttons[i].focus_neighbor_left = buttons[(i + 2) % 3].get_path()
		buttons[i].focus_neighbor_top = buttons[i].get_path()
		buttons[i].focus_neighbor_bottom = buttons[i].get_path()
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
	tags[index].text = "%02d  /  %s" % [index + 1, _rarity_name(rarity)]
	tags[index].add_theme_color_override("font_color", accent)
	titles[index].text = str(card.get("name", card.get("id", "强化")))
	titles[index].add_theme_color_override("font_color", WHITE if rarity != "genesis" else Color("#fff0bd"))
	title_rules[index].color = accent
	var current := 0
	if sim.v2_mode:
		current = int(sim.run_state.buff_levels.get(card.get("id", ""), 0))
		var target := "全队" if sim.endless_mode else "全队 / 水晶"
		if card.get("target", "global") == "character":
			target = str(card.get("character_id", "角色"))
			for hero: Dictionary in sim.heroes:
				if hero.get("character_id", "") == card.get("character_id", ""):
					target = str(hero.get("name", target))
					break
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
	action_labels[index].text = "选择并继续"
	action_labels[index].add_theme_color_override("font_color", WHITE)
	action_index_labels[index].text = "[%d]" % (index + 1)
	action_index_labels[index].add_theme_color_override("font_color", accent)
	glow_panels[index].add_theme_stylebox_override("panel", _glow_style(accent))

func _focus_card(index: int) -> void:
	if index < 0 or index >= buttons.size():
		return
	var changed := focused_index != index
	focused_index = index
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
	_play(confirm_sound)
	chosen.emit(index)

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
