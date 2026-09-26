extends CanvasLayer

signal interact_requested(character_id: String)
signal facility_requested(facility_id: String)
signal exit_requested

const Sequences = preload("res://scripts/character_sequence_library.gd")
const SpriteAnchor = preload("res://scripts/sprite_anchor.gd")
const MAP_WIDTH := 2560.0
const VIEW_WIDTH := 1280.0
const VIEW_HEIGHT := 720.0
const WALK_SPEED := 245.0
const TALK_RADIUS := 96.0
const FACILITY_RADIUS := 86.0
const FACILITIES := [
	{"id": "stages", "name": "作战终端", "x": 100.0, "action": "选择关卡"},
	{"id": "archive", "name": "档案台", "x": 1120.0, "action": "查看图鉴"},
	{"id": "achievements", "name": "成就墙", "x": 1540.0, "action": "查看成就"},
	{"id": "settings", "name": "控制台", "x": 2240.0, "action": "调整设置"},
]
const FLOOR_TILES: Array[Texture2D] = [
	preload("res://assets/world/endless/helltaker/labFloor0001.png"),
	preload("res://assets/world/endless/helltaker/labFloor0002.png"),
	preload("res://assets/world/endless/helltaker/labFloor0003.png"),
	preload("res://assets/world/endless/helltaker/labFloor0004.png"),
	preload("res://assets/world/endless/helltaker/labFloor0005.png"),
	preload("res://assets/world/endless/helltaker/labFloor0006.png"),
	preload("res://assets/world/endless/helltaker/labFloor0007.png"),
	preload("res://assets/world/endless/helltaker/labFloor0008.png"),
]
const WALL_TILE = preload("res://assets/world/endless/helltaker/labWall.png")
const WALL_VENT = preload("res://assets/world/endless/helltaker/wallVent.png")
const WALL_TUBE = preload("res://assets/world/endless/helltaker/wallTube.png")
const DISPLAY_FONT = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
const HOVER_AUDIO = preload("res://assets/helltaker/audio/button_dialogue_highlight_01.wav")
const CONFIRM_AUDIO = preload("res://assets/helltaker/audio/button_dialogue_confirm_01.wav")

class HomeInterior extends Node2D:
	var font: Font
	func _draw() -> void:
		draw_rect(Rect2(0, 0, MAP_WIDTH, VIEW_HEIGHT), Color("#0c0a16"))
		# The same 100px square floor modules used by the endless battle map.
		for col in 26:
			var x := float(col) * 100.0
			draw_texture_rect(WALL_TILE, Rect2(x, -70, 100, 400), false, Color(0.63, 0.59, 0.66))
			for row in 4:
				var index := 0 if (col + row) % 4 != 0 else 1 + posmod(col * 3 + row, 7)
				draw_texture_rect(FLOOR_TILES[index], Rect2(x, 320 + row * 100, 100, 100), false, Color(0.73, 0.68, 0.74))
		for x in [360.0, 960.0, 1560.0, 2160.0]:
			draw_texture_rect(WALL_TUBE, Rect2(x, 160, 100, 170), false, Color(0.81, 0.74, 0.82))
		for x in [650.0, 1250.0, 1850.0, 2450.0]:
			draw_texture_rect(WALL_VENT, Rect2(x, 179, 80, 120), false, Color(0.69, 0.64, 0.73))
		draw_line(Vector2(0, 320), Vector2(MAP_WIDTH, 320), Color("#cb3552"), 3.0)
		draw_rect(Rect2(0, 320, MAP_WIDTH, 400), Color(0.11, 0.04, 0.08, 0.16))
		_draw_interior_details()

	func _draw_interior_details() -> void:
		# Wall recesses and warm lamps keep furniture above the walking lane.
		for x in [180.0, 780.0, 1380.0, 1980.0, 2400.0]:
			draw_rect(Rect2(x - 90, 98, 180, 179), Color("#090e1c"))
			draw_rect(Rect2(x - 90, 98, 180, 179), Color("#555268"), false, 4)
			for pane in 3:
				draw_rect(Rect2(x - 79 + pane * 54, 110, 45, 150), Color("#202d43"))
				draw_line(Vector2(x - 73 + pane * 54, 115), Vector2(x - 40 + pane * 54, 145), Color("#34465b"), 3)
			draw_line(Vector2(x - 68, 278), Vector2(x + 68, 278), Color("#c99383"), 3)
		for zone in [{"x":30.0,"w":960.0,"title":"01 / 作战与会客区"},{"x":1030.0,"w":730.0,"title":"02 / 档案与荣誉区"},{"x":1800.0,"w":720.0,"title":"03 / 生活与整备区"}]:
			var x := float(zone.x)
			var width := float(zone.w)
			draw_rect(Rect2(x, 350, width, 270), Color(0.10, 0.12, 0.20, 0.30))
			draw_rect(Rect2(x + 12, 355, width - 24, 258), Color("#67515f"), false, 1)
			draw_line(Vector2(x + 25, 596), Vector2(x + width - 25, 596), Color("#a3465b"), 2)
			if font != null: draw_string(font, Vector2(x + 25, 87), str(zone.title), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#e0b9b2"))
		# Upholstered benches, low tables and bookcases; all are decorative.
		for x in [450.0, 850.0, 1980.0, 2400.0]:
			draw_rect(Rect2(x - 85, 296, 170, 47), Color("#151423"))
			draw_rect(Rect2(x - 79, 300, 158, 30), Color("#603748"))
			for cushion in 3: draw_rect(Rect2(x - 72 + cushion * 49, 329, 45, 19), Color("#865064"))
			draw_line(Vector2(x - 80, 351), Vector2(x + 80, 351), Color("#ba8290"), 3)
		for x in [1050.0, 1650.0]:
			draw_rect(Rect2(x - 40, 187, 80, 102), Color("#181725"))
			for row in 3:
				for book in 7:
					var ink := Color("#8a5566") if book % 2 == 0 else Color("#74869b")
					draw_rect(Rect2(x - 32 + book * 9, 194 + row * 30, 6, 22 - book % 3 * 3), ink)
				draw_line(Vector2(x - 36, 218 + row * 30), Vector2(x + 36, 218 + row * 30), Color("#a18888"), 2)
		for x in [30.0, 1010.0, 1780.0, 2510.0]:
			draw_rect(Rect2(x - 14, 312, 28, 29), Color("#745061"))
			for side in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(x,320),Vector2(x + side * 29,277),Vector2(x + side * 5,290)]),Color("#64867e"))

