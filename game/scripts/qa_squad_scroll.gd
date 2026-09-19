extends RefCounted

var checks := 0
var failures := 0

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		push_error("[FAIL] " + message)

func run(game) -> void:
	var panel = game.squad_panel
	var squad: Array[String] = ["traveler"]
	panel.open("stage_01", squad)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	var scroll_bar: VScrollBar = panel.grid_scroll.get_v_scroll_bar()
	_check(scroll_bar.max_value > scroll_bar.page, "character list has scrollable overflow")
	panel.grid_scroll.scroll_vertical = 0
	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	wheel_down.position = panel.grid_scroll.get_global_rect().get_center()
	panel._input(wheel_down)
	_check(panel.grid_scroll.scroll_vertical > 0, "wheel scroll works anywhere inside the squad list")
	var after_down: int = panel.grid_scroll.scroll_vertical
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	wheel_up.position = wheel_down.position
	panel._input(wheel_up)
	_check(panel.grid_scroll.scroll_vertical < after_down, "reverse wheel scroll works")
	print("SQUAD_SCROLL_TEST checks=%d failures=%d" % [checks, failures])
	game.get_tree().quit(failures)
