extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V7 PASS: " + message)
	else:
		failures += 1
		push_error("V7 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.refresh()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v7-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func wait_frames(game, count: int) -> void:
	for frame in count:
		await game.get_tree().process_frame

func run(game) -> void:
	game.compendium.unlocked_characters = {"traveler": true}
	var opening_squad: Array[String] = ["traveler"]
	game.sim.reset_stage("stage_01", opening_squad, 707)
	game.sim.state = "won"
	game.stage_result_recorded = true
	game.advance_stage()
	expect(game.squad_panel.is_open(), "clearing a stage opens the Helltaker squad screen")
	expect(game.compendium.unlocked_characters.has("hero_02"), "stage reward unlocks the next character before selection")
	expect(game.squad_panel.buttons.size() == 8, "all eight selectable characters appear in the roster")
	expect(game.squad_panel.buttons["hero_03"].disabled, "future characters remain locked")
	expect(game.squad_panel.selected == ["traveler"], "Traveler is mandatory and starts selected")
	await capture(game, "01-unlock-and-squad-select")
	game.squad_panel.toggle("hero_02")
	expect(game.squad_panel.selected == ["traveler", "hero_02"], "an unlocked character can join the squad")
	game.squad_panel.toggle("traveler")
	expect("traveler" in game.squad_panel.selected, "Traveler cannot be removed")
	game.squad_panel.confirm()
	expect(game.sim.current_stage_id == "stage_02", "confirmation loads the next stage")
	expect(game.sim.run_state.squad == ["traveler", "hero_02"], "selected squad reaches combat runtime")
	expect(game.sim.run_state.buff_levels.is_empty(), "new stage starts with a clean build")
	expect(game.story.active and game.story.key == "mode1_stage2_opening", "next-stage dialogue plays after squad confirmation")
	await wait_frames(game, 25)
	await capture(game, "02-selected-squad-dialogue")
	game.story.skip()
	game.dialogue.root.hide()
	var second_stage: Dictionary = game.sim.database.stages["stage_02"]
	game.compendium.clear_stage("stage_02", second_stage.unlocks)
	var final_stage: Dictionary = game.sim.database.stages["stage_03"]
	game.compendium.clear_stage("stage_03", final_stage.unlocks)
	expect(game.compendium.unlocked_characters.size() == 8, "final victory unlocks the complete eight-character roster")
	var replay_squad: Array[String] = ["traveler", "hero_05", "hero_07"]
	game.sim.reset_stage("stage_03", replay_squad, 708)
	game.open_current_squad()
	expect(game.squad_panel.is_open(), "F3 can rebuild the current stage squad for replay")
	expect(not game.squad_panel.buttons["hero_08"].disabled, "all final roster choices are selectable")
	await capture(game, "03-full-roster-replay")
	print("V7 UI TESTS: %d checks; %d failures" % [checks, failures])
	var tree = game.get_tree()
	game.queue_free()
	await tree.process_frame
	tree.quit(0 if failures == 0 else 1)
