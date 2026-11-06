extends Control
const LAYOUT = preload("res://data/ui_layout_profile.tres")
const FONT = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
const MAIN := "res://main.tscn"
var elapsed := 0.0
var ready_scene: PackedScene
var status: Label
var entering := false
var requested := false

func label_at(rect: Rect2, caption: String, size_value: int, color: Color) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = caption
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _ready() -> void:
	var art := TextureRect.new()
	art.texture = load("res://assets/ui/release_20261106/splash.png")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	label_at(LAYOUT.mode_boot_title_rect, "裂隙守望", 82, Color("fff5e5"))
	label_at(LAYOUT.mode_boot_subtitle_rect, "RIFT GUARD  /  三章试玩版", 25, Color("f9c957"))
	label_at(LAYOUT.mode_boot_tagline_rect, "世界裂开了，队友倒是凑齐了。", 22, Color("e7dcd6"))
	status = label_at(LAYOUT.mode_boot_status_rect, "正在准备舞台…", 21, Color("fff5e5"))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	ResourceLoader.load_threaded_request(MAIN)

func _process(dt: float) -> void:
	elapsed += dt
	if ready_scene == null:
		var progress: Array = []
		var state := ResourceLoader.load_threaded_get_status(MAIN, progress)
		if state == ResourceLoader.THREAD_LOAD_LOADED:
			ready_scene = ResourceLoader.load_threaded_get(MAIN) as PackedScene
			status.text = "轻触屏幕 / 按任意键开始"
		elif state == ResourceLoader.THREAD_LOAD_FAILED:
			status.text = "加载失败，请重新启动游戏。"
		elif not progress.is_empty():
			status.text = "正在准备舞台… %d%%" % roundi(float(progress[0]) * 100.0)
	if ready_scene != null and not entering and elapsed >= 1.2 and (requested or elapsed >= 4.0):
		entering = true
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.25)
		tween.tween_callback(func(): get_tree().change_scene_to_packed(ready_scene))

func _input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		requested = true
