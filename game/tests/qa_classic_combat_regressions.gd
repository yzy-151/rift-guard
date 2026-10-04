extends SceneTree
const Sim = preload("res://scripts/combat_simulation.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func setup(stage: String = "stage_02") -> RefCounted:
	var sim: RefCounted = Sim.new(827, true)
	var squad: Array[String] = ["traveler"]
	sim.reset_stage(stage, squad, 827)
	sim.start()
	sim.state = "running"
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	sim.terrain_features.clear()
	sim.events.clear()
	var hero: Dictionary = sim.heroes[0]
	hero.deployed = true
	hero.pos = Vector2(650, 360)
	hero.target = hero.pos
	hero.armor = 0.0
	hero.hp = 10000.0
	hero.max_hp = 10000.0
	hero.invulnerable_timer = 0.0
	return sim

func shooter(sim: RefCounted, kind: String = "ranged") -> Dictionary:
	var enemy: Dictionary = sim.spawn_enemy(Vector2(850, 360), kind)
	enemy.pos = Vector2(850, 360)
	enemy.affixes = []
	enemy.speed = 0.0
	enemy.damage = 40.0
	return enemy

func _initialize() -> void:
	test_physical_ranged()
	test_construct_projectile_impact()
	test_committed_aim()
	test_homing_identity()
	test_frozen_windups()
	test_delayed_release_freeze()
	test_late_endless_mix()
	test_flat_campaign_geometry()
	test_v86_endless_attack_geometry()
	test_endless_objectives()
	test_story_contract_unchanged()
	test_bat_group_quota()
	test_projectile_affixes_and_wall()
	test_owned_hazard_freeze()
	test_freeze_preserves_aura_expiry()
	print("CLASSIC REGRESSIONS: checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_physical_ranged() -> void:
	for kind in ["ranged", "buffer"]:
		var sim: RefCounted = setup()
		var enemy: Dictionary = shooter(sim, kind)
		var hero: Dictionary = sim.heroes[0]
		var health: float = hero.hp
		sim._begin_enemy_warning(enemy, hero)
		sim._resolve_enemy_warning(enemy)
		check(hero.hp == health, kind + " release does not cause pre-flight damage")
		check(sim.enemy_projectiles.size() == 1, kind + " attack creates one physical projectile")
		if sim.enemy_projectiles.is_empty():
			continue
		var projectile: Dictionary = sim.enemy_projectiles[0]
		check(projectile.get("source_id", -1) == enemy.id, kind + " projectile records source identity")
		sim._enemy_projectile_tick(0.1)
		check(hero.hp == health, kind + " distant projectile spends real time in flight")
		# One large step crosses the body and must still hit exactly once.
		sim._enemy_projectile_tick(0.6)
		check(is_equal_approx(hero.hp, health - enemy.damage), kind + " swept collision hits exactly once")
		check(sim.enemy_projectiles.is_empty(), kind + " projectile is consumed on hit")

func test_committed_aim() -> void:
	var sim: RefCounted = setup()
	var enemy: Dictionary = shooter(sim)
	var hero: Dictionary = sim.heroes[0]
	var health: float = hero.hp
	sim._begin_enemy_warning(enemy, hero)
	var locked: Vector2 = enemy.warning_pos
	hero.pos += Vector2(0, 130)
	sim._resolve_enemy_warning(enemy)
	check(sim.enemy_projectiles.size() == 1, "archer fires committed aim even when target left warning")
	if not sim.enemy_projectiles.is_empty():
		check(sim.enemy_projectiles[0].get("target_pos", Vector2.ZERO) == locked, "arrow keeps original warned position")
	for i in range(50):
		sim._enemy_projectile_tick(0.1)
	check(hero.hp == health, "sideways dodge avoids physical arrow")
	check(sim.dodges == 1, "missed physical attack credits one dodge")

func test_homing_identity() -> void:
	var sim: RefCounted = setup()
	var enemy: Dictionary = shooter(sim, "troop_ranged")
	var hero: Dictionary = sim.heroes[0]
	sim._begin_enemy_warning(enemy, hero)
	sim._resolve_enemy_warning(enemy)
	check(sim.enemy_projectiles.size() == 1, "original ranged troop keeps magic projectile")
	if sim.enemy_projectiles.is_empty():
		return
	hero.pos += Vector2(0, 90)
	var projectile: Dictionary = sim.enemy_projectiles[0]
	var before_y: float = projectile.pos.y
	sim._enemy_projectile_tick(0.1)
	check(projectile.pos.y > before_y, "ranged troop orb retains homing behavior")

func test_frozen_windups() -> void:
	for kind in ["grunt", "ranged", "buffer", "boss_01"]:
		var sim: RefCounted = setup()
		var enemy: Dictionary = shooter(sim, kind)
		var hero: Dictionary = sim.heroes[0]
		sim._begin_enemy_warning(enemy, hero)
		if kind == "boss_01":
			sim._start_rift_warning(enemy, "rift_laser")
			enemy.special_pending = true
		var remaining: float = enemy.warning_timer
		var special: float = enemy.get("special_warning", 0.0)
		enemy.frozen_timer = 3.0
		var health: float = hero.hp
		for i in range(20):
			sim._enemy_tick(0.1)
		check(is_equal_approx(enemy.warning_timer, remaining), kind + " frozen normal windup remains paused")
		check(enemy.attack_pending, kind + " frozen warning remains present")
		check(hero.hp == health and sim.enemy_projectiles.is_empty(), kind + " cannot attack while frozen")
		if kind == "boss_01":
			check(is_equal_approx(enemy.special_warning, special), "frozen boss special warning remains aligned")
		enemy.frozen_timer = 0.0
		sim._enemy_tick(0.1)
		check(enemy.warning_timer < remaining, kind + " windup resumes on thaw")

func test_delayed_release_freeze() -> void:
	var sim: RefCounted = setup()
	var enemy: Dictionary = shooter(sim, "boss_01")
	enemy.special_move = "rift_orbs"
	enemy.special_warning_positions = [sim.heroes[0].pos]
	sim._execute_rift_special(enemy, "rift_orbs")
	check(sim.enemy_projectiles.size() > 1, "boss queues staggered orb volley")
	var delayed: Dictionary = {}
	var released: Dictionary = {}
	for projectile in sim.enemy_projectiles:
		if projectile.get("delay", 0.0) > 0.0 and delayed.is_empty():
			delayed = projectile
		elif projectile.get("delay", 0.0) <= 0.0 and released.is_empty():
			released = projectile
	check(not delayed.is_empty() and not released.is_empty(), "volley contains both released and unreleased shots")
	if delayed.is_empty() or released.is_empty():
		return
	var delay_before: float = delayed.delay
	var life_before: float = delayed.life
	var moving_before: Vector2 = released.pos
	enemy.frozen_timer = 2.0
	sim._enemy_projectile_tick(0.1)
	check(is_equal_approx(delayed.delay, delay_before) and is_equal_approx(delayed.life, life_before), "freeze pauses owned unreleased shot delay and lifetime")
	check(released.pos != moving_before, "already airborne boss orb continues while caster frozen")

func test_late_endless_mix() -> void:
	var sim: RefCounted = setup("stage_endless")
	for phase in [3, 4, 8]:
		var pool: Array[String] = sim._endless_enemy_pool(phase)
		for required in ["originium_bug", "rift_bat", "flyer", "splitter", "shielded", "hilichurl_brute"]:
			check(required in pool, "late phase %d retains %s" % [phase, required])
	sim.endless_boss_index = 5
	sim.endless_next_boss_at = 99999.0
	sim.elapsed = 600.0
	sim.endless_spawn_timer = 999.0
	sim.troop_convoy_timer = 0.0
	sim._endless_spawn_tick(0.1)
	for kind in ["troop_cannon", "troop_melee", "troop_ranged"]:
		check(sim.enemies.any(func(e: Dictionary) -> bool: return e.kind == kind), "late endless still fields original " + kind)


func test_flat_campaign_geometry() -> void:
	var sim: RefCounted = setup()
	var hero: Dictionary = sim.heroes[0]
	hero.range = 200.0
	check(sim.attack_range_screen_radii(hero).is_equal_approx(Vector2(200, 200)), "campaign attack preview uses authoritative circular range")
	check(sim.ability_area_screen_radii(hero.pos, 180).is_equal_approx(Vector2(180, 180)), "campaign ability preview uses authoritative circular radius")
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1).normalized()]:
		check(sim.is_in_attack_range(hero, hero.pos + direction * 199), "campaign attack includes each inner circle edge")
		check(not sim.is_in_attack_range(hero, hero.pos + direction * 201), "campaign attack excludes each outer circle edge")
		check(sim.is_in_ability_area(hero.pos, hero.pos + direction * 179, 180), "campaign ability includes each inner circle edge")
		check(not sim.is_in_ability_area(hero.pos, hero.pos + direction * 181, 180), "campaign ability excludes each outer circle edge")
		check(sim.support_barrage_contains(hero.pos, hero.pos + direction * 179, 180), "campaign support barrage matches circle preview")
	var enemy: Dictionary = sim.spawn_enemy(hero.pos + Vector2(0, -190), "grunt")
	enemy.pos = hero.pos + Vector2(0, -190)
	hero.attack_timer = 0.0
	var shots: int = sim.shots_fired
	sim._hero_tick()
	check(sim.shots_fired == shots + 1, "real campaign targeting agrees with vertical circle boundary")
	sim = setup("stage_endless")
	hero = sim.heroes[0]
	hero.range = 200.0
	check(sim.attack_range_screen_radii(hero).is_equal_approx(Vector2(144.3, 57.72)), "endless original attack ellipse stays intact")
	check(sim.ability_area_screen_radii(hero.pos, 180).is_equal_approx(Vector2(153.6, 61.44)), "endless original ability ellipse stays intact")
	check(sim.is_in_ability_area(hero.pos, hero.pos + Vector2(0, 68), 180), "endless original eight-pixel ground anchor stays intact")
	check(not sim.is_in_ability_area(hero.pos, hero.pos + Vector2(0, -68), 180), "endless asymmetric old ground anchor remains unchanged")

