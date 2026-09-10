extends CanvasLayer
signal closed

const Catalog = preload("res://scripts/combat_catalog.gd")
const WHITE := Color("#f3e9df")
const MUTED := Color("#a9929b")
const ACCENT := Color("#e7a0a4")

var root: Control
var list: VBoxContainer
var title: Label
var counter: Label
var tabs: Array[Button] = []
var database
var progress
var hud
var active_tab := "characters"

func build(owner_hud, game_database, state) -> void:
	hud = owner_hud
	database = game_database
	progress = state
	layer = 40
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	var hell_background := TextureRect.new()
	hell_background.texture = preload("res://assets/helltaker/backgrounds/chapterBG0008.png")
	hell_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hell_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hell_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hell_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hell_background)
	var veil := ColorRect.new()
	veil.color = Color(0.025, 0.012, 0.02, 0.84)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)
	var frame: Panel = owner_hud.panel(root, Rect2(54, 40, 1172, 640), Color("#171119"), Color("#9f4f60"))
	owner_hud.ornament(frame, Rect2(-18, -18, 1208, 676))
	owner_hud.label(frame, Vector2(34, 21), Vector2(520, 20), "A R C H I V E   /   裂 隙 档 案", 12, ACCENT)
	title = owner_hud.label(frame, Vector2(34, 47), Vector2(520, 42), "角色图鉴", 30, WHITE)
	counter = owner_hud.label(frame, Vector2(640, 54), Vector2(405, 28), "", 14, MUTED)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var close_btn: Button = owner_hud.button(frame, Rect2(1064, 25, 78, 42), "关闭", false)
	close_btn.pressed.connect(close)
	var tab_data := [["characters", "角色图鉴"], ["cards", "卡牌图鉴"], ["enemies", "敌人档案"], ["builds", "构筑战报"]]
	for i in tab_data.size():
		var tab: Button = owner_hud.button(frame, Rect2(34 + i * 165, 101, 152, 42), tab_data[i][1], false)
		tab.pressed.connect(show_tab.bind(str(tab_data[i][0])))
		tabs.append(tab)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(34, 157)
	scroll.size = Vector2(1108, 442)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(1082, 0)
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	owner_hud.label(frame, Vector2(34, 607), Vector2(1080, 20), "F2 打开/关闭 · 发现记录会自动保存 · 通关后解锁新角色", 12, MUTED)
	root.hide()

func open(tab: String = "characters") -> void:
	active_tab = tab
	show_tab(tab)
	root.show()

func close() -> void:
	root.hide()
	closed.emit()

func is_open() -> bool:
	return root != null and root.visible

func show_tab(tab: String) -> void:
	active_tab = tab
	for child in list.get_children():
		child.queue_free()
	for i in tabs.size():
		tabs[i].modulate = Color.WHITE if i == ["characters", "cards", "enemies", "builds"].find(tab) else Color("#806e75")
	match tab:
		"cards": _show_cards()
		"enemies": _show_enemies()
		"builds": _show_builds()
		_: _show_characters()

func _show_characters() -> void:
	title.text = "角色图鉴"
	var unlocked := 0
	for id: String in database.characters:
		var data: Dictionary = database.characters[id]
		var known: bool = progress.unlocked_characters.has(id)
		unlocked += int(known)
		var name: String = str(data.name) if known else "？？？"
		var skill: Dictionary = data.get("active_skill", {})
		var ultimate: Dictionary = data.get("ultimate", {})
		var body: String = "%s · %s  /  Q %s  /  E %s" % [_element_name(str(data.element)), data.role, skill.get("name", "主动技能"), ultimate.get("name", "终结技")] if known else "档案封锁    /    随剧情推进后解锁"
		_add_row(name, body, _element_color(str(data.element)) if known else MUTED, known)
	counter.text = "解锁 %d / %d" % [unlocked, database.characters.size()]

