extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	var scene = load("res://starfall/main.tscn").instantiate()
	root.add_child(scene)
	scene.qa_mode = "controller"
	check(scene.ui.page=="title","title starts before combat")
	await scene.start_run({"mode":"campaign","squad":["traveler","hero_03","hero_08"]})
	check(scene.running and scene.sim.phase=="battle","native start enters real battle")
	scene.ui.hero_buttons[0].grab_focus()
	await press(KEY_SPACE)
	check(scene.paused and scene.ui.page=="pause","Space pauses even with focused HUD button")
	var time: float = scene.sim.time
	for i in range(4): await physics_frame
	check(scene.sim.time==time,"paused combat clock does not advance")
	scene._on_action("settings","pause")
	await press(KEY_ESCAPE)
	check(scene.ui.page=="pause" and scene.paused,"Escape settings returns to paused menu")
	await press(KEY_ESCAPE)
	check(not scene.paused and scene.ui.page=="battle","Escape resumes battle")
	scene.last_battle_mouse = Vector2(200,360)
	scene.arena.camera = scene.sim.heroes[0].pos
	scene.sim.heroes[0].q_cd = 0
	scene.sim.projectiles.clear()
	scene._on_action("q",null)
	check(not scene.sim.projectiles.is_empty(),"HUD skill invokes real attack")
	if not scene.sim.projectiles.is_empty():
		check(scene.sim.projectiles[0].vel.x<0,"HUD skill retains battlefield aim instead of aiming at button")
	scene.arena.camera += Vector2(1200,0)
	scene.sim.heroes[0].q_cd = 0
	scene.sim.projectiles.clear()
	scene._on_action("q",null)
	check(scene.sim.projectiles[0].vel.x>0,"stationary cursor aim follows camera movement")
	scene.sim.grant_xp(scene.sim.xp_needed+1)
	scene._sync_phase()
	check(scene.ui.page=="upgrade","level-up opens native selection")
	var choice: String = scene.sim.upgrade_choices[0].id
	scene._on_action("upgrade",choice)
	check(scene.ui.page=="battle" and scene.sim.upgrades.has(choice),"draft selection changes build and resumes")
	scene._on_action("title",null)
	check(not scene.running and scene.ui.page=="title","return title stops run")
	scene.music.stop()
	for voice in scene.voices: voice.stop()
	await create_timer(0.15).timeout
	scene.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS: Starfall controller input, pause, targeting and draft flow")
	quit(0 if failures.is_empty() else 1)