func test_endless_objectives() -> void:
	var sim: RefCounted = setup("stage_endless")
	check(sim.combat_contract.metric == "survival_time" and sim.combat_contract.target == 120, "endless first objective preserves original 120-second contract")
	var luck: float = sim.run_state.luck
	sim.elapsed = 120.0
	sim._contract_tick()
	check(sim.contract_completed and is_equal_approx(sim.run_state.luck, luck + 0.06), "first endless objective keeps original luck reward")
	sim._contract_tick()
	check(is_equal_approx(sim.run_state.luck, luck + 0.06), "completed objective rewards exactly once")
	sim.kills = 77
	sim.elapsed = 124.0
	sim._contract_tick()
	check(not sim.contract_completed and sim.combat_contract.metric == "kills", "endless continues to optional kill objective after completed banner")
	if sim.contract_completed:
		return
	check(sim.contract_progress() == 0, "new objective excludes kills earned before it started")
	var index: int = sim.combat_contract.get("objective_index", 0)
	sim.kills += 7
	var snapshot: Dictionary = sim.export_run_snapshot()
	var restored: RefCounted = setup("stage_endless")
	check(restored.import_run_snapshot(snapshot), "endless objective snapshot imports alongside original build")
	check(restored.contract_progress() == 7 and restored.combat_contract.get("objective_index", 0) == index, "objective progress survives reload with counters rebased")
	for i in range(9):
		var metric: String = sim.combat_contract.metric
		var remaining: int = sim.combat_contract.target - sim.contract_progress()
		if metric == "kills": sim.kills += remaining
		elif metric == "survival_time": sim.elapsed += remaining
		elif metric == "reactions": sim.reactions += remaining
		elif metric == "boss_kills": sim.boss_kills += remaining
		elif metric == "elite_kills": sim.elite_kills += remaining
		elif metric == "zone_hold":
			sim.heroes[0].pos = sim.combat_contract.zone_pos
			for tick in ceili(float(remaining) / 0.2) + 2:
				sim.elapsed += 0.2
				sim._contract_tick()
		else: check(false, "supported optional objective metric")
		sim.heroes[0].energy = 99.0
		sim._contract_tick()
		check(sim.contract_completed, "rotating objective completes through its real metric")
		check(sim.heroes[0].energy <= sim.heroes[0].max_energy and sim.run_state.luck <= luck + 0.06001, "repeatable objective rewards remain bounded and add no permanent luck")
		sim.elapsed += 4.0
		sim._contract_tick()
		check(sim.contract_progress() == 0 and not sim.contract_completed, "each objective starts from fresh counters")
	check(sim.combat_contract.get("objective_index", 0) >= 10, "optional objective chain continues without finite exhaustion")
	var restart_squad: Array[String] = ["traveler"]
	sim.reset_stage("stage_endless", restart_squad, 29)
	check(sim.combat_contract.target == 120 and sim.contract_progress() == 0, "new endless run resets objective chain")

