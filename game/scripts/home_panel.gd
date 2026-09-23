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

class HomeMap extends Node2D:
	var owner_panel
	var sequences
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
		for facility: Dictionary in FACILITIES:
			_draw_facility(facility)
		for npc: Dictionary in owner_panel.npcs:
			var id := str(npc.id)
			var point: Vector2 = npc.pos
			_draw_shadow(point + Vector2(0, 7), 41.0, 11.0, Color(0, 0, 0, 0.46))
			_draw_character(id, "idle", point)
			if font != null:
				draw_string(font, point + Vector2(-48, -sequences.display_size(id) + 10), str(npc.name), HORIZONTAL_ALIGNMENT_CENTER, 96, 17, Color("#fff0eb"))
		var player: Vector2 = owner_panel.player_pos
		_draw_shadow(player + Vector2(0, 7), 32.0, 9.0, Color(0, 0, 0, 0.55))
		_draw_character("traveler", "run" if owner_panel.moving else "idle", player)
		if font != null:
			draw_string(font, player + Vector2(-35, -sequences.display_size("traveler") + 10), "你", HORIZONTAL_ALIGNMENT_CENTER, 70, 17, Color.WHITE)

	func _draw_facility(facility: Dictionary) -> void:
		var center := Vector2(float(facility.x), 385.0)
		var active: bool = owner_panel.player_pos.distance_to(Vector2(center.x, 480.0)) < FACILITY_RADIUS
		var accent := Color("#ff5067") if active else Color("#8d3b51")
		draw_rect(Rect2(center.x - 75, 328, 150, 113), Color("#100d18"))
		draw_rect(Rect2(center.x - 75, 328, 150, 113), accent, false, 3.0)
		draw_rect(Rect2(center.x - 61, 342, 122, 55), Color("#1a1d30"))
		draw_line(Vector2(center.x - 48, 362), Vector2(center.x + 48, 362), accent, 2.0)
		draw_line(Vector2(center.x - 34, 377), Vector2(center.x + 34, 377), accent.darkened(0.3), 2.0)
		if font != null:
			draw_string(font, Vector2(center.x - 70, 423), str(facility.name), HORIZONTAL_ALIGNMENT_CENTER, 140, 17, Color("#fff0e9"))
			draw_string(font, Vector2(center.x - 70, 458), str(facility.action), HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color("#c9aab1"))

	func _draw_character(id: String, state: String, foot: Vector2) -> void:
		var texture: Texture2D = sequences.texture(id, state)
		if texture == null:
			return
		var frame: int = sequences.frame_at_time(id, state, owner_panel.elapsed)
		var size: float = sequences.display_size(id)
		var placement: Dictionary = SpriteAnchor.placement(Vector2.ONE * size, sequences.cell(id), sequences.pivot(id), 1.0)
		var dest: Rect2 = placement.rect
		dest.position += foot
		draw_texture_rect_region(texture, dest, sequences.source_rect(id, state, frame))

	func _draw_shadow(center: Vector2, rx: float, ry: float, color: Color) -> void:
		var points := PackedVector2Array()
		for i in 24:
			var angle := TAU * float(i) / 24.0
			points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		draw_colored_polygon(points, color)

var root: Control
var map: HomeMap
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
	var resident_slots := [300.0, 500.0, 700.0, 900.0, 1320.0, 1760.0, 1950.0, 2070.0, 2450.0]
	for index in unlocked.size():
		var id := unlocked[index]
		var x: float = resident_slots[index] if index < resident_slots.size() else 300.0 + float(index) * 210.0
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
			var npc := nearest_resident()
			var facility := nearest_facility()
			if not facility.is_empty() and (npc.is_empty() or player_pos.distance_to(Vector2(float(facility.x), 480.0)) < player_pos.distance_to(npc.pos)):
				confirm_sound.play()
				busy = true
				facility_requested.emit(str(facility.id))
			elif not npc.is_empty():
				confirm_sound.play()
				busy = true
				interact_requested.emit(str(npc.id))
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
	moving = axis.length_squared() > 0.0
	if moving:
		player_pos += axis.normalized() * WALK_SPEED * dt
		player_pos.x = clampf(player_pos.x, 30.0, MAP_WIDTH - 30.0)
		player_pos.y = clampf(player_pos.y, 398.0, 635.0)
	_update_camera()
	map.queue_redraw()
	var npc := nearest_resident()
	var facility := nearest_facility()
	if not facility.is_empty() and (npc.is_empty() or player_pos.distance_to(Vector2(float(facility.x), 480.0)) < player_pos.distance_to(npc.pos)):
		prompt.text = "[F]  %s" % str(facility.action)
	elif not npc.is_empty():
		prompt.text = "[F]  与 %s 对话" % str(npc.name)
	else:
		prompt.text = ""
	prompt_panel.visible = not prompt.text.is_empty()

func _update_camera() -> void:
	camera_x = clampf(player_pos.x - VIEW_WIDTH * 0.5, 0.0, MAP_WIDTH - VIEW_WIDTH)
	map.position.x = -camera_x
