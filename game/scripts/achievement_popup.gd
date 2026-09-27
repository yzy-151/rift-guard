extends CanvasLayer

signal dismissed

const AchievementCatalog = preload("res://scripts/achievement_catalog.gd")
const WHITE := Color("#fff1e8")
const MUTED := Color("#b79da6")
const ACCENT := Color("#ff5068")

var root: Control
var list: VBoxContainer
var heading: Label
var hud

func build(owner_hud) -> void:
	hud = owner_hud
	layer = 120
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.012, 0.009, 0.025, 0.88)
	root.add_child(veil)
	var frame: Panel = owner_hud.panel(root, Rect2(260, 102, 760, 516), Color("#100b13"), Color("#d13a55"))
	owner_hud.label(frame, Vector2(36, 24), Vector2(680, 20), "A C H I E V E M E N T   /   成 就 解 锁", 12, ACCENT)
	heading = owner_hud.label(frame, Vector2(36, 52), Vector2(680, 46), "成就已完成", 30, WHITE)
	var rule := ColorRect.new()
	rule.position = Vector2(36, 108)
	rule.size = Vector2(688, 2)
	rule.color = ACCENT
	frame.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(36, 128)
	scroll.size = Vector2(688, 290)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(664, 0)
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var close_button: Button = owner_hud.button(frame, Rect2(170, 444, 420, 48), "收下并继续", true)
	close_button.pressed.connect(close)
	root.hide()

func open(ids: Array[String]) -> void:
	for child in list.get_children():
		child.queue_free()
	heading.text = "完成 %d 项新成就" % ids.size()
	for id: String in ids:
		var item: Dictionary = AchievementCatalog.by_id(id)
		if not item.is_empty():
			_add_item(item)
	root.show()

func close() -> void:
	if root == null or not root.visible:
		return
	root.hide()
	dismissed.emit()

func is_open() -> bool:
	return root != null and root.visible

func handle_input(event: InputEvent) -> bool:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
		close()
		return true
	return false

func _add_item(item: Dictionary) -> void:
	var tier := str(item.get("tier", "silver"))
	var color := AchievementCatalog.tier_color(tier)
	var row := Panel.new()
	row.custom_minimum_size = Vector2(664, 78)
	row.add_theme_stylebox_override("panel", hud.style(Color("#211620"), color.darkened(0.32)))
	list.add_child(row)
	var accent := ColorRect.new()
	accent.position = Vector2(0, 0)
	accent.size = Vector2(6, 78)
	accent.color = color
	row.add_child(accent)
	var icon_path := AchievementCatalog.icon_path(str(item.id))
	if ResourceLoader.exists(icon_path):
		hud.icon(row, icon_path, Rect2(13, 8, 62, 62), Color.WHITE)
	hud.label(row, Vector2(84, 10), Vector2(350, 28), str(item.name), 20, color)
	hud.label(row, Vector2(84, 41), Vector2(470, 24), str(item.description), 12, WHITE)
	var badge: Label = hud.label(row, Vector2(548, 21), Vector2(94, 30), AchievementCatalog.tier_name(tier), 13, color)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
