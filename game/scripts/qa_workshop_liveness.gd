extends SceneTree

const Session = preload("res://scripts/workshop_session.gd")
const Sim = preload("res://scripts/combat_simulation.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	print("PASS " + label if condition else "FAIL " + label)
	if not condition: failures.append(label)

func open_pair(session) -> Array[Vector2]:
	for y in range(280, 480, 20):
		for x in range(460, 920, 20):
			var point := Vector2(x, y)
			if session.legal(point, 40.0) and session.legal(point + Vector2(60, 0), 40.0) and session.legal(point + Vector2(0, 60), 25.0) and not session.sim.terrain_line_blocked(point, point + Vector2(60, 0)):
				return [point, point + Vector2(60, 0)]
	return []

func tick_seconds(session, seconds: float) -> void:
	for frame in range(roundi(seconds * 60.0)):
		session.tick(1.0 / 60.0)
		session.sim.drain_events()

func _run() -> void:
	var session = Session.new()
	session.enemy_action = false
	var points := open_pair(session)
	check(points.size() == 2, "find adjacent legal positions for real combat and movement")
	if points.is_empty(): quit(1); return
	check(session.place_hero("traveler", points[0]), "deploy traveler in isolated laboratory")
	var hero: Dictionary = session.sim.heroes[0]
	for count in range(12):
		check(session.place_enemy("grunt", points[1]), "place real grunt %02d" % count)
	# Exercise actual auto attacks, projectiles, kills, XP and level rewards for
	# longer than the reported 43.88-second freeze, without granting test XP.
	tick_seconds(session, 180.0)
	print("LIVE SUMMARY elapsed=%.2f state=%s kills=%d level=%d shots=%d" % [session.sim.elapsed, session.sim.state, session.sim.kills, session.sim.run_state.crystal_level, hero.shots])
	check(session.sim.kills >= 9, "automatic attacks actually kill enough enemies to trigger level growth")
	check(session.sim.run_state.crystal_level > 1, "real enemy kills award experience and grow the crystal level")
	check(session.sim.state == "running", "workshop level growth never enters inaccessible reward state")
	check(session.sim.elapsed > 179.9, "laboratory clock continues beyond 43.88 seconds and upgrades")
	check(not session.paused, "laboratory UI pause state remains consistent with live simulation")
	session.selected_kind = "hero"
	session.selected_id = 0
	var destination := points[0] + Vector2(0, 60)
	var before_move: Vector2 = hero.pos
	check(session.move_selected(destination), "post-upgrade movement command accepted")
	tick_seconds(session, 1.0)
	check(Vector2(hero.pos).distance_to(before_move) > 20.0 and Vector2(hero.pos).distance_to(destination) < 2.0, "post-upgrade hero truly reaches requested position")
	session.clear_units(true)
	check(session.place_enemy("grunt", destination + Vector2(20, 0)), "place post-upgrade attack target")
	var target: Dictionary = session.selected()
	var initial_hp := float(target.hp)
	var shots_before := int(hero.shots)
	tick_seconds(session, 3.0)
	check(int(hero.shots) > shots_before and float(target.hp) < initial_hp, "post-upgrade auto attacks deal real damage")
	# Explicit recovery is the escape hatch for a laboratory already frozen by
	# the old build; neither recover nor new level growth may toggle manual pause.
	session.paused = true
	for state: String in ["reward", "won", "lost"]:
		session.sim.state = state
		session.recover()
		check(session.sim.state == "running" and session.paused, "recover exits stale %s state while preserving manual pause" % state)
	session.sim.state = "paused"
	session.recover()
	check(session.sim.state == "paused" and session.paused, "recover does not override an explicit simulation pause")
	# The same XP path must keep the normal campaign's mandatory card selection.
	var campaign = Sim.new(9304, true)
	campaign.state = "running"
	var victim: Dictionary = campaign.spawn_enemy(points[1], "grunt")
	victim.xp = 100000
	campaign.apply_hit(victim, float(victim.max_hp) * 100.0, "", 0)
	check(campaign.kills == 1 and campaign.run_state.crystal_level > 1 and campaign.state == "reward" and not campaign.rewards.offered.is_empty(), "normal campaign kill and level still open card selection")
	if "--qa-workshop-visual" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await capture_live_workshop(session, points)
	print("WORKSHOP LIVENESS QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func capture_live_workshop(session, points: Array[Vector2]) -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true
	app.set_process(false)
	app.set_physics_process(false)
	app.open_settings()
	app.open_workshop()
	var panel = app.workshop
	check(panel != null, "real settings opens a workshop for post-upgrade input QA")
	if panel == null: return
	panel.set_physics_process(false)
	session.sim.state = "running"
	session.paused = false
	session.clear_units(true)
	session.selected_kind = "hero"
	session.selected_id = 0
	panel.session = session
	panel.battle.sim = session.sim
	panel.toggle_drawer()
	var before: Vector2 = session.sim.heroes[0].pos
	await click(panel.battle.world_to_screen(points[0]), MOUSE_BUTTON_RIGHT)
	check(Vector2(session.sim.heroes[0].target).distance_to(points[0]) < 1.0, "actual right-click input sets movement target after crystal upgrades")
	for frame in range(90): panel._physics_process(1.0 / 60.0)
	check(Vector2(session.sim.heroes[0].pos).distance_to(before) > 30.0 and Vector2(session.sim.heroes[0].pos).distance_to(points[0]) < 1.0, "actual panel physics advances a post-upgrade movement command")
	var clock := float(session.sim.elapsed)
	await key(KEY_SPACE)
	for frame in range(60): panel._physics_process(1.0 / 60.0)
	check(session.paused and is_equal_approx(session.sim.elapsed, clock), "manual workshop pause truly stops the battle clock")
	await key(KEY_PERIOD)
	check(session.paused and session.sim.elapsed > clock, "single-frame input advances paused simulation exactly once")
	await key(KEY_SPACE)
	check(not session.paused, "actual space input resumes a manually paused workshop")
	session.place_enemy("grunt", points[1])
	var target: Dictionary = session.selected()
	var hp_before := float(target.hp)
	for frame in range(180): panel._physics_process(1.0 / 60.0)
	check(float(target.hp) < hp_before, "actual panel physics keeps dealing damage after post-upgrade resume")
	session.selected_kind = "hero"
	session.selected_id = 0
	panel.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://../qa/story_review_20261005")
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join("workshop_after_upgrade.png"))
	panel.close()
	await process_frame

func click(point: Vector2, button: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		event.button_mask = button if pressed else 0
		root.push_input(event, true)
		await process_frame

func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
