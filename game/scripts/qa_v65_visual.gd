extends RefCounted

var checks := 0
var failures := 0
var output_dir := ""

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V65 VISUAL PASS: " + message)
	else:
		failures += 1
		push_error("V65 VISUAL FAIL: " + message)

func capture(game, name: String) -> void:
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	await game.get_tree().create_timer(0.10).timeout
	var image: Image = game.get_viewport().get_texture().get_image()
	expect(image != null, name + " frame available")
	if image != null:
		if image.get_size() != Vector2i(1920, 1080):
			image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
		expect(image.save_png(output_dir.path_join(name + ".png")) == OK, name + " screenshot written")

func run(game) -> void:
	output_dir = ProjectSettings.globalize_path("res://../docs/v65-validation")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var squad: Array[String] = ["traveler", "hero_01", "hero_07"]
	for stage_number in range(1, 9):
		game.sim.reset_stage("stage_%02d" % stage_number, squad, 6550 + stage_number)
		game.sim.start()
		game.sim.state = "running"
		for hero: Dictionary in game.sim.heroes:
			hero.deployed = true
		game.selected_id = 0
		game.hud.signature = ""
		game.refresh()
		game.hud.overlay.hide()
		await capture(game, "stage-%02d" % stage_number)
	print("V65 VISUAL COMPLETE: %d checks, %d failures -> %s" % [checks, failures, output_dir])
	game.get_tree().quit(failures)
