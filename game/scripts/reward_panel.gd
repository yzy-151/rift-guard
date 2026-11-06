extends Control
const GeneratedIconCatalog = preload("res://scripts/content/generated_icon_catalog.gd")
const CharacterBreathPreview = preload("res://scripts/character_breath_preview.gd")
signal chosen(index: int, hero_id: int)
signal reroll_requested
const Synergies = preload("res://scripts/rewards/card_synergies.gd")
const POSTER = preload("res://scripts/poster_surface.gd")
const MOTION = preload("res://scripts/poster_motion.gd")
const CARD_ART = preload("res://scripts/reward_card_art.gd")
const BACKDROP_ART = preload("res://scripts/reward_poster_backdrop.gd")

const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")
const WHITE := Color("#f5f2ec")
const MUTED := Color("#aeb4c2")
var current_sim
var reroll_button: Button
var synergy_button: Button
var synergy_hint: Label
var synergy_overlay: ColorRect
var synergy_rows: Array[Label] = []

var buttons: Array[Button] = []
var card_bodies: Array[Control] = []
var card_art: Array[Control] = []
var tags: Array[Label] = []
var rarity_badges: Array[Label] = []
var titles: Array[Label] = []
var summary_labels: Array[Label] = []
var descriptions: Array[Label] = []
var action_labels: Array[Label] = []
var icons: Array[Sprite2D] = []
var action_index_labels: Array[Label] = []
var rarity_keys: Array[String] = ["common", "common", "common"]
var heading: Label
var history_label: Label
var hover_sound: AudioStreamPlayer
var confirm_sound: AudioStreamPlayer
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
var header_group: Control
var footer_group: Control
var target_panel: Control
var target_back: Button
var reduced_motion := false
var opening_serial := 0
var owner_hud

func build(hud) -> void:
	owner_hud = hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	reduced_motion = bool(hud.reduced)
	var backdrop: Control = BACKDROP_ART.new()
	backdrop.position = UI_LAYOUT.reward_background_rect.position
	backdrop.size = UI_LAYOUT.reward_background_rect.size
	add_child(backdrop)
	header_group = Control.new()
	header_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_group)
	_poster_label(hud, header_group, UI_LAYOUT.battle_reward_brand_rect, "战地补给  /  PICK ONE. GET LOUD.", 14, POSTER.PAPER)
	var title: Label = _poster_label(hud, header_group, UI_LAYOUT.battle_reward_heading_rect, "挑一张，开点挂。", 34, POSTER.PAPER)
	title.add_theme_color_override("font_outline_color", POSTER.INK)
	title.add_theme_constant_override("outline_size", 5)
	hud.bind(title, "reward_title")
	# The semantic profile owns this rebuilt surface even with old CSV overrides.
	title.position = UI_LAYOUT.battle_reward_heading_rect.position
	title.size = UI_LAYOUT.battle_reward_heading_rect.size
	title.text = "挑一张，开点挂。"
	title.add_theme_font_size_override("font_size", 34)
	heading = _poster_label(hud, header_group, UI_LAYOUT.battle_reward_status_rect, "", 15, POSTER.PAPER)

	for i in 3:
		_build_card(hud, i)

	footer_group = Control.new()
	footer_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer_group)
	history_label = _poster_label(hud, footer_group, UI_LAYOUT.reward_history_rect, "", 14, POSTER.PAPER)
	history_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	history_label.max_lines_visible = 1
	history_label.clip_text = true
	history_label.size = UI_LAYOUT.reward_history_rect.size
	var footer: Label = _poster_label(hud, footer_group, UI_LAYOUT.reward_footer_rect, "点击整张卡牌或按 1 / 2 / 3 选择  ·  强化持续到本局结束", 14, Color("#c3beb7"))
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
	visibility_changed.connect(_visibility_changed)
	hide()

