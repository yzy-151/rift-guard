extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V8 PASS: " + message)
	else:
		failures += 1
		push_error("V8 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v8-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	game.compendium.unlocked_characters = {"traveler": true}
	game.compendium.cleared_stages.clear()
	game.compendium.stage_records.clear()
	game.sim.state = "ready"
	game.open_stage_select()
	expect(game.stage_select_panel.is_open(), "F4 opens the Helltaker mission screen")
	expect(not game.stage_select_panel.buttons["stage_01"].disabled, "first mission is available by default")
	expect(game.stage_select_panel.buttons["stage_02"].disabled and game.stage_select_panel.buttons["stage_03"].disabled, "future missions remain locked")
	await capture(game, "01-locked-missions")
	game.stage_select_panel.close()
	game.compendium.clear_stage("stage_01", ["hero_02"])
	game.compendium.clear_stage("stage_02", ["hero_03"])
	game.compendium.record_result("stage_01", 243, 88, 25)
	game.open_stage_select()
	expect(not game.stage_select_panel.buttons["stage_02"].disabled and not game.stage_select_panel.buttons["stage_03"].disabled, "cleared missions unlock the full chapter")
	expect("最高基地 88%" in game.stage_select_panel.status_labels["stage_01"].text, "mission card displays the saved best result")
	await capture(game, "02-unlocked-missions-and-records")
	game.stage_select_panel.select("stage_02")
	expect(game.squad_panel.is_open() and game.pending_stage_id == "stage_02", "mission selection flows directly into squad selection")
	await capture(game, "03-mission-to-squad")
	print("V8 UI TESTS: %d checks; %d failures" % [checks, failures])
	var tree = game.get_tree()
	game.queue_free()
	await tree.process_frame
	tree.quit(0 if failures == 0 else 1)
