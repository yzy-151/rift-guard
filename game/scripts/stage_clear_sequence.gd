extends CanvasLayer

signal finished

const WHITE := Color("#f3e9df")
const ACCENT := Color("#ee7886")

var root: Control
var traveler: Control
var newcomer: Control
var door: Control
var title: Label
var subtitle: Label
var playing := false
var hud

func build(owner_hud) -> void:
	hud = owner_hud
	layer = 52
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.01, 0.025, 0.96)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)
	owner_hud.label(root, Vector2(55, 35), Vector2(600, 22), "C L E A R   /   通 往 下 一 区 域", 12, ACCENT)
	title = owner_hud.label(root, Vector2(55, 63), Vector2(800, 44), "裂隙之门正在开启", 28, WHITE)
	subtitle = owner_hud.label(root, Vector2(55, 110), Vector2(850, 28), "", 14, Color("#c6a5ac"))
	door = _build_door()
	traveler = _build_actor("旅", Color("#e7c88d"))
	traveler.position = Vector2(260, 350)
	newcomer = _build_actor("新", Color("#ed7785"))
	newcomer.position = Vector2(1050, 350)
	root.hide()

func _build_actor(glyph: String, color: Color) -> Control:
	var actor := Control.new()
	actor.size = Vector2(92, 92)
	root.add_child(actor)
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([Vector2(46, 0), Vector2(92, 46), Vector2(46, 92), Vector2(0, 46)])
	diamond.color = Color("#1a111a")
	actor.add_child(diamond)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([Vector2(46, 0), Vector2(92, 46), Vector2(46, 92), Vector2(0, 46), Vector2(46, 0)])
	outline.width = 4.0
	outline.default_color = color
	actor.add_child(outline)
	var face: Label = hud.label(actor, Vector2(0, 18), Vector2(92, 52), glyph, 32, color)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return actor

func _build_door() -> Control:
	var frame := Control.new()
	frame.position = Vector2(1025, 170)
	frame.size = Vector2(150, 310)
	root.add_child(frame)
	var glow := ColorRect.new()
	glow.position = Vector2(0, 0)
	glow.size = frame.size
	glow.color = Color("#ed7785")
	frame.add_child(glow)
	var opening := ColorRect.new()
	opening.position = Vector2(13, 16)
	opening.size = Vector2(124, 294)
	opening.color = Color("#07050a")
	frame.add_child(opening)
	var line := ColorRect.new()
	line.position = Vector2(62, 28)
	line.size = Vector2(5, 255)
	line.color = Color("#8f344a")
	frame.add_child(line)
	return frame

func is_playing() -> bool:
	return playing

func play(character_name: String, element: String) -> void:
	if playing:
		return
	playing = true
	root.show()
	title.text = "裂隙之门正在开启"
	subtitle.text = "新的同行者回应了旅行者。"
	traveler.position = Vector2(260, 350)
	newcomer.position = Vector2(1050, 350)
	newcomer.modulate = Color(1, 1, 1, 0)
	door.modulate = Color.WHITE
	door.scale = Vector2(0.12, 1.0)
	door.pivot_offset = door.size * Vector2(1.0, 0.5)
	var opening := create_tween()
	opening.tween_property(door, "scale:x", 1.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	opening.parallel().tween_property(door, "modulate", Color("#ffb2b8"), 0.55)
	await opening.finished
	var entrance := create_tween()
	entrance.set_parallel(true)
	entrance.tween_property(newcomer, "position", Vector2(790, 350), 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	entrance.tween_property(newcomer, "modulate:a", 1.0, 0.28)
	entrance.tween_property(traveler, "position", Vector2(590, 350), 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await entrance.finished
	title.text = "%s  已 解 锁" % character_name
	subtitle.text = "%s元素同行者加入可选角色，下一关可重新编队。" % element
	newcomer.scale = Vector2(1.18, 1.18)
	var unlock := create_tween()
	unlock.tween_property(newcomer, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await unlock.finished
	await get_tree().create_timer(0.75).timeout
	var exit := create_tween()
	exit.set_parallel(true)
	exit.tween_property(traveler, "position", Vector2(1060, 350), 0.9)
	exit.tween_property(newcomer, "position", Vector2(1100, 350), 0.9)
	exit.tween_property(traveler, "modulate:a", 0.0, 0.9)
	exit.tween_property(newcomer, "modulate:a", 0.0, 0.9)
	await exit.finished
	root.hide()
	traveler.modulate = Color.WHITE
	newcomer.scale = Vector2.ONE
	playing = false
	finished.emit()