func _poster_label(hud, parent: Node, rect: Rect2, copy: String, font_size: int, color: Color) -> Label:
	var result: Label = hud.label(parent, rect.position, rect.size, copy, font_size, color)
	result.add_theme_font_override("font", POSTER.TYPE)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _build_card(hud, index: int) -> void:
	var rect := Rect2(UI_LAYOUT.reward_grid_origin + Vector2(index * (UI_LAYOUT.reward_card_size.x + UI_LAYOUT.reward_card_gap.x), 0), UI_LAYOUT.reward_card_size)
	var card: Button = hud.button(self, rect, "", false)
	hud.bind(card, "reward_card_%d" % (index + 1))
	card.position = rect.position
	card.size = rect.size
	card.pivot_offset = rect.size * 0.5
	card.clip_contents = false
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	buttons.append(card)

	var body := Control.new()
	body.size = rect.size
	body.pivot_offset = body.size * 0.5
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)
	card_bodies.append(body)
	var art: Control = CARD_ART.new()
	art.size = body.size
	body.add_child(art)
	card_art.append(art)
	var tag: Label = _poster_label(hud, body, UI_LAYOUT.reward_tag_rect, "", 13, POSTER.INK)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.clip_text = true
	tags.append(tag)
	var badge: Label = _poster_label(hud, body, UI_LAYOUT.battle_reward_rarity_badge_rect, "", 16, POSTER.INK)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.clip_text = true
	rarity_badges.append(badge)
	var title: Label = _poster_label(hud, body, UI_LAYOUT.reward_title_rect, "", 25, POSTER.PAPER)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	titles.append(title)
	var icon: Sprite2D = _scaled_sprite(body, UI_SKIN.reward_icon_summon_crystal, UI_LAYOUT.reward_icon_rect)
	icons.append(icon)

	var summary: Label = _poster_label(hud, body, Rect2(UI_LAYOUT.reward_preview_rect.position + Vector2(7, 3), UI_LAYOUT.reward_preview_rect.size - Vector2(14, 6)), "", 17, POSTER.PAPER)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.clip_text = true
	summary.max_lines_visible = 2
	summary_labels.append(summary)
	var description: Label = _poster_label(hud, body, UI_LAYOUT.reward_description_rect, "", 14, POSTER.INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 3
	description.clip_text = true
	descriptions.append(description)
	var action: Label = _poster_label(hud, body, Rect2(UI_LAYOUT.reward_action_rect.position + Vector2(8, 0), Vector2(UI_LAYOUT.reward_action_rect.size.x - 64, UI_LAYOUT.reward_action_rect.size.y)), "就这张  /  TAKE IT", 17, POSTER.PAPER)
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_labels.append(action)
	var action_index: Label = _poster_label(hud, body, Rect2(UI_LAYOUT.reward_action_rect.end - Vector2(51, UI_LAYOUT.reward_action_rect.size.y), Vector2(42, UI_LAYOUT.reward_action_rect.size.y)), "", 18, POSTER.PAPER)
	action_index.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action_index.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_index_labels.append(action_index)

	card.focus_entered.connect(_focus_card.bind(index))
	card.mouse_entered.connect(func(): card.grab_focus())
	card.pressed.connect(_commit_choice.bind(index))

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
	var key := _offer_identity(sim)
	var opened := not visible
	var changed := offer_key != key
	show()
	if changed:
		close_target_picker()
		synergy_overlay.hide()
		offer_key = key
		if sim.v2_mode:
			heading.text = "任务奖励 · 第 %d / %d 次选卡" % [sim.expedition.cards_total-sim.expedition.cards_remaining+1, sim.expedition.cards_total] if sim.endless_mode and sim.expedition.cards_remaining>0 else "水晶 Lv.%d  ·  幸运 %.2f" % [sim.run_state.crystal_level, sim.run_state.luck]
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
	if opened or changed:
		focused_index = -1
		buttons[0].grab_focus()
		_focus_card(0)
		_enter()

func _offer_identity(sim) -> String:
	# Preview writes the displayed gain back into offer descriptions. Those
	# cosmetic fields must never restart the entrance of the same dealt cards.
	var cards: Array = []
	for card: Dictionary in sim.rewards.offered:
		cards.append([str(card.get("id", "")), int(card.get("next_level", 0)), card.get("target", -1)])
	var revision: int = int(sim.rewards.offer_revision) if sim.v2_mode else sim.rewards.history.size()
	return str([sim.rewards.get_instance_id(), sim.run_seed, sim.wave, revision, cards])

func _enter() -> void:
	opening_serial += 1
	reduced_motion = bool(owner_hud.reduced)
	var items: Array[Dictionary] = [{"node":header_group,"offset":Vector2(-58,0),"delay":0.0,"scale":1.0}]
	for index in buttons.size():
		if buttons[index].visible:
			items.append({"node":buttons[index],"offset":Vector2(0,64),"delay":0.035 + index * 0.055,"scale":0.97})
	items.append({"node":footer_group,"offset":Vector2(0,19),"delay":0.10,"scale":1.0})
	MOTION.enter(self, items, reduced_motion)

func _visibility_changed() -> void:
	if visible: return
	MOTION.reset(self)
	MOTION.reset(target_overlay)
	for index in card_bodies.size():
		if focus_tweens.has(index):
			var tween: Tween = focus_tweens[index]
			if tween != null and tween.is_valid(): tween.kill()
		card_bodies[index].position = Vector2.ZERO
		card_bodies[index].scale = Vector2.ONE
		descriptions[index].modulate = Color.WHITE
	focus_tweens.clear()
	if target_overlay != null: target_overlay.hide()
	if synergy_overlay != null: synergy_overlay.hide()
	target_card_index = -1

func _apply_offer(index: int, card: Dictionary, sim) -> void:
	var rarity := _normalize_rarity(str(card.get("rarity", "common")))
	rarity_keys[index] = rarity
	var accent := _rarity_color(rarity)
	card_art[index].accent = accent
	card_art[index].rarity = rarity
	card_art[index].queue_redraw()
	rarity_badges[index].text = "%s · %s" % [_rarity_name(rarity), {"common":"I", "rare":"II", "epic":"III", "legendary":"IV", "genesis":"V"}.get(rarity, "I")]
	rarity_badges[index].add_theme_color_override("font_color", POSTER.INK)
	icons[index].texture = _icon_for(card)
	var icon_size := icons[index].texture.get_size()
	var icon_bounds: Rect2 = UI_LAYOUT.reward_icon_rect
	var icon_scale := minf(icon_bounds.size.x / icon_size.x, icon_bounds.size.y / icon_size.y)
	icons[index].scale = Vector2.ONE * icon_scale
	icons[index].position = icon_bounds.position + (icon_bounds.size - icon_size * icon_scale) * 0.5
	tags[index].text = "%02d  /  %s" % [index + 1, _rarity_name(rarity)]
	tags[index].add_theme_color_override("font_color", POSTER.INK)
	titles[index].text = str(card.get("name", card.get("id", "强化")))
	titles[index].add_theme_color_override("font_color", POSTER.PAPER if rarity != "genesis" else POSTER.YELLOW)
	var title_font := 25
	while POSTER.TYPE.get_string_size(titles[index].text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font).x > titles[index].size.x and title_font > 18:
		title_font -= 1
	titles[index].add_theme_font_size_override("font_size", title_font)
	var current := 0
	if sim.v2_mode:
		current = int(sim.run_state.buff_levels.get(card.get("id", ""), 0))
		var target := "全队" if sim.endless_mode else "全队 / 水晶"
		if str(card.get("family", "")) == "device":
			target = "机关"
		elif str(card.get("effect", "")) == "assign_traveler_element":
			target = "旅行者"
		elif card.get("target", "global") == "character":
			target = "选定角色"
		tags[index].text = "%02d / %s · %s" % [index + 1, target, _rarity_name(rarity)]
		summary_labels[index].text = sim.rewards.preview(card, sim)
		var card_description := str(card.get("description", "获得强化"))
		if sim.endless_mode:
			card_description = card_description.replace("并修复水晶", "").replace("水晶", "旅行者")
		var stack_limit := str(int(card.get("max_stacks", 1)))
		descriptions[index].text = card_description
		tags[index].text = "%s  Lv.%d / %s" % [target, current, stack_limit]
	else:
		var target := str(sim.heroes[card.target].name) if int(card.get("target", -1)) >= 0 else "全队 / 基地"
		current = int(sim.rewards.levels.get(card.get("id", ""), 0))
		tags[index].text = "%02d / %s · %s" % [index + 1, target, str(card.get("tag", _rarity_name(rarity)))]
		summary_labels[index].text = sim.rewards.preview(card, sim)
		descriptions[index].text = str(card.get("desc", "获得强化"))
	buttons[index].tooltip_text = titles[index].text + "\n" + _rarity_name(rarity) + " · " + tags[index].text + "\n" + summary_labels[index].text + "\n" + descriptions[index].text
	action_labels[index].text = "给谁？ / TARGET" if sim.v2_mode and card.get("target", "global") == "character" else "就这张 / TAKE IT"
	action_labels[index].add_theme_color_override("font_color", POSTER.INK if index == focused_index else POSTER.PAPER)
	action_index_labels[index].text = "[%d]" % (index + 1)
	action_index_labels[index].add_theme_color_override("font_color", POSTER.INK if index == focused_index else POSTER.PAPER)

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
		# Hover owns a child, so it cannot fight the parent's entrance tween.
		tween.tween_property(card_bodies[i], "position", Vector2(0,-5) if selected else Vector2.ZERO, 0.14)
		tween.tween_property(card_bodies[i], "scale", Vector2.ONE * (1.018 if selected else 1.0), 0.14)
		buttons[i].z_index = 3 if selected else i
		card_art[i].selected = selected
		card_art[i].queue_redraw()
		action_labels[i].add_theme_color_override("font_color", POSTER.INK if selected else POSTER.PAPER)
		action_index_labels[i].add_theme_color_override("font_color", POSTER.INK if selected else POSTER.PAPER)

func _commit_choice(index: int) -> void:
	if index < 0 or index >= buttons.size() or not buttons[index].visible or not visible or target_overlay.visible or synergy_overlay.visible:
		return
	_play(confirm_sound)
	chosen.emit(index, -1)

func _build_target_picker(hud) -> void:
	target_overlay = ColorRect.new()
	target_overlay.color = Color(POSTER.INK, 0.97)
	target_overlay.z_index = 100
	target_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(target_overlay)
	var panel: Panel = POSTER.new()
	panel.position = Vector2(122, 112)
	panel.size = Vector2(1036, 500)
	panel.title_rect = Rect2(42, 19, 950, 48)
	target_overlay.add_child(panel)
	target_panel = panel
	target_heading = _poster_label(hud, panel, Rect2(54, 28, 928, 40), "给谁开挂？", 27, POSTER.PAPER)
	target_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 3:
		var button: Button = hud.button(panel, Rect2(50 + i * 323, 94, 290, 330), "", false)
		POSTER.style_button(button, false, 20)
		button.clip_contents = true
		var preview: Control = CharacterBreathPreview.new()
		preview.transparent_background = true
		preview.position = UI_LAYOUT.battle_reward_target_portrait_rect.position
		preview.size = UI_LAYOUT.battle_reward_target_portrait_rect.size
		button.add_child(preview)
		target_previews.append(preview)
		var name_label: Label = _poster_label(hud, button, UI_LAYOUT.battle_reward_target_name_rect, "", 20, POSTER.INK)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		target_name_labels.append(name_label)
		var hp_label: Label = _poster_label(hud, button, UI_LAYOUT.battle_reward_target_stats_rect, "", 13, POSTER.INK)
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		target_hp_labels.append(hp_label)
		button.pressed.connect(_pick_target.bind(i))
		button.mouse_entered.connect(func(): _play(hover_sound); button.grab_focus())
		target_buttons.append(button)
	var back: Button = hud.button(panel, Rect2(410, 445, 216, 42), "返回卡牌", false)
	POSTER.style_button(back, false, 20)
	target_back = back
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
		target_name_labels[i].add_theme_color_override("font_color", POSTER.INK)
		target_hp_labels[i].text = "HP %d / %d" % [int(hero.get("hp", 0)), int(hero.get("max_hp", 0))]
		var benefit := preload("res://scripts/card_benefit_preview.gd").hero_lines(sim.rewards.offered[index], hero)
		target_hp_labels[i].text += "\n" + (benefit if not benefit.is_empty() else sim.rewards.preview(sim.rewards.offered[index],sim))
		target_hp_labels[i].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		target_buttons[i].tooltip_text = Synergies.preview(sim.rewards.offered[index], sim, i)
	reroll_button.disabled = true
	target_overlay.show()
	var items: Array[Dictionary] = [{"node":target_panel,"offset":Vector2(0,36),"delay":0.0,"scale":0.98}]
	for target_index in target_buttons.size():
		if target_buttons[target_index].visible: items.append({"node":target_buttons[target_index],"offset":Vector2(0,24),"delay":target_index * 0.05,"scale":0.98})
	MOTION.enter(target_overlay, items, bool(owner_hud.reduced))
	for button: Button in target_buttons:
		if button.visible:
			button.grab_focus()
			break

func close_target_picker() -> void:
	MOTION.reset(target_overlay)
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
	MOTION.reset(target_overlay)
	target_overlay.hide()
	target_card_index = -1
	chosen.emit(picked_card, hero_id)

func _normalize_rarity(rarity: String) -> String:
	if rarity in ["mythic", "genesis"]:
		return "genesis"
	if rarity in ["common", "rare", "epic", "legendary"]:
		return rarity
	return "common"

func _rarity_name(rarity: String) -> String:
	return {"common":"普通", "rare":"稀有", "epic":"史诗", "legendary":"传奇", "genesis":"创世"}.get(rarity, "普通")

func _rarity_color(rarity: String) -> Color:
	return {"common":Color("#d9dee3"), "rare":Color("#62b8ee"), "epic":Color("#c781f0"), "legendary":Color("#ffc94d"), "genesis":Color("#65e0d6")}.get(rarity, Color("#eef3f8"))

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
	reroll_button = hud.button(header_group, UI_LAYOUT.battle_reward_reroll_rect, "刷新 2/2  [R]", false)
	POSTER.style_button(reroll_button, false, 17)
	reroll_button.pressed.connect(request_reroll)
	reroll_button.tooltip_text = "每轮免费刷新2次；尽量避开本轮已见卡牌，不消耗选卡机会。"
	synergy_button = hud.button(header_group, UI_LAYOUT.battle_reward_synergy_button_rect, "联动图鉴", false)
	POSTER.style_button(synergy_button, false, 17)
	synergy_button.pressed.connect(show_synergies)
	synergy_hint = _poster_label(hud, footer_group, UI_LAYOUT.battle_reward_synergy_preview_rect, "", 14, POSTER.YELLOW)
	synergy_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	synergy_hint.clip_text = true
	synergy_hint.max_lines_visible = 2
	synergy_hint.size = UI_LAYOUT.battle_reward_synergy_preview_rect.size
	synergy_overlay = ColorRect.new()
	synergy_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	synergy_overlay.color = Color(POSTER.INK, 0.98)
	synergy_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	synergy_overlay.z_index = 110
	add_child(synergy_overlay)
	var area: Rect2 = UI_LAYOUT.battle_reward_synergy_overlay_rect
	var surface: Panel = POSTER.new()
	surface.position = area.position
	surface.size = area.size
	surface.title_rect = Rect2(18, 6, 1020, 39)
	synergy_overlay.add_child(surface)
	_poster_label(hud, surface, Rect2(20, 8, 780, 34), "卡牌联动 · 每组只激活一次", 24, POSTER.PAPER)
	_poster_label(hud, surface, Rect2(20, 48, 850, 24), "角色联动需由同一角色持有两张卡；全队联动可由不同角色持有。", 14, POSTER.PAPER)
	var close_button: Button = hud.button(synergy_overlay, Rect2(area.end - Vector2(172, area.size.y - 8), Vector2(152, 34)), "返回选卡 [Esc]", false)
	POSTER.style_button(close_button, false, 15)
	close_button.pressed.connect(close_synergies)
	for index in Synergies.RECIPES.size():
		var strip := Panel.new()
		strip.position = Vector2(20, 88 + index * 64)
		strip.size = Vector2(area.size.x - 40, 59)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_theme_stylebox_override("panel", POSTER.paper_style())
		surface.add_child(strip)
		var row: Label = _poster_label(hud, strip, Rect2(13, 5, strip.size.x - 26, 49), "", 14, POSTER.INK)
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
		synergy_rows[index].add_theme_color_override("font_color", POSTER.RED.darkened(0.25) if state.begins_with("已激活") else POSTER.INK)
	synergy_overlay.show()

func close_synergies() -> void:
	synergy_overlay.hide()
	if not buttons.is_empty(): buttons[maxi(0, focused_index)].grab_focus()
