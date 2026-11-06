extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const Checkpoint = preload("res://scripts/campaign_checkpoint.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const Pool = preload("res://scripts/rewards/card_pool.gd")

var checks := 0
var failures: Array[String] = []
var observations: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("BALLISTICS QA: " + label)

func _initialize() -> void:
	_test_randomness()
	_test_stage_guest()
	_test_enemy_ballistics()
	_test_hero_ballistics()
	_test_damage_feedback()
	_test_boss_arrow_numbers()
	_test_projectile_limits()
	_test_collision_load()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):
			var output_path := argument.trim_prefix("--qa-output=")
			DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
			var output := FileAccess.open(output_path, FileAccess.WRITE)
			if output != null:
				output.store_string(JSON.stringify({"checks":checks, "failures":failures, "observations":observations}, "\t"))
				output.close()
	print("BALLISTICS + REWARDS QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _offer_signature(pool, run) -> String:
	var ids: Array[String] = []
	for card: Dictionary in pool.draw_three(run): ids.append(str(card.id))
	return ",".join(ids)

func _test_randomness() -> void:
	var sim = Sim.new(9201, true)
	var replay = Sim.new(9201, true)
	check(sim.card_pool.rng.seed == sim.run_seed, "reward RNG uses the exact persisted run seed")
	check(_offer_signature(sim.card_pool, sim.run_state) == _offer_signature(replay.card_pool, replay.run_state), "explicit QA/checkpoint seed reproduces the draw")
	var seen := {}
	var seeds := {}
	for attempt in 8:
		sim.restart_current_stage()
		seeds[sim.run_seed] = true
		seen[_offer_signature(sim.card_pool, sim.run_state)] = true
		check(sim.card_pool.rng.seed == sim.run_seed, "retry %d card seed and persisted seed agree" % attempt)
	check(seeds.size() == 8, "fresh retries generate distinct run seeds")
	check(seen.size() >= 5, "new runs produce varied reward offers instead of a fixed stage sequence")
	observations.random_runs = {"seed_count":seeds.size(), "distinct_offers":seen.size(), "offers":seen.keys()}
	var before: Array = sim.card_pool.offered.duplicate(true)
	var rng_before: int = sim.card_pool.rng.state
	for read in 10:
		for card: Dictionary in sim.card_pool.offered: sim.card_pool.preview(card, sim)
	check(before == sim.card_pool.offered and rng_before == sim.card_pool.rng.state, "reading/reopening an existing offer does not reroll it")
	check(sim.reroll_rewards() == false, "non-reward state cannot spend rerolls or change the draw")
	sim.state = "reward"
	check(sim.reroll_rewards() and sim.card_pool.rerolls_left == 1, "explicit reroll still spends exactly one attempt")
	var checkpoint := Checkpoint.snapshot(replay, "battle")
	var restored = Sim.new(1, true)
	check(Checkpoint.restore(checkpoint, restored), "existing checkpoint structure restores successfully")
	var expected = Pool.new(replay.database.cards, replay.run_seed)
	check(_offer_signature(restored.card_pool, restored.run_state) == _offer_signature(expected, replay.run_state), "continuing a saved run retains its seed rather than generating new offers")
	var implicit_a = Pool.new(sim.database.cards)
	var implicit_b = Pool.new(sim.database.cards)
	check(implicit_a.rng.seed != implicit_b.rng.seed, "default card pools no longer hardcode seed zero")

func _test_stage_guest() -> void:
	var sim = Sim.new(42, true)
	check(sim.run_state.squad == ["traveler"], "first-stage guest does not enter permanent squad")
	check(sim.heroes.size() == 2, "traveler-only first stage has an additional Gwen on the field")
	var guest: Dictionary = sim.heroes[1]
	check(guest.character_id == "hero_13" and guest.deployed and guest.get("temporary_assist", false), "Gwen is deployed immediately as a temporary ally")
	check(sim.run_state.temporary_assists == ["hero_13"], "guest is available to in-battle character card eligibility")
	var guest_card := {"id":"qa_gwen", "target":"character", "character_id":"hero_13", "effect":"attack_multiplier"}
	check(sim.card_pool.eligible(guest_card, sim.run_state), "Gwen can receive appropriate cards without a permanent unlock")
	var snapshot := sim.export_run_snapshot()
	check(snapshot.squad == ["traveler"] and snapshot.heroes.size() == 1, "temporary ally is excluded from endless carry-over")
	sim.reset_stage("stage_01", ["traveler", "hero_03"], 43)
	check(sim.heroes.size() == 3 and sim.heroes[2].character_id == "hero_13" and sim.heroes[2].deployed, "story-unlocked Furina and guest Gwen coexist within the three-person HUD")
	var reinforcement := {"id":"qa_reinforcement", "effect":"deploy_reinforcement"}
	check(not sim.card_pool.eligible(reinforcement, sim.run_state), "a guest occupies a physical slot for reinforcement capacity")
	sim.reset_stage("stage_01", ["traveler", "hero_13", "hero_03"], 44)
	check(sim.heroes.size() == 3 and sim.run_state.temporary_assists.is_empty(), "an already selected Gwen is not duplicated")
	sim.reset_stage("stage_02", ["traveler"], 45)
	check(sim.heroes.size() == 1 and sim.run_state.temporary_assists.is_empty(), "next stage removes the guest until Gwen is actually recruited")

func _clean_sim():
	var sim = Sim.new(5105, true)
	sim.reset_stage("stage_endless", ["traveler", "hero_03"], 5105)
	sim.terrain_features.clear()
	sim.endless_blocker_bins.clear()
	sim.endless_blocker_index_ready = false
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	sim.drain_events()
	for hero: Dictionary in sim.heroes:
		hero.pos = Vector2(1800, 1000)
		hero.target = hero.pos
		hero.deployed = false
		hero.hp = 1000
		hero.max_hp = 1000
		hero.armor = 0
	return sim

func _dummy_enemy(sim, point: Vector2) -> Dictionary:
	var enemy: Dictionary = sim.spawn_enemy(point, "grunt")
	enemy.hp = 100000
	enemy.max_hp = enemy.hp
	enemy.armor = 0
	enemy.aura = ""
	return enemy

func _test_enemy_ballistics() -> void:
	for kind: String in ["ranged", "buffer", "troop_ranged"]:
		var sim = _clean_sim()
		var hero: Dictionary = sim.heroes[0]
		hero.deployed = true
		var caster: Dictionary = sim.spawn_enemy(Vector2(1600, 1000), kind)
		caster.damage = 25
		caster.affixes = ["vampiric"]
		caster.hp = 40
		caster.max_hp = 100
		sim._begin_enemy_warning(caster, hero)
		hero.pos.y += 100
		var hp: float = hero.hp
		sim._resolve_enemy_warning(caster)
		check(hero.hp == hp, "%s release does not deal instant endpoint damage" % kind)
		check(sim.enemy_projectiles.size() == 1, "%s releases even if the hero dodged the old warning point" % kind)
		var shot: Dictionary = sim.enemy_projectiles[0]
		check(shot.ballistic and shot.direction.is_equal_approx(Vector2.RIGHT), "%s freezes the advertised heading" % kind)
		check(shot.visual_kind == ("arrow" if kind == "ranged" else "orb"), "%s has the requested arrow/orb renderer contract" % kind)
		sim._enemy_projectile_tick(0.8)
		check(sim.enemy_projectiles.size() == 1 and shot.pos.x > 1800 and is_equal_approx(shot.pos.y, 988), "%s misses and flies beyond the former aim point without turning" % kind)
		check(hero.hp == hp, "%s miss causes no phantom damage" % kind)
		check(caster.hp == 40, "%s misses cannot grant vampiric healing just for releasing a shot" % kind)
		hero.hp = 0
		sim._enemy_projectile_tick(0.1)
		check(sim.enemy_projectiles.size() == 1, "%s continues after its original target dies" % kind)
		sim._enemy_projectile_tick(5.0)
		check(sim.enemy_projectiles.is_empty(), "%s misses are reclaimed by lifetime" % kind)
	var sim = _clean_sim()
	sim.heroes[0].deployed = true
	sim.heroes[0].pos = Vector2(1800, 1100)
	sim.heroes[1].deployed = true
	sim.heroes[1].pos = Vector2(1730, 1000)
	var projectile := {"kind":"enemy_arrow", "ballistic":true, "direction":Vector2.RIGHT, "pos":Vector2(1600, 988), "speed":650.0, "life":4.0, "damage":25.0, "hit_radius":5.0, "target_id":0, "source_enemy_id":99, "source_name":"丘丘弓箭手"}
	sim._queue_enemy_projectile(projectile)
	sim._enemy_projectile_tick(0.5)
	check(sim.heroes[1].hp == 975 and sim.heroes[0].hp == 1000, "a fast arrow hits the first actual hero on its path, not the original target")
	check(sim.enemy_projectiles.is_empty(), "non-piercing enemy shot is consumed on contact")
	check(sim.last_incoming_hit.source_name == "丘丘弓箭手", "ballistic damage retains its enemy source attribution")

func _hero_shot(pierce: int = 0) -> Dictionary:
	return {"visual_id":1, "ballistic":true, "direction":Vector2.RIGHT, "pos":Vector2(1600, 988), "speed":720.0, "life":4.5, "source_id":1, "target_id":-1, "damage":20.0, "element":"", "pierce":pierce, "hit_ids":[], "critical":false}

func _test_hero_ballistics() -> void:
	var sim = _clean_sim()
	var caster: Dictionary = sim.heroes[1]
	caster.deployed = true
	caster.pos = Vector2(1600, 1000)
	caster.range = 500
	caster.attack_timer = 0
	var target := _dummy_enemy(sim, Vector2(1700, 1000))
	sim._hero_tick()
	check(sim.projectiles.size() == 1 and sim.projectiles[0].direction.is_equal_approx(Vector2.RIGHT), "real Furina attack creates a frozen-direction spell bolt")
	target.pos.y += 100
	var hp: float = target.hp
	sim._projectile_tick(0.5)
	check(sim.projectiles.size() == 1 and target.hp == hp, "moving target can dodge an actual spell instead of being homed on")
	check(sim.projectiles[0].pos.x > 1700 and is_equal_approx(sim.projectiles[0].pos.y, 988), "hero spell travels past the former target position")
	target.hp = 0
	sim._projectile_tick(0.1)
	check(sim.projectiles.size() == 1, "hero bolt does not disappear when its selected enemy dies")
	sim._projectile_tick(5)
	check(sim.projectiles.is_empty(), "hero misses are reclaimed by lifetime")
	sim = _clean_sim()
	var first := _dummy_enemy(sim, Vector2(1700, 1000))
	var second := _dummy_enemy(sim, Vector2(1850, 1000))
	var off_axis := _dummy_enemy(sim, Vector2(1780, 1100))
	sim.projectiles.append(_hero_shot(1))
	sim._projectile_tick(0.6)
	check(first.hp == 99980 and second.hp == 99980 and off_axis.hp == 100000, "swept piercing hits two collinear enemies in one fast frame and misses off-axis enemy")
	check(sim.projectiles.is_empty(), "one pierce permits exactly two contacts")
	sim = _clean_sim()
	first = _dummy_enemy(sim, Vector2(1700, 1000))
	sim.projectiles.append(_hero_shot(2))
	sim._projectile_tick(0.2)
	sim._projectile_tick(0.1)
	check(first.hp == 99980 and sim.projectiles.size() == 1, "piercing bolt cannot repeatedly damage a previously hit target")
	check(sim.projectiles[0].direction == Vector2.RIGHT, "piercing retains heading instead of retargeting another enemy")
	sim = _clean_sim()
	first = _dummy_enemy(sim, Vector2(1680, 1000))
	second = _dummy_enemy(sim, Vector2(1820, 1000))
	sim.terrain_features.append({"type":"blocked", "area":Rect2(1740, 950, 30, 100)})
	sim.projectiles.append(_hero_shot(3))
	sim._projectile_tick(0.5)
	check(first.hp == 99980 and second.hp == 100000 and sim.projectiles.is_empty(), "sweep orders a contact before a wall correctly and prevents damage beyond the wall")

func _test_damage_feedback() -> void:
	var sim = _clean_sim()
	var first := _dummy_enemy(sim, Vector2(1700, 1000))
	var second := _dummy_enemy(sim, Vector2(1701, 1000))
	sim.drain_events()
	sim.apply_hit(first, 10, "", 1, true)
	sim.apply_hit(second, 11, "", 1, false)
	var events: Array[Dictionary] = sim._compact_cosmetic_events(sim.drain_events())
	var hits: Array[Dictionary] = []
	for event: Dictionary in events:
		if event.kind == "hit": hits.append(event)
	check(hits.size() == 2, "different nearby enemies do not merge into one floating damage number")
	check(hits[0].enemy_id != hits[1].enemy_id and hits[0].critical and not hits[1].critical, "damage number metadata preserves target identity and critical state")
	check(hits[0].value == 10 and hits[1].value == 11 and hits[0].hero_id == 1, "damage number values are the actual post-defense damage with hero attribution")

func _test_projectile_limits() -> void:
	var sim = _clean_sim()
	for index in 260:
		sim._queue_enemy_projectile({"kind":"enemy_orb", "ballistic":true, "direction":Vector2.RIGHT, "pos":Vector2(1600, 988), "speed":430.0, "life":4.0, "damage":25.0})
	check(sim.enemy_projectiles.size() == sim.MAX_ENDLESS_ENEMY_PROJECTILES, "late-game enemy projectile load remains bounded")
	sim._enemy_projectile_tick(0.2)
	check(sim.enemy_projectiles.size() == 200, "misses remain live and bounded during their travel")
	sim._enemy_projectile_tick(5)
	check(sim.enemy_projectiles.is_empty(), "a full missed-projectile pool is eventually reclaimed")
	for index in 100:
		_dummy_enemy(sim, Vector2(1600 + index * 25, 1000 + (index % 4) * 60))
	sim._projectile_candidates(Vector2(1600, 988), Vector2(1620, 988))
	var local: Array[Dictionary] = sim._projectile_candidates(Vector2(1600, 988), Vector2(1620, 988))
	check(local.size() < 15, "spatial bins query nearby targets rather than scanning the whole late-game wave per projectile")

func _test_boss_arrow_numbers() -> void:
	for kind: String in ["kindred_arrow", "kindred_dread_arrow", ""]:
		var sim = _clean_sim()
		var hero: Dictionary = sim.heroes[0]
		hero.deployed = true
		hero.armor = 25
		var hp_before := float(hero.hp)
		sim._queue_enemy_projectile({"kind":kind, "pos":Vector2(hero.pos), "target_id":0, "damage":25.0, "life":2.0, "speed":10.0, "source_name":"千珏", "source_skill":"追猎箭"})
		sim._enemy_projectile_tick(0.01)
		var numbers: Array[Dictionary] = []
		for event: Dictionary in sim.drain_events():
			if event.kind in ["hit", "hurt"]: numbers.append(event)
		check(numbers.size() == 1 and numbers[0].kind == "hurt", "%s hit creates one actual hurt number and no duplicate hit" % (kind if not kind.is_empty() else "legacy fallback"))
		check(hero.hp == hp_before - 20.0 and numbers[0].value == 20, "%s arrow shows post-defense 20 damage, never the raw 25" % kind)
		check(numbers[0].hero_id == 0 and numbers[0].source_name == "千珏", "%s sole arrow number retains victim and source attribution" % kind)

func _test_collision_load() -> void:
	var sim = _clean_sim()
	for hero: Dictionary in sim.heroes:
		hero.deployed = true
		hero.hp = 10000000
		hero.max_hp = hero.hp
	for index in 100:
		_dummy_enemy(sim, Vector2(1700 + index % 20 * 65, 860 + index / 20 * 65))
	var samples: Array[int] = []
	for frame in 120:
		while sim.projectiles.size() < 360:
			var shot := _hero_shot(2)
			shot.pos = Vector2(1600, 850 + (sim.projectiles.size() % 30) * 10)
			shot.visual_id = sim.projectiles.size()
			sim.projectiles.append(shot)
		while sim.enemy_projectiles.size() < 200:
			sim._queue_enemy_projectile({"kind":"enemy_orb", "ballistic":true, "direction":Vector2.RIGHT, "pos":Vector2(1600, 900 + sim.enemy_projectiles.size() % 30 * 8), "speed":430.0, "life":4.0, "damage":1.0})
		var start := Time.get_ticks_usec()
		sim._projectile_tick(1.0 / 60.0)
		sim._enemy_projectile_tick(1.0 / 60.0)
		samples.append(Time.get_ticks_usec() - start)
		sim.drain_events()
	samples.sort()
	observations.collision_load = {"heroes":2, "enemies":100, "friendly_projectiles":360, "enemy_projectiles":200, "frames":120, "median_ms":samples[60] / 1000.0, "p95_ms":samples[113] / 1000.0, "max_ms":samples.back() / 1000.0}
	check(samples[113] < 16000, "560-projectile swept collision fixture stays within a 16 ms collision budget at p95")
	print("BALLISTIC COLLISION LOAD: " + JSON.stringify(observations.collision_load))