func test_story_contract_unchanged() -> void:
	var sim: RefCounted = setup("stage_01")
	var definition: Dictionary = sim.combat_contract.duplicate(true)
	sim.kills = sim.combat_contract.target
	var luck: float = sim.run_state.luck
	sim._contract_tick()
	check(sim.contract_completed and is_equal_approx(sim.run_state.luck, luck + 0.04), "story kill contract retains configured reward")
	sim.elapsed = 1000.0
	sim._contract_tick()
	check(sim.combat_contract == definition and sim.contract_completed, "story contract never rotates into endless tasks")


func test_bat_group_quota() -> void:
	var sim: RefCounted = setup("stage_endless")
	sim.elapsed = 600.0
	sim.endless_boss_index = 4
	sim.endless_next_boss_at = 99999.0
	sim.troop_convoy_timer = 99999.0
	for i in range(11):
		sim.spawn_enemy(Vector2(150 + i * 30, 150), "rift_bat")
	# Select a phase-pool index that requests a bat when next_id is incremented.
	var pool: Array[String] = sim._endless_enemy_pool(4)
	var bat_index: int = pool.find("rift_bat")
	while (sim.next_id + sim._endless_tier()) % pool.size() != bat_index:
		sim.next_id += 1
	sim.endless_spawn_timer = 0.0
	sim._endless_spawn_tick(0.1)
	check(sim._endless_kind_count(["rift_bat"]) <= 12, "bat triplet respects remaining species quota")