class HomeMap extends Node2D:
	var owner_panel
	var sequences
	var font: Font
	func _draw() -> void:
		for facility: Dictionary in FACILITIES:
			_draw_facility(facility)
		var actors: Array[Dictionary] = owner_panel.npcs.duplicate()
		actors.append({"id":"traveler","name":"你","pos":owner_panel.player_pos})
		actors.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.pos.y < b.pos.y)
		var closest: Dictionary = owner_panel.interaction_target()
		for actor: Dictionary in actors:
			var id := str(actor.id)
			var point: Vector2 = actor.pos
			var player := id == "traveler"
			var facing: float = owner_panel.facing if player else (1.0 if owner_panel.player_pos.x > point.x else -1.0)
			var active: bool = not player and str(closest.get("id","")) == id
			_draw_shadow(point + Vector2(0,7), 32.0, 9.0, Color(0,0,0,0.46))
			if active:
				_draw_shadow(point + Vector2(0,5), 38.0 + sin(owner_panel.elapsed * 3.0)*2.0, 10.0, Color(0.42,0.86,0.79,0.24))
			_draw_character(id, "run" if player and owner_panel.moving else "idle", point, facing)
			if font != null and not player:
				draw_string(font, point + Vector2(-60,-sequences.display_size(id)+10), str(actor.name), HORIZONTAL_ALIGNMENT_CENTER,120,16,Color("#fff0eb"))
				if active: draw_string(font, point + Vector2(-40,-sequences.display_size(id)-14), "[F] 对话", HORIZONTAL_ALIGNMENT_CENTER,80,15,Color("#a8e8d7"))

	func _draw_facility(facility: Dictionary) -> void:
		var center := Vector2(float(facility.x), 385.0)
		var active: bool = str(owner_panel.interaction_target().get("id", "")) == str(facility.id)
		var accent := Color("#ff5067") if active else Color("#8d3b51")
		draw_rect(Rect2(center.x - 75, 328, 150, 113), Color("#100d18"))
		draw_rect(Rect2(center.x - 75, 328, 150, 113), accent, false, 3.0)
		draw_rect(Rect2(center.x - 61, 342, 122, 55), Color("#1a1d30"))
		var glyph := Vector2(center.x, 368)
		match str(facility.id):
			"stages":
				draw_polyline(PackedVector2Array([glyph+Vector2(-36,12),glyph+Vector2(-16,-12),glyph+Vector2(7,8),glyph+Vector2(33,-16)]),Color("#9ad8cd"),3)
				for offset in [Vector2(-36,12),Vector2(-16,-12),Vector2(7,8),Vector2(33,-16)]:draw_circle(glyph+offset,4,Color("#f7d5a5"))
			"archive":
				for side in [-1.0,1.0]: draw_polyline(PackedVector2Array([glyph+Vector2(0,20),glyph+Vector2(side*30,13),glyph+Vector2(side*30,-17),glyph+Vector2(0,-10),glyph+Vector2(0,20)]),Color("#b3c9e0"),2)
			"achievements":
				draw_colored_polygon(PackedVector2Array([glyph+Vector2(-18,-18),glyph+Vector2(18,-18),glyph+Vector2(13,4),glyph+Vector2(0,13),glyph+Vector2(-13,4)]),Color("#d9b87d"))
				draw_line(glyph+Vector2(0,10),glyph+Vector2(0,21),Color("#d9b87d"),3)
				draw_line(glyph+Vector2(-12,21),glyph+Vector2(12,21),Color("#d9b87d"),3)
			"settings":
				for row in 3:
					var y := glyph.y-16+row*16
					draw_line(Vector2(glyph.x-33,y),Vector2(glyph.x+33,y),Color("#b6bbd1"),2)
					draw_circle(Vector2(glyph.x-16+row*15,y),4,accent)
		if font != null:
			draw_string(font, Vector2(center.x - 70, 423), str(facility.name), HORIZONTAL_ALIGNMENT_CENTER, 140, 17, Color("#fff0e9"))
			draw_string(font, Vector2(center.x - 70, 458), str(facility.action), HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color("#c9aab1"))

	func _draw_character(id: String, state: String, foot: Vector2, facing: float) -> void:
		var texture: Texture2D = sequences.texture(id, state)
		if texture == null:
			return
		var frame: int = sequences.frame_at_time(id, state, owner_panel.elapsed)
		var size: float = sequences.display_size(id)
		var placement: Dictionary = SpriteAnchor.placement(Vector2.ONE * size, sequences.cell(id), sequences.pivot(id), facing)
		var dest: Rect2 = placement.rect
		draw_set_transform(foot, 0.0, Vector2(float(placement.flip_x), 1.0))
		draw_texture_rect_region(texture, dest, sequences.source_rect(id, state, frame))
		draw_set_transform(Vector2.ZERO)

	func _draw_shadow(center: Vector2, rx: float, ry: float, color: Color) -> void:
		var points := PackedVector2Array()
		for i in 24:
			var angle := TAU * float(i) / 24.0
			points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		draw_colored_polygon(points, color)

