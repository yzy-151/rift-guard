extends SceneTree
const Sim = preload("res://scripts/combat_simulation.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func fixture():
	var s = Sim.new(303)
	s.start()
	s.spawn_remaining = 1
	s.spawn_timer = 999.0
	for h in s.heroes:
		h.attack_timer = 999.0
		h.heal_timer = 999.0
	return s

func _initialize() -> void:
	var s = fixture()
	check(s.heroes.size() == 3, "three independently initialized heroes")
	var original: Vector2 = s.heroes[0].target
	s.command_move(2, Vector2(1900, -30))
	check(s.heroes[2].target == Vector2(660, 215) and s.heroes[0].target == original, "indexed move clamps only selected hero")
	s.heroes[2].hp = 0.0
	s.command_move(2, Vector2(250, 400))
	check(s.heroes[2].target == Vector2(660, 215), "downed hero ignores movement")
	s = fixture()
	var e = s.spawn_enemy(Vector2(900, 295))
	s.heroes[1].attack_timer = 0.0
	s.tick(0.01)
	check(s.shots_fired == 0, "range excludes distant targets")
	e.pos = Vector2(550, 295)
	s.tick(0.01)
	check(s.heroes[1].shots == 1, "fire hero shoots independently")
	s.tick(0.1)
	check(s.heroes[1].shots == 1, "per-hero cooldown throttles fire")
	s.heroes[1].attack_timer = 0
	s.command_move(1, Vector2(520, 450))
	s.tick(0.1)
	check(s.heroes[1].shots == 1, "moving hero pauses shooting")
	s = fixture()
	for i in 3:
		e = s.spawn_enemy(Vector2(546 + i * 2, 360), "armored")
	s.tick(0.3)
	check(s.enemies.filter(func(x: Dictionary) -> bool: return x.blocked_by == 0).size() == 2, "guard blocks at most two enemies")
	check(s.heroes[0].blocked == 2, "block counter reports capacity")
	var blocked_x: float = s.enemies[0].pos.x
	s.tick(0.2)
	check(is_equal_approx(s.enemies[0].pos.x, blocked_x), "blocked enemy stops advancing")
	var health_before: float = s.heroes[0].hp
	s.enemies[0].attack_timer = 0.0
	s.tick(0.01)
	check(s.heroes[0].hp < health_before, "blocked enemy damages guard through defense")
	s.command_move(0, Vector2(400, 470))
	s.tick(0.1)
	check(s.enemies.all(func(x: Dictionary) -> bool: return x.blocked_by == -1), "moving guard releases all blocks")
	s = fixture()
	e = s.spawn_enemy(Vector2(545, 360))
	s.tick(0.01)
	s.damage_hero(0, 10000)
	check(s.heroes[0].hp == 0 and e.blocked_by == -1, "downing a guard releases blockers immediately")
	s = fixture()
	s.heroes[0].hp = 0.0
	s.heroes[1].hp = 50.0
	s.heroes[2].heal_timer = 0.0
	s.tick(0.01)
	check(s.heroes[1].hp == 72.0 and s.heroes[0].hp == 0, "water heals living ally and never revives in combat")
	s = fixture()
	s.heroes[0].hp = 1.0
	s.heroes[0].pos = Vector2(800, 100)
	s.heroes[0].target = s.heroes[0].pos
	s.heroes[2].heal_timer = 0.0
	s.tick(0.01)
	check(s.heroes[0].hp == 1.0, "healing respects range")
	s = fixture()
	e = s.spawn_enemy(Vector2(900, 360), "armored")
	var actual: float = s.apply_hit(e, 100.0, "")
	check(is_equal_approx(actual, 10000.0 / 185.0), "armor follows documented reduction")
	s.apply_hit(e, 1.0, "water")
	actual = s.apply_hit(e, 40.0, "fire")
	check(is_equal_approx(actual, 6000.0 / 185.0) and s.reactions == 1, "water then fire causes 1.5x vaporize")
	check(e.aura == "" and e.aura_timer == 0.0, "reaction consumes aura")
	s.apply_hit(e, 1.0, "water")
	s.apply_hit(e, 1.0, "fire")
	check(s.reactions == 1, "reaction cooldown prevents immediate retrigger")
	s.tick(0.6)
	s.apply_hit(e, 1.0, "fire")
	check(s.reactions == 2, "reaction becomes available after cooldown")
	s = fixture()
	e = s.spawn_enemy(Vector2(900, 360))
	s.apply_hit(e, 1.0, "fire")
	actual = s.apply_hit(e, 10.0, "water")
	check(is_equal_approx(actual, 15.0), "fire then water also vaporizes")
	s = fixture()
	e = s.spawn_enemy(Vector2(1000, 360))
	s.apply_hit(e, 1.0, "fire")
	s.tick(3.01)
	check(e.aura == "", "element aura expires after three seconds")
	s = fixture()
	e = s.spawn_enemy(Vector2(700, 360))
	s.apply_hit(e, 1.0, "water")
	s.toggle_pause()
	var location: Vector2 = e.pos
	var aura_time: float = e.aura_timer
	s.tick(5.0)
	check(e.pos == location and e.aura_timer == aura_time, "pause freezes enemy and aura timers")
	s = fixture()
	e = s.spawn_enemy(Vector2(600, 295))
	s.heroes[1].attack_timer = 0
	s.tick(0.01)
	s.damage_hero(1, 10000)
	for i in 60:
		s.tick(1.0 / 60.0)
	check(e.hp < e.max_hp, "in-flight projectile retains damage after source is downed")
	s = fixture()
	e = s.spawn_enemy(Vector2(119, 450), "runner")
	s.tick(0.01)
	check(s.base_hp == 94 and s.enemies.is_empty(), "runner leaks exactly once with own leak value")
	s.base_hp = 15
	s.spawn_enemy(Vector2(119, 450), "armored")
	s.tick(0.01)
	check(s.base_hp == 0 and s.state == "lost", "armored leak triggers defeat at zero")
	s = fixture()
	s.heroes[0].hp = 0
	s.spawn_remaining = 0
	s.tick(0.01)
	check(s.state == "reward" and s.heroes[0].hp == s.heroes[0].max_hp * 0.5, "wave end revives downed ally at half health")
	s.reset()
	check(s.state == "ready" and s.heroes.all(func(h: Dictionary) -> bool: return h.hp == h.max_hp) and s.reactions == 0 and s.projectiles.is_empty(), "restart clears every hero and elemental state")
	var good: Dictionary = run_layout(false)
	var bad: Dictionary = run_layout(true)
	print("LAYOUT COMPARISON: " + JSON.stringify({"coverage": good, "corner": bad}))
	check(good.state == "won", "covering formation completes five mixed nodes")
	check(good.base_hp >= bad.base_hp + 20, "same waves: covering formation saves at least 20 base HP")
	for i in 2:
		var repeat: Dictionary = run_layout(false)
		check(repeat == good, "fixed encounters repeat exact outcome " + str(i + 1))
	print("ALL %d M4 COMBAT TESTS PASSED" % checks if failures == 0 else "%d TESTS FAILED" % failures)
	quit(0 if failures == 0 else 1)

func run_layout(bad: bool) -> Dictionary:
	var s = Sim.new(303)
	if bad:
		for h in s.heroes:
			h.pos = Vector2(185, 230)
			h.target = h.pos
	s.start()
	for frame in 30000:
		if s.state == "reward":
			s.choose_reward(0)
		s.tick(1.0 / 60.0)
		s.drain_events()
		if s.state in ["won", "lost"]:
			break
	return {"state": s.state, "base_hp": s.base_hp, "kills": s.kills, "reactions": s.reactions}
