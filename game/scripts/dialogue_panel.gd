extends CanvasLayer
signal finished
const PORTRAITS = {
	"saria": preload("res://assets/portraits/saria.png"),
	"saria-soft": preload("res://assets/portraits/saria-soft.png"),
	"jessica": preload("res://assets/portraits/jessica.png"),
	"muelsyse": preload("res://assets/portraits/muelsyse.png")
}
var config
var director
var hud
var root: Control
var portrait: TextureRect
var partner: TextureRect
var name_label: Label
var body: RichTextLabel
var progress: Label
var history_panel: Panel
var history_text: RichTextLabel
var advance_button: Button
var auto_button: Button
var history_button: Button
var controls: Array[Button] = []
var letters: float = 0.0
var auto_mode: bool = false
var auto_timer: float = 0.0
var last_portrait: String = "muelsyse"

func build(ui, story) -> void:
	hud = ui
	director = story
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = hud.get_child(0).theme
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.015, 0.025, 0.86)
	root.add_child(shade)
	hud.label(root, Vector2(52, 22), Vector2(800, 28), "R I F T   G U A R D   /   城 门 之 下", 15, Color("#d7a9a2"))
	hud.label(root, Vector2(52, 55), Vector2(900, 24), "同人试作剧情 · 角色战斗属性为本作玩法设定", 12, Color("#a79a9f"))
	partner = art(Rect2(685, 80, 490, 650))
	partner.modulate = Color(0.36, 0.28, 0.34, 0.8)
	portrait = art(Rect2(115, 75, 520, 665))
	var box := NinePatchRect.new()
	box.texture = preload("res://assets/gothic/panel_main_horned.png")
	box.position = Vector2(75, 455)
	box.size = Vector2(1130, 250)
	box.patch_margin_left = 95
	box.patch_margin_right = 95
	box.patch_margin_top = 130
	box.patch_margin_bottom = 60
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	hud.bind(box, "dialog_frame")
	name_label = hud.label(root, Vector2(170, 530), Vector2(550, 32), "", 23, Color("#f0b4ae"))
	body = RichTextLabel.new()
	body.position = Vector2(152, 578)
	body.size = Vector2(970, 62)
	body.add_theme_font_size_override("normal_font_size", 20)
	body.add_theme_color_override("default_color", Color("#f5ece4"))
	body.scroll_following = true
	root.add_child(body)
	hud.bind(name_label, "dialog_name")
	hud.bind(body, "dialog_body")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress = hud.label(root, Vector2(153, 649), Vector2(245, 25), "", 12, Color("#b9a2a9"))
	advance_button = action(Rect2(965, 645, 172, 32), "继续  [Enter]", advance)
	auto_button = action(Rect2(800, 645, 150, 32), "自动：关", func():
		auto_mode = not auto_mode
		auto_timer = 0.0
		auto_button.text = "自动：开" if auto_mode else "自动：关")
	history_button = action(Rect2(651, 645, 132, 32), "历史  [H]", toggle_history)
	var skip_button: Button = action(Rect2(489, 645, 146, 32), "跳过本段 [Esc]", skip)
	hud.bind(advance_button, "dialog_continue")
	hud.bind(auto_button, "dialog_auto")
	hud.bind(history_button, "dialog_history")
	hud.bind(skip_button, "dialog_skip")
	for i in controls.size():
		controls[i].focus_next = controls[(i + 1) % controls.size()].get_path()
		controls[i].focus_previous = controls[(i + controls.size() - 1) % controls.size()].get_path()
	history_panel = hud.panel(root, Rect2(190, 112, 900, 470), Color("#241b25"), Color("#bb626b"))
	hud.label(history_panel, Vector2(28, 20), Vector2(600, 35), "对话记录 · H / Esc 返回", 22, Color("#f0b4ae"))
	history_text = RichTextLabel.new()
	history_text.focus_mode = Control.FOCUS_ALL
	history_text.position = Vector2(28, 70)
	history_text.size = Vector2(844, 370)
	history_text.add_theme_font_size_override("normal_font_size", 18)
	history_panel.add_child(history_text)
	history_panel.hide()
	root.hide()

func art(rect: Rect2) -> TextureRect:
	var item := TextureRect.new()
	item.position = rect.position
	item.size = rect.size
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(item)
	return item