func test_projectile_affixes_and_wall() -> void:
	var sim: RefCounted = setup()
	var enemy: Dictionary = shooter(sim)
	enemy.hp = 20.0
	enemy.affixes = ["vampiric", "suppressor"]
	var hero: Dictionary = sim.heroes[0]
	hero.skill_cooldown = 0.0
	sim._begin_enemy_warning(enemy, hero)
	sim._resolve_enemy_warning(enemy)
	check(enemy.hp == 20.0 and hero.skill_cooldown == 0.0, "ranged affixes do not trigger before physical impact")
	sim._enemy_projectile_tick(0.6)
	check(enemy.hp == 30.0 and hero.skill_cooldown == 2.0, "ranged vampiric and suppressor effects trigger on impact")
	sim = setup()
	enemy = shooter(sim)
	hero = sim.heroes[0]
	sim._begin_enemy_warning(enemy, hero)
	sim._resolve_enemy_warning(enemy)
	sim.terrain_features.append({"type":"blocked", "area":Rect2(740, 300, 35, 130), "hp":100.0})
	var health: float = hero.hp
	sim._enemy_projectile_tick(0.6)
	check(hero.hp == health and sim.enemy_projectiles.is_empty(), "physical arrow is blocked by terrain before reaching hero")

func test_owned_hazard_freeze() -> void:
	var sim: RefCounted = setup()
	var boss: Dictionary = shooter(sim, "boss_02")
	boss.frozen_timer = 2.0
	var hazard: Dictionary = {"source_id":boss.id, "kind":"slime_court_final", "pos":sim.heroes[0].pos, "delay":1.0, "life":0.5, "radius":100.0, "damage":20.0}
	sim._queue_enemy_hazard(hazard)
	sim._enemy_hazard_tick(0.5)
	check(hazard.delay == 1.0, "owned unreleased impact pauses while boss frozen")
	boss.hp = 0.0
	sim._enemy_hazard_tick(0.1)
	check(sim.enemy_hazards.is_empty(), "dead caster cancels its unreleased delayed impact")


