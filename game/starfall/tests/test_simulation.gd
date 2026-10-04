extends SceneTree

var failures: Array[String] = []
var assertions: int = 0
var Simulation: GDScript

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func fresh(mode: String = "campaign") -> RefCounted:
	var sim: RefCounted = Simulation.new()
	sim.start(mode, ["traveler", "hero_03", "hero_08"], 1234)
	sim.spawn_timer = 999.0
	return sim

func advance(sim: RefCounted, seconds: float, movement: Vector2 = Vector2.ZERO) -> void:
	for i in range(ceili(seconds * 60.0)):
		sim.step(1.0 / 60.0, movement, Vector2(1300, 600))

func _initialize() -> void:
	if not FileAccess.file_exists("res://starfall/simulation.gd"):
		printerr("FAIL: new battle simulation does not exist")
		quit(1)
		return
	Simulation = load("res://starfall/simulation.gd")
	test_foundation()
	test_projectile_travel()
	test_locked_enemy_projectile()
	test_skills_and_dodge()
	test_drafts_and_reset()
	test_deaths()
	test_boss_progression()
	test_enemy_variety()
	test_charge_damage_follows_body()
	test_frozen_windup_stays_aligned()
	test_switch_formation()
	test_all_hero_skills()
	test_saturated_drafts()
	test_lethal_core_beats_boss_heal()
	test_endless_bounds()
	if failures.is_empty():
		print("PASS: %d Starfall simulation assertions" % assertions)
	quit(0 if failures.is_empty() else 1)

func test_foundation() -> void:
	var sim: RefCounted = fresh()
	check(sim.heroes.size() == 3, "three preserved characters spawn")
	check(sim.phase == "battle", "run starts in battle")
	advance(sim, 2.0, Vector2.RIGHT)
	check(sim.heroes[0].pos.x > 960.0, "movement changes player position")
	advance(sim, 10.0, Vector2.RIGHT)
	check(sim.heroes[0].pos.x < 1780.0, "movement stays in arena")
	check(sim.heroes[1].pos.distance_to(sim.heroes[0].pos) < 200.0, "companions follow formation")
	var catalog: GDScript = load("res://starfall/catalog.gd")
	check(catalog.heroes().size() == 10, "all ten preserved character atlas IDs are available")
	check(catalog.upgrades().size() >= 15, "catalog includes fifteen meaningful upgrades")

func test_projectile_travel() -> void:
	var sim: RefCounted = fresh()
	for hero in sim.heroes:
		hero.attack_timer = 999.0
	sim.heroes[0].attack_timer = 0.0
	var enemy: Dictionary = sim.spawn_enemy("grunt", sim.heroes[0].pos + Vector2(300, 0))
	enemy.speed = 0.0
	enemy.attack_timer = 999.0
	var health: float = enemy.hp
	sim.step(0.01, Vector2.ZERO, enemy.pos)
	check(sim.projectiles.size() > 0, "automatic attack emits traveling projectile")
	check(enemy.hp == health, "distant projectile does not deal instant damage")
	advance(sim, 0.65)
	check(enemy.hp < health, "projectile deals damage after travel")

func test_locked_enemy_projectile() -> void:
	var sim: RefCounted = fresh()
	for hero in sim.heroes:
		hero.attack_timer = 999.0
	var enemy: Dictionary = sim.spawn_enemy("ranged", sim.heroes[0].pos + Vector2(340, 0))
	enemy.attack_timer = 0.0
	advance(sim, 0.85)
	var bullet: Dictionary = {}
	for p in sim.projectiles:
		if p.owner == "enemy":
			bullet = p
			break
	check(not bullet.is_empty(), "ranged windup emits hostile projectiles")
	if not bullet.is_empty():
		var velocity: Vector2 = bullet.vel
		advance(sim, 0.12, Vector2.UP)
		check(bullet.vel == velocity, "enemy bullet keeps committed direction when target moves")

