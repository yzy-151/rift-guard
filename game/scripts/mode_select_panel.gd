extends CanvasLayer

signal chosen(mode_id: String)

const WHITE := Color("#f3e9df")
const MUTED := Color("#ad929b")
const ACCENT := Color("#f07482")

var root: Control
var hud
var buttons: Dictionary = {}

func build(owner_hud) -> void:
	hud = owner_hud
	layer = 60
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	var background := TextureRect.new()
	background.texture = preload("res://assets/helltaker/backgrounds/chapterBG0001.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var veil := ColorRect.new()
	veil.color = Color(0.025, 0.01, 0.025, 0.88)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)
	owner_hud.label(root, Vector2(78, 52), Vector2(760, 22), "R I F T   G U A R D   /   作 战 模 式", 12, ACCENT)
	owner_hud.label(root, Vector2(78, 82), Vector2(760, 52), "选择游戏模式", 36, WHITE)
	owner_hud.label(root, Vector2(80, 140), Vector2(920, 24), "不同模式使用独立地图规则，强化均可无限叠加。", 13, MUTED)
	_build_mode_card(Rect2(80, 205, 535, 390), "rift_watch", "01", "裂隙守望", "多角色路线防守", "三关剧情战役  ·  折线路径  ·  固定Boss\n守卫水晶并在每关重建卡牌构筑", "进入关卡选择")
	_build_mode_card(Rect2(665, 205, 535, 390), "endless_survival", "∞", "无尽生存", "四屏追击生存", "无固定波次  ·  四边刷怪  ·  无限升级\n操纵旅行者移动，同行者跟随攻击", "立即进入荒原")
	owner_hud.label(root, Vector2(80, 635), Vector2(1120, 24), "剧情模式的关卡选择可按 F4 再次打开", 11, MUTED)
	root.hide()

func _build_mode_card(rect: Rect2, id: String, number: String, name: String, subtitle: String, description: String, action: String) -> void:
	var button: Button = hud.button(root, rect, "", true)
	buttons[id] = button
	button.pressed.connect(func():
		root.hide()
		chosen.emit(id))
	hud.label(button, Vector2(30, 26), Vector2(120, 68), number, 48, ACCENT)
	hud.label(button, Vector2(30, 112), Vector2(460, 44), name, 30, WHITE)
	hud.label(button, Vector2(30, 164), Vector2(460, 28), subtitle, 16, ACCENT)
	var copy: Label = hud.label(button, Vector2(30, 220), Vector2(460, 78), description, 13, MUTED)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.label(button, Vector2(30, 334), Vector2(460, 28), action + "   →", 14, WHITE)

func open() -> void:
	root.show()
	for id: String in buttons:
		buttons[id].disabled = false
	buttons["rift_watch"].grab_focus()

func close() -> void:
	root.hide()

func is_open() -> bool:
	return root != null and root.visible
