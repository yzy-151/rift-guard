extends CanvasLayer
signal chosen(layout_id: String)
signal cancelled
var root: Control
var hud
var choices: Array[Dictionary] = []
var cards: Array[Button] = []
class LayoutPreview extends Node2D:
	var option: Dictionary
	var ink := Color("#ca6579")
	func _draw() -> void:
		var box := Rect2(0,0,312,176)
		draw_rect(box,Color("#10131d"))
		draw_rect(box,ink.darkened(0.45),false,2)
		var bounds: Rect2 = option.get("preview_bounds",Rect2(0,0,2560,1440))
		var factor := Vector2(304,168)/bounds.size
		for feature: Dictionary in option.get("preview_regions",[]):
			var area: Rect2 = feature.area
			var dest := Rect2(Vector2(4,4)+(area.position-bounds.position)*factor,area.size*factor)
			var kind := str(feature.get("type","blocked"))
			var color := ink.darkened(0.5)
			if kind in ["slow","low_ground"]: color = Color("#426d85")
			elif kind in ["high_ground","attack_buff"]: color = Color("#9d8b56")
			elif kind in ["trap","hazard"]: color = Color("#b34f67")
			elif kind == "relay": color = Color("#c3a0ff")
			elif kind == "spring": color = Color("#87e9cf")
			elif kind == "wind_lane": color = Color("#aad8d7")
			elif kind == "hazard_lane": color = Color("#e39560")
			draw_rect(dest,color)
			draw_rect(dest,ink.darkened(0.15),false,1)
		var spawn: Vector2 = Vector2(4,4)+(Vector2(option.get("spawn",bounds.get_center()))-bounds.position)*factor
		draw_circle(spawn,6,Color("#f5e4ce"))
		draw_arc(spawn,11,0,TAU,24,ink,1.5,true)
func build(owner_hud) -> void:
	hud = owner_hud
	layer = 18
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = hud.get_child(0).theme
	add_child(root)
	root.hide()
func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(2)
	result.corner_radius_top_left = 3
	result.corner_radius_bottom_right = 3
	return result
func open(options: Array, selected: String = "blood_gate") -> void:
	for node: Node in root.get_children(): node.free()
	choices.clear()
	choices.assign(options)
	cards.clear()
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#0b0910")
	root.add_child(backdrop)
	hud.label(root,Vector2(74,39),Vector2(1000,22),"RIFT GUARD / ENDLESS EXPEDITION",12,Color("#ed526c"))
	hud.label(root,Vector2(72,71),Vector2(900,46),"选择无尽战场",34,Color("#f6e8df"))
	hud.label(root,Vector2(74,130),Vector2(1070,24),"三处荒原，三种走位节奏。地图结构不同，角色、觉醒与卡牌构筑沿用原规则。",14,Color("#c0a9b2"))
	var back: Button = hud.button(root,Rect2(1086,48,126,44),"返回  Esc",false)
	back.pressed.connect(func(): close(); cancelled.emit())
	var colors := [Color("#d9687e"),Color("#78c7df"),Color("#cdb985")]
	for index in range(choices.size()):
		var option: Dictionary = choices[index]
		var accent: Color = colors[index%colors.size()]
		var card: Button = hud.button(root,Rect2(72+index*388,182,360,443),"",false)
		card.name = "Layout_"+str(option.id)
		card.add_theme_stylebox_override("normal",_style(Color("#191520"),accent.darkened(0.45)))
		card.add_theme_stylebox_override("hover",_style(Color("#29202e"),accent))
		card.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),accent))
		card.add_theme_stylebox_override("pressed",_style(Color("#35242f"),Color("#ffe8d1")))
		hud.label(card,Vector2(24,21),Vector2(302,25),"0%d  /  ENDLESS" % (index+1),13,accent)
		hud.label(card,Vector2(24,55),Vector2(312,38),str(option.name),26,Color("#f4e6dd"))
		var preview := LayoutPreview.new()
		preview.position = Vector2(24,112)
		preview.option = option
		preview.ink = accent
		card.add_child(preview)
		var description: Label = hud.label(card,Vector2(24,310),Vector2(312,67),str(option.get("description","")),14,Color("#ccb8c2"))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hud.label(card,Vector2(24,393),Vector2(312,28),"选择队伍  →",17,accent)
		for child: Node in card.get_children():
			if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.pressed.connect(_choose.bind(index))
		cards.append(card)
	hud.label(root,Vector2(75,658),Vector2(1128,28),"生存 · 击杀 · 元素反应 · 精英狩猎 · 区域驻留     /     首领前预警与补给窗口",14,Color("#bfaab3"))
	root.show()
	for index in range(choices.size()):
		if str(choices[index].id) == selected: cards[index].grab_focus()
func _choose(index: int) -> void:
	if index<0 or index>=choices.size(): return
	close()
	chosen.emit(str(choices[index].id))
func close() -> void:
	if root != null: root.hide()
func is_open() -> bool:
	return root != null and root.visible
func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: close(); cancelled.emit()
		elif event.keycode in [KEY_1,KEY_2,KEY_3]: _choose(event.keycode-KEY_1)
