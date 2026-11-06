extends CanvasLayer

signal dismissed

const AchievementCatalog = preload("res://scripts/achievement_catalog.gd")
const POSTER = preload("res://scripts/poster_surface.gd")
const ROW_SURFACE = preload("res://scripts/compendium_surface.gd")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")

var root: Control
var list: VBoxContainer
var heading: Label
var scroll: ScrollContainer
var close_button: Button
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
	veil.color = Color(0.015, 0.016, 0.022, 0.9)
	root.add_child(veil)
	var frame := POSTER.new()
	frame.position = UI_LAYOUT.stage_achievement_frame_rect.position
	frame.size = UI_LAYOUT.stage_achievement_frame_rect.size
	frame.title_rect = UI_LAYOUT.stage_achievement_header_rect
	root.add_child(frame)
	var header: Rect2 = UI_LAYOUT.stage_achievement_header_rect
	heading = owner_hud.label(frame, header.position + Vector2(15, 2), Vector2(header.size.x - 30, 61), "成就解锁！", 43, POSTER.PAPER)
	heading.add_theme_font_override("font", POSTER.TYPE)
	heading.add_theme_constant_override("outline_size", 4)
	heading.add_theme_color_override("font_outline_color", POSTER.INK)
	var subtitle: Label = owner_hud.label(frame, header.position + Vector2(18, 66), Vector2(header.size.x - 36, 22), "ACHIEVEMENT / 新纪录已收入图鉴", 17, POSTER.PAPER)
	subtitle.add_theme_font_override("font", POSTER.TYPE)
	scroll = ScrollContainer.new()
	scroll.position = UI_LAYOUT.stage_achievement_scroll_rect.position
	scroll.size = UI_LAYOUT.stage_achievement_scroll_rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(UI_LAYOUT.stage_achievement_row_size.x, 0)
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	close_button = owner_hud.button(frame, UI_LAYOUT.stage_achievement_continue_rect, "收下徽章，继续！ [Esc]", true)
	POSTER.style_button(close_button, true, 22)
	close_button.pressed.connect(close)
	root.hide()

func open(ids: Array[String]) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0
	heading.text = "成就解锁！  × %d" % ids.size()
	for id: String in ids:
		var item: Dictionary = AchievementCatalog.by_id(id)
		if not item.is_empty(): _add_item(item)
	root.show()
	close_button.grab_focus()

func close() -> void:
	if root == null or not root.visible: return
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
	var row := Control.new()
	row.custom_minimum_size = UI_LAYOUT.stage_achievement_row_size
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(row)
	var paper := ROW_SURFACE.new()
	paper.accent = color
	paper.kind = "row"
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(paper)
	var icon_path := AchievementCatalog.icon_path(str(item.id))
	if ResourceLoader.exists(icon_path):
		var image: TextureRect = hud.icon(row, icon_path, Rect2(18, 16, 114, 110), Color.WHITE)
		image.name = "AchievementIcon"
	var name_label: Label = hud.label(row, Vector2(155, 12), Vector2(row.custom_minimum_size.x - 300, 37), str(item.name), 28, POSTER.INK)
	name_label.add_theme_font_override("font", POSTER.TYPE)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var description: Label = hud.label(row, Vector2(155, 63), Vector2(row.custom_minimum_size.x - 183, 62), str(item.description), 19, POSTER.INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_constant_override("line_spacing", 4)
	var badge: Label = hud.label(row, Vector2(row.custom_minimum_size.x - 139, 18), Vector2(110, 29), "%s · %s" % [str(item.group), AchievementCatalog.tier_name(tier)], 18, POSTER.RED)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
