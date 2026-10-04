extends SceneTree
var game
var output := ""
var failures: Array[String] = []
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	if not output.is_absolute_path(): printerr("Provide absolute --qa-output"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); printerr("FAIL: " + label)
func capture(name: String) -> void:
	for i in range(5): await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.test_mode = true
	game.set_physics_process(false)
	for i in range(5): await process_frame
	game.enter_home()
	var home = game.home_panel
	var unlocks: Dictionary = game.compendium.unlocked_characters.duplicate()
	check(home.is_open(),"home entry remains accessible")
	await capture("home-base")
	home.player_pos = Vector2(2460,480)
	check(str(home.interaction_target().get("destination","")) == "harbor","walk to base exit offers harbor")
	check(await home.travel_to("harbor",false),"base exit opens harbor")
	home.player_pos = Vector2(650,535)
	home._update_camera()
	check(home.npcs.size()==3,"harbor has three distinct visitors")
	await capture("home-harbor")
	game.begin_home_interaction("hero_03")
	check(game.story.active and game.story.key=="explore_harbor_hero_03","visitor opens regional portrait dialogue")
	await create_timer(0.7).timeout
	game.dialogue.advance()
	await capture("home-harbor-dialogue")
	for i in range(12):
		if not game.story.active: break
		if game.story.has_choices():
			game.apply_dialogue_choice(game.story.current().choices[0])
			game.story.choose(0)
		else: game.story.advance()
	game.dialogue.close()
	var deadline := Time.get_ticks_msec()+12000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if game.dialogue.animation_waiting: game.dialogue.acknowledge_animation()
		if home.is_open() and not home.busy and game.pending_home_scene_key.is_empty() and not game.dialogue.comic_playing:
			break
	check(not home.busy,"dialogue transitions return control to the region")
	check(not game.dialogue.root.visible,"dialogue overlay closes before exploration resumes")
	check(home.exploration.completed.has("explore_harbor_hero_03"),"completed regional scene saved")
	check(await home.travel_to("garden",false),"harbor elevator opens garden")
	home.player_pos = Vector2(1570,535)
	home._update_camera()
	check(home.npcs.size()==4,"garden has four other visitors")
	await capture("home-garden")
	check(await home.travel_to("harbor",false) and await home.travel_to("base",false),"region exits return to original base")
	check(game.compendium.unlocked_characters==unlocks,"exploration never bypasses roster unlocks")
	game._stop_scene_audio(game)
	await create_timer(0.4).timeout
	print("V91 HOME FLOW: %d failures; portals, regional portrait dialogue, persistent journal, return" % failures.size())
	quit(0 if failures.is_empty() else 1)
