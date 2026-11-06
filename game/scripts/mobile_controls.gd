extends CanvasLayer

signal move_mode_requested(all_heroes: bool)
signal interact_requested

var root: Control
var home_buttons: Array[Button] = []
var battle_buttons: Array[Button] = []
var move_button: Button
var squad_button: Button
var directions := {"left": false, "right": false, "up": false, "down": false}

func build(hud) -> void:
	layer = 60
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = hud.get_child(0).theme
	add_child(root)
	_add_direction(hud, "up", "▲", Vector2(83, 485))
	_add_direction(hud, "left", "◀", Vector2(18, 548))
	_add_direction(hud, "down", "▼", Vector2(83, 548))
	_add_direction(hud, "right", "▶", Vector2(148, 548))
	var interact: Button = hud.button(root, Rect2(1095, 532, 152, 64), "交互", false)
	interact.add_theme_font_size_override("font_size", 22)
	interact.pressed.connect(func(): interact_requested.emit())
	home_buttons.append(interact)
	move_button = hud.button(root, Rect2(1114, 455, 132, 52), "移动", false)
	move_button.add_theme_font_size_override("font_size", 18)
	move_button.pressed.connect(func(): move_mode_requested.emit(false))
	battle_buttons.append(move_button)
	squad_button = hud.button(root, Rect2(1114, 511, 132, 52), "全队移动", false)
	squad_button.add_theme_font_size_override("font_size", 15)
	squad_button.pressed.connect(func(): move_mode_requested.emit(true))
	battle_buttons.append(squad_button)
	update_modes(false, false, false, false)

func _add_direction(hud, direction: String, caption: String, position: Vector2) -> void:
	var button: Button = hud.button(root, Rect2(position, Vector2(60, 60)), caption, false)
	button.add_theme_font_size_override("font_size", 25)
	button.button_down.connect(func(): directions[direction] = true)
	button.button_up.connect(func(): directions[direction] = false)
	home_buttons.append(button)

func movement_axis() -> Vector2:
	return Vector2(float(directions.right) - float(directions.left), float(directions.down) - float(directions.up))

func update_modes(home_visible: bool, battle_visible: bool, moving: bool, moving_all: bool) -> void:
	for button in home_buttons:
		button.visible = home_visible
	for button in battle_buttons:
		button.visible = battle_visible
	if not home_visible:
		for direction in directions:
			directions[direction] = false
	move_button.text = "点地移动" if moving and not moving_all else "移动"
	squad_button.text = "点地全队移" if moving and moving_all else "全队移动"