func _show_cards() -> void:
	title.text = "卡牌图鉴"
	var discovered := 0
	for card: Dictionary in database.cards:
		var id := str(card.id)
		var known: bool = progress.discovered_cards.has(id)
		discovered += int(known)
		var rarity := str(card.rarity)
		var tag_text := " / ".join(card.get("tags", []))
		var evolution := " · 可进化" if not card.get("evolutions", []).is_empty() else ""
		var card_body := "%s\n标签：%s%s" % [str(card.description), tag_text, evolution]
		_add_row(str(card.name) if known else "？？？", card_body if known else "在升级三选一中首次获得后记录", _rarity_color(rarity) if known else MUTED, known, _rarity_name(rarity) if known else "未发现")
	counter.text = "发现 %d / %d" % [discovered, database.cards.size()]

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
		var title_text := "%s · 击杀%d · 闪避%d · 最高叠层Lv.%d" % [record.get("stage_id","未知关卡"), int(record.get("kills",0)), int(record.get("dodges",0)), int(record.get("highest_stack",0))]
		_add_row(title_text, "\n".join(lines), ACCENT, true, "%d项强化" % record.get("buff_levels",{}).size())
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
		var trait_text := " / ".join(traits) if not traits.is_empty() else "近战"
		var body: String = "HP %.0f · 护甲 %.0f · 移速 %.0f · %s" % [data.hp, data.armor, data.speed, trait_text] if known else "遭遇该敌人后解锁战斗情报"
		_add_row(str(data.name) if known else "未知敌影", body, Color(data.color) if known else MUTED, known)
	counter.text = "遭遇 %d / %d" % [discovered, Catalog.ENEMIES.size()]

func _add_row(name: String, body: String, color: Color, known: bool, badge: String = "") -> void:
	var row := Panel.new()
	var row_height := 90.0 if active_tab == "builds" else 66.0
	row.custom_minimum_size = Vector2(1082, row_height)
	row.add_theme_stylebox_override("panel", hud.style(Color("#261b26") if known else Color("#171317"), color.darkened(0.45)))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(row)
	var mark := ColorRect.new()
	mark.size = Vector2(6, row_height)
	mark.color = color
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mark)
	var icon_name := "character" if active_tab == "characters" else ("card" if active_tab == "cards" else ("boss" if "Boss" in body else "skull"))
	var icon_path := "res://assets/ui/icons/temporary/nieobie/%s.svg" % icon_name
	if ResourceLoader.exists(icon_path):
		var icon_back := ColorRect.new()
		icon_back.position = Vector2(15, 12)
		icon_back.size = Vector2(40, 40)
		icon_back.color = Color("#ead9dc") if known else Color("#55474d")
		icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_back)
		hud.icon(row, icon_path, Rect2(18, 15, 34, 34), color if known else MUTED)
	hud.label(row, Vector2(66, 8), Vector2(350, 26), name, 16, color)
	var body_label: Label = hud.label(row, Vector2(66, 35), Vector2(850, row_height - 38.0), body, 11, WHITE if known else MUTED)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not badge.is_empty():
		var tag: Label = hud.label(row, Vector2(920, 19), Vector2(132, 27), badge, 13, color)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _rarity_name(rarity: String) -> String:
	return {"common": "普通", "rare": "稀有", "epic": "史诗", "legendary": "传奇"}.get(rarity, rarity)

func _rarity_color(rarity: String) -> Color:
	return {"common": Color("#d8d1ca"), "rare": Color("#62b8ee"), "epic": Color("#c781f0"), "legendary": Color("#f1b85a")}.get(rarity, WHITE)

func _element_name(element: String) -> String:
	return {"none": "无元素", "anemo": "风元素", "electro": "雷元素", "pyro": "火元素", "hydro": "水元素", "geo": "岩元素", "cryo": "冰元素"}.get(element, element)

func _element_color(element: String) -> Color:
	return {"none": WHITE, "anemo": Color("#63e6c0"), "electro": Color("#bf83ff"), "pyro": Color("#ff745c"), "hydro": Color("#5ab8ff"), "geo": Color("#e8b94d"), "cryo": Color("#9de7f2")}.get(element, WHITE)