func test_skills_and_dodge() -> void:
	var sim: RefCounted = fresh()
	check(sim.cast("q", Vector2(1100, 640)), "ready skill casts")
	check(not sim.cast("q", Vector2(1100, 640)), "cooldown blocks repeat skill")
	check(not sim.cast("e", Vector2(1100, 640)), "ultimate requires full energy")
	sim.heroes[0].energy = 100.0
	check(sim.cast("e", Vector2(1100, 640)), "charged ultimate casts")
	check(sim.heroes[0].energy == 0.0, "ultimate consumes energy")
	check(sim.dash(Vector2.RIGHT), "ready dash succeeds")
	check(not sim.dash(Vector2.RIGHT), "dash cooldown blocks repeat")
	var before: float = sim.heroes[0].hp
	sim.hurt_hero(sim.heroes[0], 50.0)
	check(sim.heroes[0].hp == before, "dash grants real invulnerability")
	advance(sim, 0.6)
	sim.hurt_hero(sim.heroes[0], 10.0)
	check(sim.heroes[0].hp < before, "invulnerability expires")
	advance(sim, 14.0)
	check(sim.cast("q", Vector2(1100, 640)), "skill becomes available after cooldown")

func test_drafts_and_reset() -> void:
	var sim: RefCounted = fresh()
	sim.grant_xp(sim.xp_needed)
	check(sim.phase == "upgrade", "level gain pauses battle for draft")
	check(sim.upgrade_choices.size() == 3, "draft offers three upgrades")
	check(not sim.choose_upgrade("not-an-upgrade"), "unknown upgrade rejected")
	check(sim.reroll(), "first draft reroll succeeds")
	check(not sim.reroll(), "second draft reroll rejected")
	var choice: Dictionary = sim.upgrade_choices[0]
	check(sim.choose_upgrade(choice.id), "offered upgrade can be chosen")
	check(sim.upgrades.get(choice.id, 0) == 1, "selected upgrade gains one stack")
	check(not sim.choose_upgrade(choice.id), "upgrade cannot be purchased outside draft")
	sim.upgrades["multishot"] = 3
	for i in range(15):
		sim.grant_xp(sim.xp_needed)
		for option in sim.upgrade_choices:
			check(option.id != "multishot", "capped upgrades are excluded from offers")
		check(sim.choose_upgrade(sim.upgrade_choices[0].id), "repeated drafts remain valid")
	sim.events.append({"type": "stale"})
	sim.spawn_enemy("boss_01", Vector2(1500, 500))
	sim.start("endless", ["hero_01", "hero_04", "hero_13"], 3)
	check(sim.enemies.is_empty() and sim.projectiles.is_empty() and sim.hazards.is_empty() and sim.pickups.is_empty(), "reset clears all combat transients")
	check(sim.level == 1 and sim.kills == 0 and sim.upgrades.is_empty() and sim.selected == 0, "reset clears progression and selection")
	check(sim.mode == "endless" and sim.heroes[0].character_id == "hero_01", "reset applies new mode and squad")
	for event in sim.drain_events():
		check(event.type != "stale", "reset discards prior events")
	check(sim.drain_events().is_empty(), "drain_events empties queue")

func test_deaths() -> void:
	var sim: RefCounted = fresh()
	sim.hurt_hero(sim.heroes[0], 99999.0)
	check(sim.selected != 0 and sim.phase == "battle", "fallen active hero automatically swaps to survivor")
	sim.hurt_hero(sim.heroes[1], 99999.0)
	sim.hurt_hero(sim.heroes[2], 99999.0)
	check(sim.phase == "lost", "all heroes dead ends run")
	sim = fresh()
	sim.core_hp = 0.0
	sim.step(0.01, Vector2.ZERO, Vector2.ZERO)
	check(sim.phase == "lost", "destroyed moonwell ends run")