func test_freeze_preserves_aura_expiry() -> void:
	var sim: RefCounted = setup()
	var enemy: Dictionary = shooter(sim, "grunt")
	enemy.aura = "pyro"
	enemy.aura_timer = 0.1
	enemy.frozen_timer = 2.0
	sim._enemy_tick(0.2)
	check(enemy.aura == "", "freeze pauses actions while temporary elemental aura still expires")
func test_construct_projectile_impact() -> void:
	for kind in ["ranged", "buffer"]:
		var sim: RefCounted = setup()
		var enemy: Dictionary = shooter(sim, kind)
		sim.heroes[0].pos = Vector2(500, 200)
		var rock: Dictionary = {"id":91, "pos":Vector2(650, 360), "hp":100.0, "max_hp":100.0}
		sim.geo_constructs.append(rock)
		sim._begin_enemy_warning(enemy, {}, rock)
		sim._resolve_enemy_warning(enemy)
		check(rock.hp == 100.0, kind + " construct damage waits for projectile contact")
		check(sim.enemy_projectiles.size() == 1, kind + " construct attack emits a real projectile")
		sim._enemy_projectile_tick(0.1)
		check(rock.hp == 100.0, kind + " projectile travels before hitting construct")
		sim._enemy_projectile_tick(0.6)
		check(rock.hp == 60.0 and sim.enemy_projectiles.is_empty(), kind + " construct collision consumes one shot")
	var sim: RefCounted = setup()
	var enemy: Dictionary = shooter(sim)
	var hero: Dictionary = sim.heroes[0]
	var rock: Dictionary = {"id":92, "pos":Vector2(750, 360), "hp":100.0, "max_hp":100.0}
	sim.geo_constructs.append(rock)
	sim._begin_enemy_warning(enemy, hero)
	sim._resolve_enemy_warning(enemy)
	sim._enemy_projectile_tick(0.6)
	check(rock.hp == 60.0 and hero.hp == 10000.0, "geo construct intercepts projectile before hero behind it")
# Frozen V86 baseline, independent of the current map projection implementation.
func v86_project(point: Vector2) -> Vector2:
	var t: float = (point.y - 140.0) / 440.0
	return Vector2(640.0 + (point.x - 640.0) * (0.70 + 0.30 * t) * 1.03 + 10.0 * (1.0 - t), 92.0 + 482.0 * t)

func v86_unproject(point: Vector2) -> Vector2:
	var t: float = (point.y - 92.0) / 482.0
	var factor: float = maxf(0.1, 0.70 + 0.30 * t)
	return Vector2(640.0 + (point.x - 640.0 - 10.0 * (1.0 - t)) / (factor * 1.03), 140.0 + 440.0 * t)

func test_v86_endless_attack_geometry() -> void:
	var sim: RefCounted = setup("stage_endless")
	var hero: Dictionary = sim.heroes[0]
	hero.range = 200.0
	var enemy: Dictionary = sim.spawn_enemy(Vector2(800, 360), "grunt")
	for position in [Vector2(200, 140), Vector2(650, 360), Vector2(1500, 580), Vector2(2200, 1100)]:
		hero.pos = position
		hero.target = position
		var depth: float = 0.65 + 0.35 * (position.y - 140.0) / 440.0
		var radius: float = 42.0 + 200.0 * 0.62 * depth
		var radii := Vector2(radius, radius * 0.4)
		check(sim.attack_range_screen_radii(hero).is_equal_approx(radii), "endless preview preserves V86 depth at " + str(position))
		var center: Vector2 = v86_project(position) + Vector2(0, 8)
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized()]:
			for scale in [0.99, 1.01]:
				var candidate: Vector2 = v86_unproject(center + direction * radii * scale)
				var baseline_inside: bool = ((v86_project(candidate) - center) / radii).length_squared() <= 1.0
				check(sim.is_in_attack_range(hero, candidate) == baseline_inside, "endless cached collision agrees with V86 boundary " + str(position) + str(direction) + str(scale))
				enemy.pos = candidate
				hero.attack_timer = 0.0
				var before: int = sim.shots_fired
				sim._hero_tick()
				check((sim.shots_fired > before) == baseline_inside, "endless real targeting agrees with V86 boundary " + str(position) + str(direction) + str(scale))
