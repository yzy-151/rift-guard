extends SceneTree
var output := ""
var game
var failures: Array[String] = []
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=")
	if not output.is_absolute_path(): printerr("Provide absolute --qa-output"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); printerr("FAIL: "+label)
func capture(name: String) -> void:
	for i in range(6): await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.test_mode=true
	game.set_physics_process(false)
	for i in range(6): await process_frame
	game.choose_mode("endless_survival")
	check(game.endless_select_panel.is_open(),"main menu opens layout selection")
	check(game.endless_select_panel.cards.size()==3,"three map choices")
	await capture("endless-selection")
	for index in range(3):
		game.choose_mode("endless_survival")
		for settle in range(3): await process_frame
		var option: Dictionary=game.endless_select_panel.choices[index]
		var point: Vector2=game.endless_select_panel.cards[index].get_global_rect().get_center()
		for pressed: bool in [true,false]:
			var click:=InputEventMouseButton.new()
			click.position=point
			click.button_index=MOUSE_BUTTON_LEFT
			click.pressed=pressed
			root.push_input(click,true)
			await process_frame
		check(game.squad_panel.is_open(),str(option.id)+": map choice advances to original squad selection")
		check(game.sim.endless_layout_id==str(option.id),str(option.id)+": chosen layout reaches simulation")
		var squad: Array[String]=["traveler","hero_03","hero_04"]
		for id: String in squad: game.compendium.unlocked_characters[id]=true
		game.squad_panel.selected.assign(squad)
		game.squad_panel.confirm()
		check(not game.squad_panel.is_open() and game.hud.get_child(0).visible,"squad confirmation exposes battle map")
		check(game.sim.endless_mode,"original endless starts after squad confirmation")
		check(game.sim.endless_layout_id==str(option.id),"reset preserves chosen map")
		check(game.sim.heroes.all(func(hero:Dictionary)->bool:return bool(hero.deployed)),"original endless initial party retained")
		game.sim.start()
		for frame in range(120):
			game.sim.tick(1.0/30.0)
			game.process_events()
			if frame%12==0: game.refresh(); await process_frame
		game.refresh()
		await capture("endless-"+str(option.id))
		game.return_to_main_menu()
	game.choose_mode("endless_survival")
	var escape:=InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	game._input(escape)
	check(game.mode_select_panel.is_open() and not game.endless_select_panel.is_open(),"Escape returns without starting a run")
	game._stop_scene_audio(game)
	await create_timer(0.25).timeout
	print("V91 ENDLESS FLOW: %d failures; map selection, actual layouts, squad, return"%failures.size())
	quit(0 if failures.is_empty() else 1)