var root: Control
var map: HomeMap
var interior: HomeInterior
var prompt: Label
var prompt_panel: Panel
var exit_button: Button
var hud
var database
var compendium
var sequences = Sequences.new()
var npcs: Array[Dictionary] = []
var player_pos := Vector2(130.0, 535.0)
var camera_x := 0.0
var elapsed := 0.0
var moving := false
var facing := 1.0
var busy := false
var hover_sound: AudioStreamPlayer
var confirm_sound: AudioStreamPlayer

func build(owner_hud, game_database, progress) -> void:
	hud = owner_hud
	database = game_database
	compendium = progress
	layer = 15
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	interior = HomeInterior.new()
	interior.font = root.theme.default_font
	root.add_child(interior)
	map = HomeMap.new()
	map.owner_panel = self
	map.sequences = sequences
	map.font = root.theme.default_font
	root.add_child(map)
	var header := Panel.new()
	header.position = Vector2.ZERO
	header.size = Vector2(VIEW_WIDTH, 66)
	header.add_theme_stylebox_override("panel", hud.hud_shelf_style(Color(0.018, 0.007, 0.012, 0.97), Color("#a5273d"), 1))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	var header_rule := ColorRect.new()
	header_rule.position = Vector2(16, 62)
	header_rule.size = Vector2(1248, 2)
	header_rule.color = Color("#ef3150")
	header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header_rule)
	var brand_accent := ColorRect.new()
	brand_accent.position = Vector2(22, 14)
	brand_accent.size = Vector2(4, 38)
	brand_accent.color = Color("#ff3655")
	brand_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brand_accent)
	var brand: Label = hud.label(root, Vector2(35, 8), Vector2(195, 33), "裂 隙 守 望", 23, Color("#fff1e8"))
	brand.add_theme_font_override("font", DISPLAY_FONT)
	hud.label(root, Vector2(37, 43), Vector2(190, 16), "RIFT GUARD  /  HOME", 9, Color("#ff526a"))
	var separator := ColorRect.new()
	separator.position = Vector2(232, 15)
	separator.size = Vector2(1, 42)
	separator.color = Color("#6e2637")
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(separator)
	var title: Label = hud.label(root, Vector2(252, 7), Vector2(390, 26), "基地 / HOME", 17, Color("#fff1e8"))
	title.add_theme_font_override("font", DISPLAY_FONT)
	hud.label(root, Vector2(252, 36), Vector2(685, 18), "WASD / 方向键移动  ·  靠近角色或设施按 F 交互", 10, Color("#c9abb3"))
	exit_button = hud.button(root, Rect2(1123, 12, 132, 44), "返回", false)
	hud.apply_compact_hud_button_style(exit_button)
	exit_button.pressed.connect(func(): exit_requested.emit())
	prompt_panel = Panel.new()
	prompt_panel.position = Vector2(432, 637)
	prompt_panel.size = Vector2(416, 40)
	prompt_panel.add_theme_stylebox_override("panel", hud.counter_badge_style())
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_panel)
	prompt = hud.label(prompt_panel, Vector2(12, 4), Vector2(392, 32), "", 17, Color("#fff4e7"))
	prompt.add_theme_font_override("font", DISPLAY_FONT)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_panel.hide()
	hover_sound = AudioStreamPlayer.new()
	hover_sound.stream = HOVER_AUDIO
	hover_sound.bus = "SFX"
	add_child(hover_sound)
	confirm_sound = AudioStreamPlayer.new()
	confirm_sound.stream = CONFIRM_AUDIO
	confirm_sound.bus = "SFX"
	add_child(confirm_sound)
	root.hide()

