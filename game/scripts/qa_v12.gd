extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V12 PASS: " + message)
	else:
		failures += 1
		push_error("V12 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.refresh()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v12-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	var sim = game.sim
	var solo: Array[String] = ["traveler"]
	expect(game.content.loaded, "embedded Excel configuration loads without a missing-file warning")

	game.open_mode_menu()
	expect(game.mode_select_panel.is_open() and game.mode_select_panel.buttons.size() == 2, "startup menu exposes campaign and endless modes")
	await capture(game, "00-mode-menu")
	game.mode_select_panel.root.hide()
	game.hud.get_child(0).show()

	var runtime = preload("res://scripts/stages/stage_runtime.gd").new(sim.database.stages["stage_01"])
	var early: Array[Dictionary] = runtime.tick(1.0)
	expect(early.any(func(event: Dictionary) -> bool: return event.kind == "route_warning"), "route warning appears before the first enemy")
	expect(not early.any(func(event: Dictionary) -> bool: return event.kind == "spawn"), "route warning does not reveal the route during active combat")
	var later: Array[Dictionary] = runtime.tick(3.1)
	expect(later.any(func(event: Dictionary) -> bool: return event.kind == "spawn"), "enemy enters after the warning lead time")

	sim.reset_stage("stage_01", solo, 1201)
	sim.state = "running"
	game.battle.accept_events(early)
	expect(not game.battle.route_previews.is_empty() and not game.battle.spawn_portals.is_empty(), "warning drives animated route and portal state")
	await capture(game, "01-dynamic-route-warning")
	game.battle.advance(5.0)
	expect(game.battle.route_previews.is_empty(), "route overlay disappears after the warning window")
	await capture(game, "02-terrain-route-beds")

	game.selected_id = 0
	await capture(game, "03-exact-attack-range")

	sim.state = "won"
	game.play_stage_exit()
	expect(sim.state == "stage_exit" and game.battle.stage_exit_active, "victory returns to the battlefield for interactive recruitment")
	game.battle.advance(1.05)
	expect(game.battle.stage_exit_phase == "waiting", "new character walks out of the animated door")
	await capture(game, "04-interactive-recruitment")
	sim.heroes[0].pos = game.battle.STAGE_EXIT_MEET
	game.battle.advance(0.02)
	game.battle.advance(1.4)
	expect(game.squad_panel.is_open() and game.pending_stage_id == "stage_02", "meeting the newcomer opens the next-stage squad screen")
	expect(not game.squad_panel.buttons["hero_02"].disabled, "newly unlocked character is immediately selectable")
	game.squad_panel.buttons["hero_02"].pressed.emit()
	expect("hero_02" in game.squad_panel.selected and game.squad_panel.selected.size() == 2, "real character button adds the newcomer to the squad")
	await capture(game, "05-next-stage-squad-selected")
	game.squad_panel.confirm_button.pressed.emit()
	expect(sim.current_stage_id == "stage_02" and sim.heroes.size() == 2, "confirming the real button flow loads stage two with both characters")
	if game.story.active:
		game.story.active = false
		game.dialogue.root.hide()
	game.sim.state = "ready"

	game.open_mode_menu()
	game.mode_select_panel.buttons["endless_survival"].pressed.emit()
	expect(sim.current_stage_id == "stage_endless" and sim.endless_mode, "endless mode starts directly from the startup menu")
	await capture(game, "06-endless-from-menu")

	print("V12 TESTS: %d checks; %d failures" % [checks, failures])
	var tree = game.get_tree()
	game.queue_free()
	await tree.process_frame
	tree.quit(0 if failures == 0 else 1)