func test_boss_progression() -> void:
	var sim: RefCounted = fresh()
	sim.wave = 2
	sim.wave_time = 29.99
	sim.step(0.02, Vector2.ZERO, Vector2.ZERO)
	check(sim.wave == 3, "time advances normal wave")
	var boss: Dictionary = {}
	for enemy in sim.enemies:
		if enemy.kind == "boss_01":
			boss = enemy
	check(not boss.is_empty(), "third wave spawns boss")
	sim.wave_time = 30.0
	sim.step(0.02, Vector2.ZERO, Vector2.ZERO)
	check(sim.wave == 3, "live boss prevents progression after timer")
	if not boss.is_empty():
		boss.hp = 0.0
	sim.step(0.02, Vector2.ZERO, Vector2.ZERO)
	check(sim.wave == 4, "defeated boss permits next act")
	sim.wave = 9
	sim.wave_time = 30.0
	sim.enemies.clear()
	sim.boss_spawned = true
	sim.step(0.02, Vector2.ZERO, Vector2.ZERO)
	check(sim.phase == "won", "campaign ends after ninth-wave boss and timer")
	sim = fresh("endless")
	sim.wave = 9
	sim.wave_time = 30.0
	sim.boss_spawned = true
	sim.step(0.02, Vector2.ZERO, Vector2.ZERO)
	check(sim.wave == 10 and sim.phase == "battle", "endless continues beyond campaign finale")

func test_enemy_variety() -> void:
	var sim: RefCounted = fresh()
	for hero in sim.heroes:
		hero.attack_timer = 9999.0
		hero.hp = 100000.0
		hero.max_hp = 100000.0
	sim.core_hp = 100000.0
	sim.max_core_hp = 100000.0
	var kinds: Array[String] = ["grunt", "runner", "ranged", "buffer", "armored", "splitter", "boss_01"]
	for i in range(kinds.size()):
		var enemy: Dictionary = sim.spawn_enemy(kinds[i], Vector2(1100 + i * 40, 720))
		enemy.attack_timer = 0.0
		if kinds[i] == "grunt":
			enemy.hp *= 0.5
	advance(sim, 4.0)
	var seen: Dictionary = {}
	for event in sim.drain_events():
		seen[event.type] = true
	check(seen.has("cast"), "enemy telegraphs emit cast events")
	check(seen.has("shot"), "ranged enemies emit shot events")
	check(seen.has("heal"), "buffer channel heals damaged enemies")
	check(sim.enemies.size() > kinds.size(), "splitter summons reinforcements")
	check(sim.heroes[0].hp < 100000.0 or sim.core_hp < 100000.0, "enemy attacks resolve real damage")

