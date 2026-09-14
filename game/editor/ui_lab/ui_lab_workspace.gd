@tool
extends Control
class_name RiftUILayoutWorkspace

const Adapter = preload("res://editor/ui_lab/profile_adapter.gd")
const Transaction = preload("res://editor/ui_lab/write_transaction.gd")
const Handle = preload("res://editor/ui_lab/ui_lab_handle.gd")
const LAYOUT_PATH := "res://data/ui_layout_profile.tres"
const SKIN_PATH := "res://data/ui_skin_profile.tres"
const REFERENCES := {
	"Dialogue": "res://editor/ui_lab/refs/dialogue.png",
	"Mode": "res://editor/ui_lab/refs/mode.png",
	"Mission": "res://editor/ui_lab/refs/mission.png",
	"Squad": "res://editor/ui_lab/refs/squad.png",
	"Campaign Battle": "res://editor/ui_lab/refs/campaign_battle.png",
	"Endless Battle": "res://editor/ui_lab/refs/endless_battle.png",
	"Reward": "res://editor/ui_lab/refs/reward.png",
	"Settings": "res://editor/ui_lab/refs/settings.png",
	"Stage": "res://editor/ui_lab/refs/stage.png"
}

@export_enum("Dialogue", "Mode", "Mission", "Squad", "Campaign Battle", "Endless Battle", "Reward", "Settings", "Stage") var page_name := "Dialogue"
var layout_profile: Resource
var skin_profile: Resource
var layout_hash := ""
var skin_hash := ""
var last_message := ""
var generated: Array[Node] = []

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 1040)
	size = Vector2(1280, 1040)

func rebuild(requested_page: String = page_name) -> Dictionary:
	page_name = requested_page
	_clear_generated()
	layout_profile = ResourceLoader.load(LAYOUT_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	skin_profile = ResourceLoader.load(SKIN_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	if layout_profile == null or skin_profile == null:
		last_message = "Profile 加载失败。"
		return {"ok": false, "message": last_message}
	layout_hash = Transaction.file_hash(LAYOUT_PATH)
	skin_hash = Transaction.file_hash(SKIN_PATH)
	Transaction.acquire_lock(page_name)
	_add_reference()
	var layout_records := Adapter.records(layout_profile, page_name)
	for record: Dictionary in layout_records:
		_add_layout_handle(record)
	var skin_records := Adapter.records(skin_profile, page_name)
	for index in skin_records.size():
		_add_skin_preview(skin_records[index], index)
	last_message = "%s：%d 个布局字段，%d 个贴图字段。" % [page_name, layout_records.size(), skin_records.size()]
	return {"ok": true, "message": last_message, "layout_count": layout_records.size(), "skin_count": skin_records.size()}

func write_back() -> Dictionary:
	if layout_profile == null or skin_profile == null:
		return {"ok": false, "message": "请先刷新实验台。"}
	var errors := PackedStringArray()
	for node: Node in generated:
		if node is RiftUILayoutHandle:
			var error := Adapter.set_record(layout_profile, {"key": node.profile_key, "index": node.array_index}, node.profile_value())
			if not error.is_empty():
				errors.append(error)
		elif node is TextureRect and node.has_meta("skin_key"):
			var key := str(node.get_meta("skin_key"))
			if not Adapter._has_property(skin_profile, key):
				errors.append("Skin 字段不存在: %s" % key)
			else:
				skin_profile.set(key, node.texture)
	if not errors.is_empty():
		last_message = "
".join(errors)
		return {"ok": false, "message": last_message}
	var result := Transaction.save_pair(layout_profile, skin_profile, LAYOUT_PATH, SKIN_PATH, layout_hash, skin_hash)
	last_message = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		layout_hash = str(result.get("layout_hash", ""))
		skin_hash = str(result.get("skin_hash", ""))
	return result

func release_lock() -> void:
	Transaction.release_lock()

func editable_nodes() -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in generated:
		if node is RiftUILayoutHandle or (node is TextureRect and node.has_meta("skin_key")):
			result.append(node)
	return result

func field_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for node: Node in editable_nodes():
		if node is RiftUILayoutHandle:
			rows.append("%s  pos=%s  size=%s" % [node.display_key(), node.position, node.size])
		elif node is TextureRect:
			rows.append("%s  texture=%s" % [str(node.get_meta("skin_key")), node.texture.resource_path if node.texture != null else "<empty>"])
	return rows

func _add_reference() -> void:
	var reference := TextureRect.new()
	reference.name = "Reference_%s" % page_name
	reference.texture = load(str(REFERENCES.get(page_name, "")))
	reference.position = Vector2.ZERO
	reference.size = Vector2(1280, 720)
	reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference.stretch_mode = TextureRect.STRETCH_SCALE
	reference.modulate = Color(1, 1, 1, 0.46)
	reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference.z_index = -100
	_add_generated(reference)

func _add_layout_handle(record: Dictionary) -> void:
	var handle := Handle.new()
	handle.configure(record, page_name)
	handle.z_index = 20
	_add_generated(handle)

func _add_skin_preview(record: Dictionary, index: int) -> void:
	var preview := TextureRect.new()
	preview.name = "Skin_%s" % str(record.get("key", "")).replace("/", "_")
	preview.set_meta("skin_key", str(record.get("key", "")))
	preview.texture = record.get("value")
	preview.position = Vector2(24 + (index % 4) * 310, 760 + int(index / 4) * 132)
	preview.size = Vector2(278, 92)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 10
	_add_generated(preview)
	var caption := Label.new()
	caption.name = "Caption_%s" % str(record.get("key", "")).replace("/", "_")
	caption.text = "%s  ·  Inspector 可替换 Texture" % str(record.get("key", ""))
	caption.position = preview.position + Vector2(0, 96)
	caption.size = Vector2(296, 24)
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("#f5d9dd"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.z_index = 11
	_add_generated(caption)

func _add_generated(node: Node) -> void:
	add_child(node)
	node.owner = self
	node.set_meta("ui_lab_generated", true)
	generated.append(node)

func _clear_generated() -> void:
	for child: Node in get_children():
		if child.has_meta("ui_lab_generated"):
			child.free()
	generated.clear()
