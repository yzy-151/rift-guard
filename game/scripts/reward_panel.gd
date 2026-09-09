extends Control
signal chosen(index: int)
var buttons: Array[Button] = []
var tags: Array[Label] = []
var titles: Array[Label] = []
var previews: Array[Label] = []
var descriptions: Array[Label] = []
var heading: Label
var history_label: Label
var offer_key: String = ""

func build(hud) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var hell_background := TextureRect.new()
	hell_background.texture = preload("res://assets/helltaker/backgrounds/chapterBG0004.png")
	hell_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hell_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hell_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hell_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hell_background)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.012, 0.025, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	hud.label(self, Vector2(108, 72), Vector2(1050, 22), "R I F T   G U A R D     /     战 地 补 给", 13, Color("#e3a2a5"))
	hud.bind(hud.label(self, Vector2(105, 111), Vector2(1000, 52), "选择这一次的突破", 34, Color("#efeee4")), "reward_title")
	heading = hud.label(self, Vector2(108, 173), Vector2(1060, 24), "", 14, Color("#b69aa4"))
	for i in 3:
		var card: Button = hud.button(self, Rect2(105 + i * 360, 223, 350, 326), "", false)
		hud.bind(card, "reward_card_%d" % (i + 1))
		card.pressed.connect(func(): chosen.emit(i))
		buttons.append(card)
		tags.append(hud.label(card, Vector2(24, 19), Vector2(302, 23), "", 13, Color("#e3a2a5")))
		titles.append(hud.label(card, Vector2(24, 58), Vector2(302, 42), "", 25, Color("#f3efe3")))
		hud.panel(card, Rect2(24, 116, 302, 46), Color("#3d2631"), Color("#744656"))
		var preview = hud.label(card, Vector2(34, 125), Vector2(282, 31), "", 15, Color("#f0d5c4"))
		preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		previews.append(preview)
		var description = hud.label(card, Vector2(24, 184), Vector2(302, 87), "", 15, Color("#c3adb4"))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		descriptions.append(description)
		hud.label(card, Vector2(24, 280), Vector2(302, 26), "选择并继续    →    [%d]" % (i + 1), 14, Color("#e3a2a5"))
	history_label = hud.label(self, Vector2(108, 581), Vector2(1060, 66), "", 14, Color("#bca7b0"))
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.label(self, Vector2(108, 670), Vector2(1060, 25), "点击卡片 / 数字 1、2、3 选择     ·     Tab 切换焦点，Enter 确认     ·     强化持续到本局结束", 12, Color("#ae969f"))
	hide()

func display(sim) -> void:
	var key: String = str([sim.run_seed, sim.wave, sim.rewards.history, sim.rewards.offered])
	var opened: bool = not visible
	show()
	if offer_key != key:
		offer_key = key
		if sim.v2_mode:
			var level_owner := "旅行者" if sim.endless_mode else "水晶"
			heading.text = "%s Lv.%d     ·     幸运 %.2f     ·     待选择 %d     ·     本局种子 %d" % [level_owner, sim.run_state.crystal_level, sim.run_state.luck, sim.run_state.pending_level_ups, sim.run_seed]
		else:
			heading.text = "节点 %d / 5 已完成     ·     小队 Lv.%d     ·     三项中选择一项     ·     本局种子 %d" % [sim.wave, sim.team_level, sim.run_seed]
		for i in 3:
			var card: Dictionary = sim.rewards.offered[i]
			if sim.v2_mode:
				var target := "全队" if sim.endless_mode else "全队 / 水晶"
				if card.get("target", "global") == "character":
					target = str(card.get("character_id", ""))
					for hero: Dictionary in sim.heroes:
						if hero.get("character_id", "") == card.get("character_id", ""):
							target = hero.name
							break
				var rarity: String = {"common": "普通", "rare": "稀有", "epic": "史诗", "legendary": "传奇", "mythic": "神话"}.get(card.get("rarity", "common"), "普通")
				var rarity_color: Color = {"common": Color("#b8c0cc"), "rare": Color("#69a7e8"), "epic": Color("#b77ae8"), "legendary": Color("#e9b85d"), "mythic": Color("#fff2b2")}.get(card.get("rarity", "common"), Color("#b8c0cc"))
				var current: int = int(sim.run_state.buff_levels.get(card.id, 0))
				tags[i].text = "%02d  /  %s · %s%s" % [i + 1, target, rarity, " · 机制" if bool(card.get("mechanic", false)) else ""]
				tags[i].add_theme_color_override("font_color", rarity_color)
				titles[i].text = str(card.get("name", card.id))
				titles[i].add_theme_color_override("font_color", rarity_color if card.get("rarity", "common") == "mythic" else Color("#f3efe3"))
				buttons[i].self_modulate = Color("#fff1c4") if card.get("rarity", "common") == "mythic" else Color.WHITE
				previews[i].text = sim.rewards.preview(card, sim)
				var card_description := str(card.get("description", "获得强化"))
				if sim.endless_mode:
					card_description = card_description.replace("并修复水晶", "").replace("水晶", "旅行者")
				descriptions[i].text = card_description + "\n当前层数 %d / ∞" % current
			else:
				var target: String = sim.heroes[card.target].name if card.target >= 0 else "全队 / 基地"
				var current: int = sim.rewards.levels.get(card.id, 0)
				tags[i].text = "%02d  /  %s · %s" % [i + 1, target, card.tag]
				titles[i].text = card.name
				previews[i].text = sim.rewards.preview(card, sim)
				descriptions[i].text = card.desc + ("\n当前层数 %d / %d" % [current, card.max] if card.max > 0 and card.max < 99 else "")
		history_label.text = "已经获得   " + ("尚无强化，这是你的第一次选择。" if sim.rewards.history.is_empty() else "  /  ".join(sim.rewards.history))
	for i in 3:
		buttons[i].focus_next = buttons[(i + 1) % 3].get_path()
		buttons[i].focus_previous = buttons[(i + 2) % 3].get_path()
		buttons[i].focus_neighbor_right = buttons[(i + 1) % 3].get_path()
		buttons[i].focus_neighbor_left = buttons[(i + 2) % 3].get_path()
		buttons[i].focus_neighbor_top = buttons[i].get_path()
		buttons[i].focus_neighbor_bottom = buttons[i].get_path()
	if opened:
		buttons[0].grab_focus()