func test_endless_bounds() -> void:
	var sim: RefCounted = fresh("endless")
	sim.spawn_timer = 0.0
	for hero in sim.heroes:
		hero.hp = 10000000.0
		hero.max_hp = 10000000.0
	sim.core_hp = 10000000.0
	sim.max_core_hp = 10000000.0
	var max_enemies: int = 0
	var max_projectiles: int = 0
	var max_pickups: int = 0
	for i in range(18000):
		if sim.phase == "upgrade":
			var choice: String = sim.upgrade_choices[0].id
			var best_priority: int = 99
			var priorities: Array[String] = ["multishot", "haste", "power", "magnet", "pierce", "crit"]
			for option in sim.upgrade_choices:
				var priority: int = priorities.find(option.id)
				if priority >= 0 and priority < best_priority:
					choice = option.id
					best_priority = priority
			sim.choose_upgrade(choice)
		if i % 90 == 0:
			sim.select_hero((sim.selected + 1) % 3)
		var hero: Dictionary = sim.heroes[sim.selected]
		var target: Vector2 = sim.CORE
		var best: float = INF
		for enemy in sim.enemies:
			var score: float = enemy.pos.distance_to(hero.pos) * (0.4 if enemy.kind == "boss_01" else 1.0)
			if score < best:
				best = score
				target = enemy.pos
		var walk_to: Vector2 = sim.CORE + Vector2.RIGHT.rotated(sim.time * 0.18) * 220.0
		for pickup in sim.pickups:
			if pickup.pos.distance_to(hero.pos) < 230.0:
				walk_to = pickup.pos
				break
		sim.cast("q", target)
		sim.cast("e", target)
		sim.step(1.0 / 30.0, (walk_to - hero.pos).normalized(), target)
		if i % 30 == 0:
			sim.drain_events()
		max_enemies = maxi(max_enemies, sim.enemies.size())
		max_projectiles = maxi(max_projectiles, sim.projectiles.size())
		max_pickups = maxi(max_pickups, sim.pickups.size())
	check(sim.time > 550.0, "endless endurance test simulates ten minutes")
	check(sim.wave > 9, "endless endurance defeats actual bosses and continues beyond campaign")
	check(max_enemies <= 80, "enemy pool stays bounded")
	check(max_projectiles <= 160, "projectile pool stays bounded")
	check(max_pickups <= 120 and sim.hazards.size() <= 80, "pickup and hazard pools stay bounded")
	check(sim.kills > 20, "endless endurance exercises real combat")
	print("ENDURANCE: %.1fs wave=%d kills=%d peaks enemies=%d projectiles=%d pickups=%d" % [sim.time, sim.wave, sim.kills, max_enemies, max_projectiles, max_pickups])


func test_charge_damage_follows_body() -> void:
	var sim: RefCounted = fresh()
	for hero in sim.heroes:
		hero.attack_timer = 999.0
	sim.heroes[0].pos = Vector2(900, 850)
	sim.heroes[1].pos = Vector2(200, 200)
	sim.heroes[2].pos = Vector2(200, 260)
	# ID 5 targets a hero, rather than the moonwell (every fourth enemy ID).
	sim.spawn_enemy("grunt", Vector2(1600, 200)).attack_timer = 999.0
	var runner: Dictionary = sim.spawn_enemy("runner", Vector2(620, 850))
	runner.attack_timer = 0.0
	var health: float = sim.heroes[0].hp
	for i in range(43):
		sim.heroes[1].pos = Vector2(200, 200)
		sim.heroes[2].pos = Vector2(200, 260)
		sim.step(1.0 / 60.0, Vector2.ZERO, Vector2.ZERO)
	check(sim.heroes[0].hp == health, "runner warning expiry does not damage a distant lane target")
	advance(sim, 0.5)
	check(sim.heroes[0].hp < health, "runner moving body deals damage upon arrival")
	var hit_health: float = sim.heroes[0].hp
	advance(sim, 0.3)
	check(sim.heroes[0].hp == hit_health, "runner damages a victim only once per charge")

func test_switch_formation() -> void:
	var sim: RefCounted = fresh()
	sim.select_hero(1)
	advance(sim, 3.0)
	check(sim.heroes[0].pos.distance_to(sim.heroes[2].pos) > 90.0, "companions occupy separate formation slots after middle hero selected")

func test_all_hero_skills() -> void:
	var catalog: GDScript = load("res://starfall/catalog.gd")
	for entry in catalog.heroes():
		var sim: RefCounted = fresh()
		sim.start("campaign", [entry.id, "hero_03", "hero_08"], 4321)
		sim.spawn_timer = 999.0
		for hero in sim.heroes:
			hero.attack_timer = 999.0
		var enemy: Dictionary = sim.spawn_enemy("armored", sim.heroes[0].pos + Vector2(110, 0))
		enemy.hp = 10000.0
		enemy.max_hp = 10000.0
		enemy.speed = 0.0
		enemy.attack_timer = 999.0
		var health: float = enemy.hp
		check(sim.cast("q", enemy.pos), entry.id + " skill casts")
		advance(sim, 2.0)
		check(enemy.hp < health, entry.id + " skill resolves damage")
		sim.heroes[0].energy = 100.0
		health = enemy.hp
		check(sim.cast("e", enemy.pos), entry.id + " ultimate casts")
		advance(sim, 2.0)
		check(enemy.hp < health, entry.id + " ultimate resolves damage")

