extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var isolated := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output=") and arg.trim_prefix("--qa-output=").is_absolute_path(): isolated = true
	if not isolated:
		printerr("Shell QA changes window preferences; provide an absolute --qa-output to isolate player settings.")
		quit(2)
		return
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)

func wait_scene(path: String) -> bool:
	var deadline := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if current_scene!=null and current_scene.scene_file_path==path:
			for i in range(4): await process_frame
			return true
	return false

func run() -> void:
	check(str(ProjectSettings.get_setting("application/run/main_scene"))=="res://main.tscn","original V86 shell is the default entry")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.test_mode = true
	for i in range(6): await process_frame
	check(game.mode_select_panel.is_open(),"original red-black mode screen opens")
	check(game.mode_select_panel.buttons.has("rift_watch") and game.mode_select_panel.buttons.has("endless_survival"),"original two mode entries remain")
	check(game.mode_select_panel.starfall_button!=null,"additional Starfall entry exists")
	game.mode_select_panel.continue_button.pressed.emit()
	check(game.home_panel.is_open(),"original home opens through its original entry")
	game.return_to_main_menu()
	game.choose_mode("rift_watch")
	check(game.stage_select_panel.is_open(),"original campaign still opens stage selection")
	game.choose_stage("stage_01")
	check(game.squad_panel.is_open(),"original campaign still opens original squad selection")
	game.return_to_main_menu()
	check(not game.hud.buff_icons.is_empty(),"original in-battle upgrade icon controls remain")
	game.audio_director.set_setting("fullscreen", true)
	game.choose_mode("starfall")
	var reached := await wait_scene("res://starfall/main.tscn")
	check(reached,"additional mode launches after original transition animation")
	if reached:
		var extra = current_scene
		extra.qa_mode = "shell_check"
		check(extra.ui.page=="title","additional mode retains its own title screen")
		if DisplayServer.get_name().to_lower() != "headless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		extra._on_action("legacy",null)
		check(await wait_scene("res://main.tscn"),"additional mode returns to original shell")
	if current_scene!=null and current_scene.scene_file_path=="res://main.tscn":
		check(current_scene.mode_select_panel.is_open(),"return lands on original mode menu")
		if DisplayServer.get_name().to_lower() != "headless":
			check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"classic fullscreen preference restored after additional mode")
		current_scene.audio_director.set_setting("fullscreen", false)
		current_scene._stop_scene_audio(current_scene)
	await create_timer(0.2).timeout
	if failures.is_empty(): print("PASS: V86 menu, home, campaign selection, original icon controls, Starfall roundtrip")
	quit(0 if failures.is_empty() else 1)
