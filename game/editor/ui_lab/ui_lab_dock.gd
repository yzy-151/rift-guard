@tool
extends VBoxContainer
class_name RiftUILayoutDock

signal open_requested
signal page_requested(page: String)
signal refresh_requested
signal write_requested
signal field_selected(index: int)
var page_picker: OptionButton
var status_label: RichTextLabel
var field_list: ItemList

func _ready() -> void:
	name = "UI 实验台"
	custom_minimum_size = Vector2(330, 520)
	var title := Label.new()
	title.text = "RIFT GUARD · UI 实验台"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	var note := Label.new()
	note.text = "Profile 是唯一数据源 · 画布坐标 1280×720"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	page_picker = OptionButton.new()
	for page: String in ["Dialogue", "Mode", "Mission", "Squad", "Campaign Battle", "Endless Battle", "Reward", "Settings", "Stage"]:
		page_picker.add_item(page)
	page_picker.item_selected.connect(func(index: int): page_requested.emit(page_picker.get_item_text(index)))
	add_child(page_picker)
	var open_button := Button.new()
	open_button.text = "打开实验台场景"
	open_button.pressed.connect(func(): open_requested.emit())
	add_child(open_button)
	var buttons := HBoxContainer.new()
	var refresh_button := Button.new()
	refresh_button.text = "刷新 / 撤销未写回"
	refresh_button.pressed.connect(func(): refresh_requested.emit())
	buttons.add_child(refresh_button)
	var write_button := Button.new()
	write_button.text = "校验并写回"
	write_button.pressed.connect(func(): write_requested.emit())
	buttons.add_child(write_button)
	add_child(buttons)
	status_label = RichTextLabel.new()
	status_label.custom_minimum_size = Vector2(310, 84)
	status_label.fit_content = true
	status_label.bbcode_enabled = true
	status_label.text = "[color=#e8b1b8]先打开实验台场景，再选择页面。[/color]"
	add_child(status_label)
	var fields_title := Label.new()
	fields_title.text = "字段与当前值（点击可在 Inspector 精调）"
	add_child(fields_title)
	field_list = ItemList.new()
	field_list.custom_minimum_size = Vector2(310, 300)
	field_list.allow_reselect = true
	field_list.item_selected.connect(func(index: int): field_selected.emit(index))
	add_child(field_list)
	var help := Label.new()
	help.text = "选择红框后，用 2D 工具拖动或拉角点；Inspector 可精确输入 Position / Size。贴图库位于 720 线下方。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)

func selected_page() -> String:
	return page_picker.get_item_text(page_picker.selected)

func set_page(page: String) -> void:
	for index in page_picker.item_count:
		if page_picker.get_item_text(index) == page:
			page_picker.select(index)
			return

func show_result(result: Dictionary) -> void:
	var ok := bool(result.get("ok", false))
	status_label.text = "[color=%s]%s[/color]" % ["#9cf0ba" if ok else "#ff8b9b", str(result.get("message", ""))]

func update_fields(rows: PackedStringArray) -> void:
	var selected := field_list.get_selected_items()
	var selected_index := selected[0] if not selected.is_empty() else -1
	field_list.clear()
	for row: String in rows:
		field_list.add_item(row)
	if selected_index >= 0 and selected_index < field_list.item_count:
		field_list.select(selected_index)