func test_saturated_drafts() -> void:
	var sim: RefCounted = fresh()
	var catalog: GDScript = load("res://starfall/catalog.gd")
	for entry in catalog.upgrades():
		if entry.max_stacks < 999999:
			sim.upgrades[entry.id] = entry.max_stacks
	sim.grant_xp(sim.xp_needed)
	check(sim.upgrade_choices.size() == 3, "saturated permanent upgrades retain three valid repeatable draft choices")


func test_lethal_core_beats_boss_heal() -> void:
	var sim: RefCounted = fresh()
	sim.core_hp = 1.0
	sim.wave = 9
	sim.wave_time = 30.0
	sim.boss_spawned = true
	var boss: Dictionary = sim.spawn_enemy("boss_01", Vector2(1500, 300))
	boss.hp = 0.0
	sim.projectiles.append({"pos": sim.CORE + Vector2(-60, 0), "prev_pos": sim.CORE + Vector2(-60, 0), "vel": Vector2(1000, 0), "life": 1.0, "radius": 7.0, "damage": 10.0, "owner": "enemy", "color": Color.RED, "style": "arrow", "from_id": boss.id, "pierce": 0, "hits": []})
	sim.step(0.1, Vector2.ZERO, Vector2.ZERO)
	check(sim.phase == "lost", "lethal moonwell hit cannot be undone by boss death healing in same frame")
	check(sim.core_hp == 0.0, "destroyed moonwell remains destroyed")


func test_frozen_windup_stays_aligned() -> void:
	for kind in ["grunt", "runner", "armored", "buffer"]:
		var sim: RefCounted = fresh()
		for hero in sim.heroes:
			hero.attack_timer = 999.0
		sim.heroes[0].pos = Vector2(900, 850)
		sim.heroes[1].hp = 0.0
		sim.heroes[2].hp = 0.0
		sim.spawn_enemy("grunt", Vector2(1600, 200)).attack_timer = 999.0
		var enemy: Dictionary = sim.spawn_enemy(kind, Vector2(620 if kind == "runner" else 950, 850))
		enemy.attack_timer = 0.0
		sim.step(1.0 / 60.0, Vector2.ZERO, Vector2.ZERO)
		var field: Dictionary = {}
		for candidate in sim.hazards:
			if candidate.source_id == enemy.id:
				field = candidate
		check(not field.is_empty(), kind + " creates linked attack warning")
		if field.is_empty():
			continue
		check(is_equal_approx(field.remaining, enemy.state_time), kind + " warning and windup begin with identical remaining time")
		enemy.freeze = 2.0
		var clock_before: float = enemy.state_time
		var warning_before: float = field.remaining
		var health_before: float = sim.heroes[0].hp
		advance(sim, 1.5)
		check(is_equal_approx(enemy.state_time, clock_before), kind + " frozen attack windup remains paused")
		check(is_equal_approx(field.remaining, warning_before), kind + " frozen warning countdown remains paused")
		check(field in sim.hazards, kind + " warning stays visible throughout freeze")
		check(sim.heroes[0].hp == health_before, kind + " frozen source cannot resolve attack damage")
		advance(sim, 0.6)
		check(enemy.state_time < clock_before, kind + " windup resumes after thaw")
		check(is_equal_approx(field.remaining, enemy.state_time), kind + " warning and attack remain aligned after thaw")
		advance(sim, 1.3)
		check(not field in sim.hazards, kind + " warning clears when resumed attack resolves")
		if kind != "buffer":
			check(sim.heroes[0].hp < health_before, kind + " attack deals damage only after resumed windup")