func action(rect: Rect2, text: String, callback: Callable) -> Button:
	var item: Button = hud.button(root, rect, text, false)
	item.pressed.connect(callback)
	controls.append(item)
	return item

func display() -> void:
	for item in controls:
		item.disabled = false
		item.focus_mode = Control.FOCUS_ALL
	history_panel.hide()
	root.show()
	show_line()
	advance_button.grab_focus()

func show_line() -> void:
	var line: Dictionary = director.current()
	if line.is_empty():
		return
	if config != null and config.loaded:
		set_picture(portrait, line.get("portrait", ""), Vector2(line.get("x", 115), line.get("y", 75)), Vector2(520, 665), line.get("scale", 1.0), line.get("flip", false))
		set_picture(partner, line.get("partner", ""), Vector2(line.get("partner_x", 685), line.get("partner_y", 80)), Vector2(490, 650), line.get("partner_scale", 1.0), line.get("partner_flip", false))
		var highlight: String = line.get("highlight", "main")
		portrait.modulate = Color(0.36, 0.28, 0.34, 0.8) if highlight == "partner" else Color.WHITE
		partner.modulate = Color(0.36, 0.28, 0.34, 0.8) if highlight == "main" else Color.WHITE
	else:
		portrait.show()
		partner.show()
		portrait.position = Vector2(115, 75)
		portrait.size = Vector2(520, 665)
		portrait.flip_h = false
		partner.position = Vector2(685, 80)
		partner.size = Vector2(490, 650)
		partner.flip_h = false
		portrait.modulate = Color.WHITE
		partner.modulate = Color(0.36, 0.28, 0.34, 0.8)
		partner.texture = PORTRAITS.get(last_portrait, PORTRAITS.muelsyse)
		if last_portrait == line.portrait:
			partner.texture = PORTRAITS.jessica if line.portrait != "jessica" else PORTRAITS.saria
		portrait.texture = PORTRAITS.get(line.portrait, PORTRAITS.saria)
	last_portrait = line.portrait
	name_label.text = line.speaker
	body.text = line.text
	body.visible_characters = 0
	letters = 0.0
	auto_timer = 0.0
	progress.text = "战场已暂停   ·   %02d / %02d" % [director.index + 1, director.lines.size()]

func _process(dt: float) -> void:
	if root == null or not root.visible or history_panel.visible:
		return
	letters += dt * 35.0
	body.visible_characters = mini(int(letters), body.text.length())
	if body.visible_characters >= body.text.length() and auto_mode:
		auto_timer += dt
		if auto_timer > 2.0:
			advance()

func advance() -> void:
	if not director.active or history_panel.visible:
		return
	if letters < body.text.length():
		letters = body.text.length()
		body.visible_characters = -1
		return
	if director.advance():
		show_line()
	else:
		close()

func skip() -> void:
	director.skip()
	close()

func close() -> void:
	root.hide()
	history_panel.hide()
	finished.emit()

func toggle_history() -> void:
	history_panel.visible = not history_panel.visible
	if history_panel.visible:
		history_text.text = ""
		for row in director.history:
			history_text.text += row.speaker + "：\n" + row.text + "\n\n"
		for item in controls:
			item.disabled = item != history_button
			item.focus_mode = Control.FOCUS_ALL if item == history_button else Control.FOCUS_NONE
		history_button.grab_focus()
	else:
		for item in controls:
			item.disabled = false
			item.focus_mode = Control.FOCUS_ALL
		advance_button.grab_focus()

func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			toggle_history()
		elif event.keycode == KEY_ESCAPE:
			if history_panel.visible:
				toggle_history()
			else:
				skip()
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and history_panel.visible:
			toggle_history()
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and not history_panel.visible:
			var focus = get_viewport().gui_get_focus_owner()
			if focus == advance_button or focus == null:
				advance()
			elif focus is Button:
				focus.pressed.emit()
		elif event.keycode == KEY_TAB and not history_panel.visible:
			var current: int = controls.find(get_viewport().gui_get_focus_owner())
			var direction: int = -1 if event.shift_pressed else 1
			controls[posmod(current + direction, controls.size())].grab_focus()

func set_picture(item: TextureRect, alias: String, at: Vector2, dimensions: Vector2, factor: float, flipped: bool) -> void:
	item.visible = alias != ""
	item.texture = config.texture(alias) if alias != "" else null
	item.position = at
	item.size = dimensions * factor
	item.flip_h = flipped
