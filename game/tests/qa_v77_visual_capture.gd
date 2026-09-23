extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for frame in 6:
		await process_frame
	game.test_mode = true
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.compendium_panel.close()
	for id: String in ["traveler", "hero_01", "hero_03", "hero_08", "hero_10"]:
		game.compendium.unlocked_characters[id] = true
	var squad: Array[String] = ["traveler", "hero_01", "hero_03"]
	game.squad_panel.open("stage_endless", squad)
	for frame in 4:
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://../docs/v77-validation/endless-squad.png"))
	game.squad_panel.root.hide()
	game.compendium_panel.open("achievements")
	for frame in 4:
		await process_frame
	image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://../docs/v77-validation/achievement-wall.png"))
	quit()
