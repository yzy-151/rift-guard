@tool
extends Panel
class_name RiftUILayoutHandle

@export var profile_key := ""
@export var profile_kind := "rect"
@export var array_index := -1
@export var profile_page := ""
var caption: Label

func configure(record: Dictionary, page: String) -> void:
	profile_key = str(record.get("key", ""))
	profile_kind = str(record.get("kind", "rect"))
	array_index = int(record.get("index", -1))
	profile_page = page
	name = display_key().replace("[", "_").replace("]", "")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.12, 0.25, 0.13)
	style.border_color = Color("#ff5268")
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)
	caption = Label.new()
	caption.text = display_key()
	caption.position = Vector2(5, 3)
	caption.size = Vector2(420, 22)
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("#fff4ee"))
	caption.add_theme_color_override("font_outline_color", Color("#18070d"))
	caption.add_theme_constant_override("outline_size", 4)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	apply_value(record.get("value"))

func apply_value(value) -> void:
	if value is Rect2:
		position = value.position
		size = value.size
	elif value is Vector2 and profile_kind == "point":
		position = value - Vector2(14, 14)
		size = Vector2(28, 28)
	elif value is Vector2:
		position = Vector2(24, 84 + (get_index() % 5) * 54)
		size = Vector2(maxf(24.0, value.x), maxf(24.0, value.y))

func profile_value():
	if profile_kind == "point":
		return position + size * 0.5
	if profile_kind == "size":
		return size
	return Rect2(position, size)

func display_key() -> String:
	return "%s[%d]" % [profile_key, array_index] if array_index >= 0 else profile_key
