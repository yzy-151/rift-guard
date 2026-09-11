extends CanvasLayer

signal option_chosen(option: Dictionary)
signal closed

const WHITE := Color("#f3e9df")
const MUTED := Color("#b59ba3")
const ACCENT := Color("#ef6b7c")

var root: Control
var hud
var title: Label
var detail: Label
var currency: Label
var option_buttons: Array[Button] = []
var options: Array[Dictionary] = []
var close_button: Button
var resolved := false
var selected_index: int = -1

func build(owner_hud) -> void:
	hud = owner_hud
	layer = 58
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	var background := TextureRect.new()
	background.texture = preload("res://assets/helltaker/backgrounds/chapterBG0008.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(background)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.025,0.010,0.022,0.91)
	root.add_child(veil)
	var frame: Panel = owner_hud.panel(root,Rect2(115,72,1050,580),Color("#181118"),Color("#b64c61"))
	owner_hud.ornament(frame,Rect2(-20,-18,1090,616))
	owner_hud.label(frame,Vector2(42,26),Vector2(700,20),"E N C O U N T E R   /   远 征 事 件",11,ACCENT)
	title = owner_hud.label(frame,Vector2(42,58),Vector2(720,45),"战役节点",31,WHITE)
	detail = owner_hud.label(frame,Vector2(42,107),Vector2(940,50),"选择一项结果。",13,MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	currency = owner_hud.label(frame,Vector2(765,61),Vector2(235,30),"",15,Color("#f4c873"))
	currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for i in 3:
		var button: Button = owner_hud.button(frame,Rect2(42+i*326,185,302,270),"",true)
		button.pressed.connect(_choose.bind(i))
		option_buttons.append(button)
	close_button = owner_hud.button(frame,Rect2(716,492,284,46),"返回裂隙路线",false)
	close_button.pressed.connect(close)
	root.hide()

func open(node: Dictionary, rows: Array[Dictionary], shards: int) -> void:
	options = rows.duplicate(true)
	resolved = false
	selected_index = -1
	title.text = {"shop":"裂隙商店","rest":"篝火休整","recruit":"同行者招募","hidden":"未知信号"}.get(str(node.get("type","")),"远征事件")
	detail.text = "每个节点只能选择一次；效果在后续关卡继续生效。"
	currency.text = "裂隙币  ◇ %03d" % shards
	for i in option_buttons.size():
		var button: Button = option_buttons[i]
		button.visible = i < options.size()
		button.disabled = not button.visible
		button.modulate = Color.WHITE
		if i < options.size():
			var option: Dictionary = options[i]
			button.text = "%02d\n\n%s\n\n%s\n\n%s" % [i+1,str(option.name),str(option.description),("◇ %d" % int(option.cost)) if int(option.cost)>0 else "无消耗"]
	root.modulate = Color(1,1,1,0)
	root.show()
	create_tween().tween_property(root,"modulate",Color.WHITE,0.16)
	if not option_buttons.is_empty(): option_buttons[0].grab_focus()

func _choose(index: int) -> void:
	if resolved or index < 0 or index >= options.size(): return
	selected_index = index
	option_chosen.emit(options[index])

func show_result(result: Dictionary, shards: int) -> void:
	currency.text = "裂隙币  ◇ %03d" % shards
	detail.text = str(result.get("message","节点已结算。"))
	if bool(result.get("ok",false)):
		resolved = true
		for i in option_buttons.size():
			var button: Button = option_buttons[i]
			button.disabled = true
			button.modulate = Color.WHITE if i == selected_index else Color(0.76,0.70,0.73,0.86)
		close_button.text = "继续前进   →"
	else:
		var tween := create_tween()
		tween.tween_property(detail,"modulate",Color("#ff7182"),0.08)
		tween.tween_property(detail,"modulate",Color.WHITE,0.16)

func activate_at(point: Vector2) -> bool:
	if not is_open(): return false
	if close_button.get_global_rect().has_point(point): close(); return true
	for i in option_buttons.size():
		if option_buttons[i].visible and not option_buttons[i].disabled and option_buttons[i].get_global_rect().has_point(point): _choose(i); return true
	return false

func handle_input(event: InputEvent) -> bool:
	if not is_open(): return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: close(); return true
		if event.keycode in [KEY_1,KEY_2,KEY_3]: _choose(event.keycode-KEY_1); return true
	return false

func close() -> void:
	if not is_open(): return
	root.hide()
	closed.emit()

func is_open() -> bool:
	return root != null and root.visible
