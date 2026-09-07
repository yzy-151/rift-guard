extends RefCounted
const Reader = preload("res://scripts/xlsx_reader.gd")
const DISPLAY_FONT = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
const UI_IDS = ["dialog_frame", "dialog_name", "dialog_body", "dialog_continue", "dialog_auto", "dialog_history", "dialog_skip", "game_title", "game_subtitle", "pause_button", "restart_button", "hero_card_1", "hero_card_2", "hero_card_3", "menu_frame", "reward_title", "reward_card_1", "reward_card_2", "reward_card_3"]
var base_dir: String = ""
var path: String = ""
var errors: Array[String] = []
var stories: Dictionary = {}
var ui: Dictionary = {}
var assets: Dictionary = {}
var textures: Dictionary = {}
var loaded: bool = false
func _init(folder: String = "") -> void:
	base_dir = folder
	if folder == "":
		base_dir = ProjectSettings.globalize_path("res://../content") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("content")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--content-dir="):
			base_dir = argument.trim_prefix("--content-dir=")
	path = base_dir.path_join("game_config.xlsx")
	load_config()
func num(c: Dictionary, col: String, fallback: float, loc: String, low: float = -10000, high: float = 10000) -> float:
	var value: String = str(c.get(col, "")).strip_edges()
	if value == "":
		return fallback
	if not value.is_valid_float() or not is_finite(float(value)) or float(value) < low or float(value) > high:
		errors.append(loc + " " + col + " 数值无效：" + value)
		return fallback
	return float(value)
func pick(c: Dictionary, col: String, fallback: String, options: Array, loc: String) -> String:
	var value: String = str(c.get(col, "")).strip_edges()
	if value == "":
		return fallback
	if value not in options:
		errors.append(loc + " " + col + " 可填 " + "/".join(options))
		return fallback
	return value
func load_config() -> void:
	errors.clear()
	textures.clear()
	stories.clear()
	ui.clear()
	assets.clear()
	loaded = false
	if not FileAccess.file_exists(path):
		return
	var reader = Reader.new()
	var tables: Dictionary = reader.read(path)
	errors.append_array(reader.errors)
	for sheet in ["对话", "图片资源", "UI"]:
		if not tables.has(sheet):
			errors.append("缺少工作表：" + sheet)
	if not errors.is_empty():
		report()
		return
	headers(tables["对话"], ["启用", "段落", "顺序", "姓名", "对白", "主图", "主侧", "主X", "主Y", "主缩放", "主翻转", "配图", "配侧", "配X", "配Y", "配缩放", "配翻转", "高亮"], "对话")
	headers(tables["图片资源"], ["资源名", "文件", "说明", "用途"], "图片资源")
	headers(tables["UI"], ["控件ID", "X", "Y", "宽", "高", "素材", "模式", "文字", "字号", "边距左", "边距上", "边距右", "边距下", "说明", "启用"], "UI")
	for row in tables["图片资源"]:
		if row.row < 5:
			continue
		var c: Dictionary = row.cells
		var alias: String = str(c.get("A", "")).strip_edges()
		if alias == "":
			continue
		var source: String = str(c.get("B", "")).strip_edges()
		if assets.has(alias):
			errors.append("图片资源 第%d行 资源名重复：%s" % [row.row, alias])
		var file: String = resolve_path(source)
		var exists: bool = ResourceLoader.exists(file) if file.begins_with("res://") else FileAccess.file_exists(file)
		if file == "" or not exists:
			errors.append("图片资源 第%d行 文件不存在或路径无效：%s" % [row.row, source])
		assets[alias] = file
	for scene in ["opening", "node1", "node2", "node3", "node4", "won", "lost"]:
		stories[scene] = []
	var used: Dictionary = {}
	for row in tables["对话"]:
		if row.row < 5:
			continue
		var c: Dictionary = row.cells
		var text: String = str(c.get("E", ""))
		if text.strip_edges() == "":
			continue
		var loc: String = "对话 第%d行" % row.row
		if pick(c, "A", "1", ["0", "1"], loc) == "0":
			continue
		var scene: String = str(c.get("B", "")).strip_edges()
		if scene == "":
			errors.append(loc + " 段落不能为空")
			continue
		var order: float = num(c, "C", row.row, loc, 1, 100000)
		if order != floorf(order):
			errors.append(loc + " 顺序必须为整数")
		var unique: String = scene + ":" + str(order)
		if used.has(unique):
			errors.append(loc + " 同一段落顺序重复")
		used[unique] = true
		var side: String = pick(c, "G", "left", ["left", "right"], loc)
		var other: String = pick(c, "M", "right", ["left", "right"], loc)
		var line := {"speaker": str(c.get("D", "")), "text": text, "order": order,
			"portrait": str(c.get("F", "")).strip_edges(), "side": side,
			"x": num(c, "H", 115 if side == "left" else 685, loc), "y": num(c, "I", 75, loc),
			"scale": num(c, "J", 1, loc, 0.05, 5), "flip": pick(c, "K", "0", ["0", "1"], loc) == "1",
			"partner": str(c.get("L", "")).strip_edges(), "partner_side": other,
			"partner_x": num(c, "N", 115 if other == "left" else 685, loc), "partner_y": num(c, "O", 80, loc),
			"partner_scale": num(c, "P", 1, loc, 0.05, 5), "partner_flip": pick(c, "Q", "0", ["0", "1"], loc) == "1",
			"highlight": pick(c, "R", "main", ["main", "partner", "none"], loc)}
		for alias in [line.portrait, line.partner]:
			if alias != "" and not assets.has(alias):
				errors.append(loc + " 图片资源名不存在：" + alias)
		if not stories.has(scene):
			stories[scene] = []
		stories[scene].append(line)
	for scene in stories:
		stories[scene].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order)
	for row in tables["UI"]:
		if row.row < 5:
			continue
		var c: Dictionary = row.cells
		var id: String = str(c.get("A", "")).strip_edges()
		if id == "":
			continue
		var loc: String = "UI 第%d行" % row.row
		if pick(c, "O", "1", ["0", "1"], loc) == "0":
			continue
		if id not in UI_IDS or ui.has(id):
			errors.append(loc + " 控件ID未知或重复：" + id)
		var alias: String = str(c.get("F", "")).strip_edges()
		if alias != "" and not assets.has(alias):
			errors.append(loc + " 素材名不存在：" + alias)
		ui[id] = {"row": row.row, "x": num(c, "B", 0, loc), "y": num(c, "C", 0, loc),
			"width": num(c, "D", 100, loc, 1, 4000), "height": num(c, "E", 40, loc, 1, 4000),
			"asset": alias, "mode": pick(c, "G", "keep", ["keep", "stretch", "ninepatch"], loc),
			"text": str(c.get("H", "")), "font_size": num(c, "I", 0, loc, 0, 100),
			"left": num(c, "J", 0, loc, 0, 2000), "top": num(c, "K", 0, loc, 0, 2000),
			"right": num(c, "L", 0, loc, 0, 2000), "bottom": num(c, "M", 0, loc, 0, 2000)}
	if errors.is_empty():
		for alias in assets:
			if texture(alias) == null:
				errors.append("无法解码图片：" + alias)
	if errors.is_empty():
		for id in ui:
			var setting: Dictionary = ui[id]
			if setting.mode == "ninepatch" and setting.asset != "":
				var picture: Texture2D = texture(setting.asset)
				var horizontal: float = setting.left + setting.right
				var vertical: float = setting.top + setting.bottom
				if horizontal > picture.get_width() or vertical > picture.get_height() or horizontal > setting.width or vertical > setting.height:
					errors.append("UI 第%d行 九宫格边距之和超过图片或控件尺寸" % setting.row)
	if not errors.is_empty():
		stories.clear()
		ui.clear()
		assets.clear()
		textures.clear()
		report()
		return
	loaded = true
	var report_file := FileAccess.open("user://config-errors.txt", FileAccess.WRITE)
	if report_file:
		report_file.store_string("配置已加载：" + path)