func refresh_residents() -> void:
	npcs.clear()
	var unlocked: Array[String] = []
	for id: String in database.characters:
		if id == "traveler":
			continue # The player already represents the Traveler on this map.
		if compendium.unlocked_characters.has(id) and bool(database.characters[id].get("content_ready", false)) and sequences.has_character(id):
			unlocked.append(id)
	unlocked.sort()
	# Leave sight lines and F interaction space around the three terminals.
	var resident_slots := [300.0, 500.0, 700.0, 900.0, 1270.0, 1420.0, 1740.0, 1900.0, 2060.0, 2390.0, 1160.0, 1580.0]
	for index in unlocked.size():
		var id := unlocked[index]
		var x: float = resident_slots[index] if index < resident_slots.size() else 300.0 + float(index % 10) * 220.0
		var y := 548.0 + float(index % 3 - 1) * 64.0
		npcs.append({"id": id, "name": str(database.characters[id].get("name", id)), "pos": Vector2(x, y)})
	map.queue_redraw()

func open() -> void:
	refresh_residents()
	busy = false
	root.show()
	_update_camera()

func close() -> void:
	root.hide()

func is_open() -> bool:
	return root != null and root.visible

func nearest_resident() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := TALK_RADIUS
	for npc: Dictionary in npcs:
		var distance := player_pos.distance_to(npc.pos)
		if distance < best_distance:
			best = npc
			best_distance = distance
	return best

func nearest_facility() -> Dictionary:
	var best: Dictionary = {}
	var distance := FACILITY_RADIUS
	for facility: Dictionary in FACILITIES:
		var check := player_pos.distance_to(Vector2(float(facility.x), 480.0))
		if check < distance:
			best = facility
			distance = check
	return best

func handle_input(event: InputEvent) -> bool:
	if not is_open():
		return false
	if busy:
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			confirm_sound.play()
			exit_requested.emit()
			return true
		if event.keycode == KEY_F:
			var target := interaction_target()
			if not target.is_empty():
				confirm_sound.play()
				busy = true
				if target.has("action"): facility_requested.emit(str(target.id))
				else: interact_requested.emit(str(target.id))
			return true
	return event is InputEventKey and event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]

func _process(dt: float) -> void:
	if not is_open() or busy:
		return
	elapsed += dt
	var axis := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): axis.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): axis.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): axis.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): axis.y += 1.0
	move_player(axis, dt)
	_update_camera()
	map.queue_redraw()
	var target := interaction_target()
	prompt.text = ""
	if not target.is_empty():
		prompt.text = "[F]  %s" % str(target.action) if target.has("action") else "[F]  与 %s 对话" % str(target.name)
	prompt_panel.visible = not prompt.text.is_empty()

func interaction_target() -> Dictionary:
	var npc := nearest_resident()
	var facility := nearest_facility()
	if not facility.is_empty() and (npc.is_empty() or player_pos.distance_to(Vector2(float(facility.x),480.0)) < player_pos.distance_to(npc.pos)):
		return facility
	return npc

func move_player(axis: Vector2, dt: float) -> void:
	moving = axis.length_squared() > 0.0
	if not moving: return
	if absf(axis.x) > 0.01: facing = signf(axis.x)
	player_pos += axis.normalized() * WALK_SPEED * dt
	player_pos.x = clampf(player_pos.x, 30.0, MAP_WIDTH - 30.0)
	player_pos.y = clampf(player_pos.y, 398.0, 635.0)

func _update_camera() -> void:
	camera_x = clampf(player_pos.x - VIEW_WIDTH * 0.5, 0.0, MAP_WIDTH - VIEW_WIDTH)
	map.position.x = -camera_x
	interior.position.x = -camera_x
