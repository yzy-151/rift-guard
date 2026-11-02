extends SceneTree
var app
func _initialize() -> void: run.call_deferred()
func run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false); app.set_physics_process(false)
	app.open_mode_menu(); app.choose_mode("rift_watch")
	await process_frame
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE; event.pressed = true
	root.push_input(event, true)
	await process_frame
	print("BASELINE stage Escape returns menu: ", app.mode_select_panel.is_open())
	print("BASELINE pause squad available: ", app.hud.pause_presentation.actions.has("squad"))
	print("BASELINE pause stages available: ", app.hud.pause_presentation.actions.has("stages"))
	app.mode_select_panel.close(); app.sim.start(); app.sim.toggle_pause(); app.refresh()
	app.open_current_squad()
	root.push_input(event, true)
	await process_frame
	print("BASELINE squad Escape closes squad: ", not app.squad_panel.is_open())
	await app._quit_after_audio_cleanup(0)
