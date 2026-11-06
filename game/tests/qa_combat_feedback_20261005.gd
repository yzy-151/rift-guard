extends SceneTree

const OUT := "res://../qa/combat_reference_20261005"
var output_directory := ""
var failures: Array[String] = []
var checks := 0
var app

func _initialize() -> void:
	output_directory = ProjectSettings.globalize_path(OUT)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output_directory = arg.trim_prefix("--qa-output=")
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	print(("PASS " if condition else "FAIL ") + label)
	if not condition: failures.append(label)

func run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.test_mode = true
	app.set_process(false)
	app.set_physics_process(false)
	app.mode_select_panel.close()
	app.stage_select_panel.close()
	app.squad_panel.root.hide()
	app.dialogue.hide()
	app.hud.get_child(0).show()
	var sim = app.sim
	var squad: Array[String] = ["traveler", "hero_03"]
	sim.reset_stage("stage_01", squad, 62317)
	sim.start()
	check(sim.heroes.any(func(h): return h.character_id == "hero_13" and bool(h.deployed)), "first stage starts with Gwen deployed")
	check(not sim.run_state.squad.has("hero_13"), "Gwen assist does not overwrite selected permanent squad")
	var numbers = app.battle.damage_numbers
	var point := Vector2(660, 370)
	var hits: Array[Dictionary] = [
		{"kind":"hit", "pos":point, "enemy_id":811, "value":121, "critical":false},
		{"kind":"hit", "pos":point, "enemy_id":812, "value":248, "critical":true},
		{"kind":"critical", "pos":point, "enemy_id":812, "value":248},
		{"kind":"hit", "pos":point, "enemy_id":811, "value":15, "critical":false},
		{"kind":"hurt", "pos":point, "hero_id":1, "value":19}]
	numbers.clear()
	app.battle.accept_events(hits)
	check(numbers.active.size() == 3, "critical flash produces no duplicate number; distinct victims stay separate")
	check(numbers.active[0].value == 136, "rapid hits on the same victim preserve the exact combined value")
	check(numbers.active[1].critical and numbers.active[1].value == 248, "critical owns actual damage value")
	check(numbers.font.resource_path.ends_with("BarlowCondensed-Black.ttf"), "bold numeric font is bundled rather than a machine-dependent fallback")
	check(numbers.HELL_RED == preload("res://scripts/poster_surface.gd").RED, "critical uses our existing hell red")
	numbers.advance(0.08)
	var later: Array[Dictionary] = [{"kind":"hit", "pos":point, "enemy_id":811, "value":36}]
	app.battle.accept_events(later)
	check(numbers.active.size() == 4, "separate attacks outside the merge interval get a separate pop")
	for index in 140:
		var dense: Array[Dictionary] = [{"kind":"hit", "pos":point, "enemy_id":1000 + index, "value":index + 1}]
		numbers.accept(app.battle, dense)
	check(numbers.active.size() <= numbers.LIMIT and numbers.dropped > 0, "late-game damage numbers have a hard population budget")
	check(numbers.active.any(func(n): return bool(n.critical)), "budget pressure preserves critical numbers before ordinary hits")
	numbers.advance(1.0)
	check(numbers.active.is_empty(), "all numeric feedback expires without accumulating")
	app.battle.reset_transients()
	check(numbers.sequence == 0 and app.battle.projectile_trails.is_empty(), "stage reset removes feedback from the previous battle")
	if DisplayServer.get_name() != "headless" and "--capture-feedback" in OS.get_cmdline_user_args():
		await capture()
	DirAccess.make_dir_recursive_absolute(output_directory)
	var report := FileAccess.open(output_directory + "/feedback-validation.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks, "failures":failures, "graphical":DisplayServer.get_name() != "headless"}, "\t"))
	print("COMBAT FEEDBACK QA: %d assertions / %d failures" % [checks, failures.size()])
	app.queue_free()
	await process_frame
	app = null
	sim = null
	numbers = null
	await process_frame
	quit(0 if failures.is_empty() else 1)

func capture() -> void:
	var sim = app.sim
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	sim.projectiles.clear()
	sim.enemy_projectiles.clear()
	sim.workshop_mode = true
	sim.workshop_invulnerable = false
	sim.wave_timer = 999.0
	sim.pending_stage_spawns.clear()
	for index in sim.heroes.size():
		var hero: Dictionary = sim.heroes[index]
		hero.deployed = true
		hero.pos = [Vector2(505, 380), Vector2(440, 275), Vector2(445, 480)][index]
		hero.target = hero.pos
		hero.hp = 10000.0
		hero.max_hp = 10000.0
		hero.crit_chance = 0.40
		hero.attack_timer = float(index) * 0.15
	for index in 24:
		var kind := "ranged" if index % 3 == 0 else ("buffer" if index % 3 == 1 else "grunt")
		var enemy: Dictionary = sim.spawn_enemy(Vector2(630 + (index % 6) * 92, 200 + (index / 6) * 88), kind)
		enemy.hp = 12000.0
		enemy.max_hp = 12000.0
		enemy.speed = 5.0
		enemy.rate = 1.3
		enemy.attack_range = 480.0 if kind != "grunt" else 75.0
		enemy.attack_timer = float(index % 5) * 0.18
	sim.drain_events()
	app.battle.effects.clear()
	app.battle.damage_numbers.clear()
	DirAccess.make_dir_recursive_absolute(output_directory + "/frames")
	var maximum_projectiles := 0
	var kinds := {}
	for index in 240:
		var dt := 1.0 / 24.0
		sim.tick(dt)
		var events: Array[Dictionary] = sim.drain_events()
		for event in events: kinds[str(event.kind)] = int(kinds.get(str(event.kind), 0)) + 1
		app.battle.accept_events(events)
		app.fx.accept(events)
		app.battle.advance(dt)
		app.fx.advance(dt)
		app.refresh()
		maximum_projectiles = maxi(maximum_projectiles, sim.projectiles.size() + sim.enemy_projectiles.size())
		if index == 75:
			# Gameplay skill input, not a fabricated visual overlay.
			sim.heroes[0].skill_cooldown = 0.0
			sim.heroes[0].energy = 100.0
			sim.activate_hero_skill(int(sim.heroes[0].id), Vector2(780, 330))
		await RenderingServer.frame_post_draw
		var picture: Image = root.get_texture().get_image()
		picture.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
		picture.save_png(output_directory + "/frames/frame-%04d.png" % index)
		if index in [65, 115, 175]: picture.save_png(output_directory + "/battle-%03d.png" % index)
	check(maximum_projectiles > 5 and kinds.get("enemy_projectile_cast", 0) > 5, "demo runs real mixed sword/orb/hero combat")
	check(kinds.get("hit", 0) > 10 and kinds.get("hurt", 0) > 0, "demo numbers reflect real inflicted and received damage")
	var evidence := FileAccess.open(output_directory + "/capture-metrics.json", FileAccess.WRITE)
	evidence.store_string(JSON.stringify({"frames":240,"fps":24,"maximum_projectiles":maximum_projectiles,"events":kinds}, "\t"))
