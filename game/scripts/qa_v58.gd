extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V58 PASS: " + message)
	else:
		failures += 1
		push_error("V58 FAIL: " + message)

func run(game) -> void:
	var squad: Array[String] = ["traveler", "hero_03", "hero_06"]
	game.sim.reset_stage("stage_endless", squad, 5801)
	game.sim.start()
	for hero: Dictionary in game.sim.heroes:
		hero.deployed = true
		hero.hp = hero.max_hp

	var styles: Array[String] = []
	for hero: Dictionary in game.sim.heroes:
		styles.append(str(hero.get("attack_style", "standard")))
	expect(styles.size() == 3 and styles[0] != styles[1] and styles[1] != styles[2], "selected heroes have distinct normal-attack identities: %s" % str(styles))
	expect(bool(game.sim.heroes[1].get("splash", false)) and int(game.sim.heroes[2].get("pierce", 0)) >= 2, "Furina uses splash/echo while Amiya uses piercing critical attacks")

	var independent_target := Vector2(game.sim.heroes[1].pos) + Vector2(180.0, 40.0)
	game.sim.command_move(1, independent_target, false)
	var resolved_independent := Vector2(game.sim.heroes[1].target)
	game.sim._update_follow_targets(0.1)
	expect(bool(game.sim.heroes[1].get("follow_independent", false)) and Vector2(game.sim.heroes[1].target).is_equal_approx(resolved_independent), "non-Traveler heroes keep independent movement targets")
	game.sim.command_move(0, Vector2(game.sim.heroes[0].pos) + Vector2(160.0, 0.0), false)
	game.sim._update_follow_targets(0.1)
	expect(not bool(game.sim.heroes[1].get("follow_independent", true)) and not Vector2(game.sim.heroes[1].target).is_equal_approx(resolved_independent), "moving Traveler re-enables delayed squad following")

	game.sim.heroes[0].hp = 0.0
	game.sim.heroes[1].hp = game.sim.heroes[1].max_hp
	game.sim.heroes[2].hp = game.sim.heroes[2].max_hp
	game.sim.tick(1.0 / 60.0)
	expect(game.sim.state == "running", "endless mode continues when Traveler falls but allies survive")
	for hero: Dictionary in game.sim.heroes:
		hero.hp = 0.0
	game.sim.tick(1.0 / 60.0)
	expect(game.sim.state == "lost", "endless mode ends only after the whole party is down")

	game.sim.reset_stage("stage_endless", squad, 5802)
	game.sim.start()
	for hero: Dictionary in game.sim.heroes:
		hero.hp = 1000000.0
		hero.max_hp = 1000000.0
	game.sim.set_active_view_rect(Rect2(game.sim.heroes[0].pos - Vector2(624.0, 245.0), Vector2(1248.0, 490.0)))
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	var offscreen: Dictionary = game.sim.spawn_enemy(game.sim.ENDLESS_ARENA.position + Vector2(50.0, 50.0), "armored")
	offscreen.lod_accumulator = 0.0
	var start_pos := Vector2(offscreen.pos)
	game.sim._enemy_tick(1.0 / 60.0)
	expect(Vector2(offscreen.pos).is_equal_approx(start_pos), "off-screen regular enemies sleep between 5 Hz coarse updates")
	for frame in 14:
		game.sim._enemy_tick(1.0 / 60.0)
	expect(not Vector2(offscreen.pos).is_equal_approx(start_pos), "sleeping enemies still advance through coarse simulation")
	expect(game.sim.find_enemy(int(offscreen.id)) == offscreen, "projectiles resolve targets through constant-time enemy lookup")

	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	for index in 120:
		var point: Vector2 = game.sim.ENDLESS_ARENA.position + Vector2(40.0 + float(index % 20) * 44.0, 40.0 + float(index / 20) * 56.0)
		var enemy: Dictionary = game.sim.spawn_enemy(point, "armored")
		enemy.lod_accumulator = fposmod(float(index) * 0.017, 0.20)
	var start_usec := Time.get_ticks_usec()
	for frame in 120:
		game.sim.elapsed += 1.0 / 60.0
		game.sim._enemy_tick(1.0 / 60.0)
	var elapsed_usec := Time.get_ticks_usec() - start_usec
	var average_ms := float(elapsed_usec) / 120000.0
	expect(average_ms < 12.0, "120 mostly off-screen enemies simulate in %.2f ms/frame" % average_ms)

	game.battle.camera_center = game.sim.heroes[0].pos
	game.battle.effects.clear()
	var far_corner: Vector2 = game.sim.ENDLESS_ARENA.end - Vector2(10.0, 10.0)
	var offscreen_events: Array[Dictionary] = [{"kind":"hit", "pos":far_corner, "value":99, "element":"pyro", "style":"tidal_orb"}]
	game.battle.accept_events(offscreen_events)
	expect(game.battle.effects.is_empty(), "off-screen combat events are discarded before effect allocation")
	expect(game.attack_sound.volume_db >= -7.0 and game.sound.volume_db >= -9.0, "attack and impact audio gain is raised")

	print("V58 QA COMPLETE: %d checks, %d failures; off-screen benchmark %.2f ms/frame" % [checks, failures, average_ms])
	game.get_tree().quit(failures)