func headers(rows: Array, expected: Array, sheet: String) -> void:
	for row in rows:
		if row.row == 4:
			for i in expected.size():
				if row.cells.get(String.chr(65 + i), "") != expected[i]:
					errors.append(sheet + " 第4行表头不匹配：" + expected[i])
			return
	errors.append(sheet + " 缺少第4行表头")
func resolve_path(source: String) -> String:
	if source.begins_with("res://assets/") and not source.contains(".."):
		return source
	if source == "" or source.is_absolute_path() or source.contains("..") or source.contains(":"):
		return ""
	return base_dir.path_join(source.replace("\\", "/"))
func texture(alias: String) -> Texture2D:
	if textures.has(alias):
		return textures[alias]
	if not assets.has(alias):
		return null
	var file: String = assets[alias]
	var result: Texture2D
	if file.begins_with("res://"):
		result = load(file) as Texture2D
	else:
		var picture := Image.new()
		if picture.load(file) == OK:
			result = ImageTexture.create_from_image(picture)
	textures[alias] = result
	return result
func report() -> void:
	var file := FileAccess.open("user://config-errors.txt", FileAccess.WRITE)
	if file:
		file.store_string(path + "\n" + "\n".join(errors))
	for message in errors:
		push_warning(message)
func apply_ui(control: Control, id: String) -> void:
	if not ui.has(id):
		return
	var row: Dictionary = ui[id]
	control.position = Vector2(row.x, row.y)
	control.size = Vector2(row.width, row.height)
	if row.font_size > 0:
		control.add_theme_font_size_override("normal_font_size" if control is RichTextLabel else "font_size", int(row.font_size))
	if row.text != "" and (control is Label or control is Button):
		control.text = row.text
	if control is NinePatchRect:
		if row.asset != "":
			control.texture = texture(row.asset)
		control.patch_margin_left = int(row.left) if row.mode == "ninepatch" else 0
		control.patch_margin_top = int(row.top) if row.mode == "ninepatch" else 0
		control.patch_margin_right = int(row.right) if row.mode == "ninepatch" else 0
		control.patch_margin_bottom = int(row.bottom) if row.mode == "ninepatch" else 0
		if row.mode == "keep" and control.texture != null:
			var picture_size: Vector2 = control.texture.get_size()
			var factor: float = minf(row.width / picture_size.x, row.height / picture_size.y)
			control.size = picture_size * factor
			control.position += (Vector2(row.width, row.height) - control.size) * 0.5
	elif row.asset != "" and control is Button:
		var skin := StyleBoxTexture.new()
		skin.texture = texture(row.asset)
		skin.texture_margin_left = row.left if row.mode == "ninepatch" else 0.0
		skin.texture_margin_top = row.top if row.mode == "ninepatch" else 0.0
		skin.texture_margin_right = row.right if row.mode == "ninepatch" else 0.0
		skin.texture_margin_bottom = row.bottom if row.mode == "ninepatch" else 0.0
		for state in ["normal", "hover", "pressed"]:
			control.add_theme_stylebox_override(state, skin)
		if row.mode == "keep":
			var display := TextureRect.new()
			display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			display.texture = texture(row.asset)
			display.mouse_filter = Control.MOUSE_FILTER_IGNORE
			display.show_behind_parent = true
			control.add_child(display)
			control.move_child(display, 0)
			display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for state in ["normal", "hover", "pressed"]:
				control.add_theme_stylebox_override(state, StyleBoxEmpty.new())
