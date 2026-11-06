extends SceneTree

const Database = preload("res://scripts/content/game_database.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const CardPool = preload("res://scripts/rewards/card_pool.gd")
const Effects = preload("res://scripts/rewards/combat_card_effects.gd")
const Icons = preload("res://scripts/content/generated_icon_catalog.gd")
const Benefit = preload("res://scripts/card_benefit_preview.gd")
const Legacy = preload("res://scripts/reward_book.gd")

var database
var checks := 0
var failures: Array[String] = []
var observations: Dictionary = {}
var card_by_id: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FINITE CARD QA: " + label)

func _initialize() -> void:
	database = Database.new()
	for card: Dictionary in database.cards: card_by_id[str(card.id)] = card
	check(database.errors.is_empty(), "runtime database validates")
	check(database.cards.size() == 166, "all 166 currently playable cards remain")
	_test_identity_and_caps()
	_test_scaling()
	_test_distribution()
	_test_passives()
	if "--qa-integration" in OS.get_cmdline_user_args():
		_test_integration()
		check(observations.has("integrated_stats"), "integration function reaches final observation without runtime exception")
	var path := "C:/Users/23081/Desktop/codex/rift-guard/qa/rebalance-20261005/cards-finite.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): path = arg.trim_prefix("--qa-output=")
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output != null: output.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t")); output.close()
	print("FINITE CARDS QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _prepared_run(card: Dictionary = {}):
	var run = RunState.new()
	run.set_squad(["traveler", "hero_03"])
	if str(card.get("effect", "")) == "deploy_reinforcement" and str(card.get("value", "")) in run.squad:
		run.set_squad(["traveler", "hero_04"])
	run.crystal_level = 40
	run.device_cards_enabled = true
	if str(card.get("effect", "")) != "assign_traveler_element": run.traveler_element = "electro"
	for id: String in card.get("requires", []): run.buff_levels[id] = 1
	var any: Array = card.get("requires_any", [])
	if not any.is_empty(): run.buff_levels[str(any[0])] = 1
	return run

func _test_identity_and_caps() -> void:
	var baseline: Array = JSON.parse_string(FileAccess.get_file_as_string("C:/Users/23081/Desktop/codex/rift-guard/qa/rebalance-20261005/identity-baseline.json"))
	for old: Dictionary in baseline:
		var card: Dictionary = card_by_id.get(str(old.id), {})
		check(not card.is_empty() and str(card.name) == str(old.name), "%s identity unchanged" % old.id)
		if card.is_empty(): continue
		var icon_path := Icons.card_path(card)
		var expected := str(old.icon_path).replace("\\", "/").trim_prefix("game/")
		check(icon_path == "res://" + expected, "%s icon mapping unchanged" % card.id)
		check(FileAccess.get_sha256(icon_path).to_lower() == str(old.icon_sha256).to_lower(), "%s original icon SHA256 unchanged" % card.id)
		check(int(card.get("max_stacks", 0)) in range(1, 10), "%s finite level cap" % card.id)
		check(card.get("upgrade_scales", []).size() == int(card.max_stacks), "%s each level is specified" % card.id)
		var run = _prepared_run(card)
		var pool = CardPool.new(database.cards, 220)
		for level in int(card.max_stacks):
			check(pool.eligible(card, run), "%s eligible at %d" % [card.id, level])
			check(pool.apply_card(card, run, 0), "%s applies level %d" % [card.id, level + 1])
		var before := JSON.stringify(run.export_build())
		check(not pool.eligible(card, run) and not pool.apply_card(card, run, 0), "%s rejects cap+1" % card.id)
		check(JSON.stringify(run.export_build()) == before, "%s failed upgrade cannot mutate run" % card.id)
		run.buff_levels[card.id] = 999
		before = JSON.stringify(run.export_build())
		check(not pool.eligible(card, run) and JSON.stringify(run.export_build()) == before, "%s old overcap data preserved but excluded" % card.id)
	for old: Dictionary in Legacy.CARDS + Legacy.FALLBACKS: check(int(old.max) > 0, "%s hidden legacy card finite too" % old.id)
	observations.identity = {"cards":baseline.size(),"id_name_icon_preserved":true,"legacy_cards":Legacy.CARDS.size()+Legacy.FALLBACKS.size()}

func _test_scaling() -> void:
	var card: Dictionary = card_by_id.single_attack_common
	var second := CardPool.card_for_level(card, 2)
	check(is_equal_approx(float(second.value), .153), "second attack level is base .18 times .85")
	var rescaled := CardPool.card_for_level(second, 2)
	check(is_equal_approx(float(rescaled.value), float(second.value)), "rescaling an offer does not multiply twice")
	rescaled = CardPool.card_for_level(second, 3)
	check(is_equal_approx(float(rescaled.value), .126), "changing offer rank starts from canonical base")
	var bundle: Dictionary = card_by_id.v75_temporal_distortion
	var second_bundle := CardPool.card_for_level(bundle, 2)
	rescaled = CardPool.card_for_level(second_bundle, 2)
	check(second_bundle.components == rescaled.components, "bundle values cannot double scale")
	check(is_equal_approx(float(rescaled.components[0].value), .08), "bundle speed level two is exact")
	check(is_equal_approx(float(rescaled.components[1].value), .048), "bundle cooldown level two is exact")
	var run = _prepared_run()
	var pool = CardPool.new(database.cards, 92)
	var luck: Dictionary = card_by_id.luck_spark_common
	for level in 3: check(pool.apply_card(luck, run), "luck applies rank %d" % level)
	check(is_equal_approx(run.luck, .3675), "luck's own levels also diminish")
	run.luck = 9999
	var enormous := pool.adjusted_weight(card_by_id.mythic_world_breaker, run)
	run.luck = 1.5
	check(is_equal_approx(enormous, pool.adjusted_weight(card_by_id.mythic_world_breaker, run)), "old huge luck saturates probability rather than dominates")
	var hero := {"rate":1.3,"base_rate":1.3,"damage":54.0,"base_damage":54.0,"hp":500.0,"max_hp":720.0,"base_hp":720.0}
	check(Benefit.hero_lines(second, hero).contains("62.3"), "target preview shows the actual +15.3% attack")
	check(Benefit.hero_lines(second_bundle, hero).contains("攻击间隔"), "bundle target preview uses components")

func _test_distribution() -> void:
	var reach: Dictionary = {}
	var distributions: Dictionary = {}
	for crystal_level in [2, 5, 8, 12, 30]:
		for luck in [0.0, 1.5]:
			var run = _prepared_run()
			run.crystal_level = crystal_level
			run.luck = luck
			var pool = CardPool.new(database.cards, 6629 + crystal_level)
			var counts: Dictionary = {}
			for draw in 800:
				var offer: Array[Dictionary] = pool.draw_three(run)
				check(offer.size() == 3, "%d luck %.1f offer retains three legal choices" % [crystal_level, luck])
				var unique: Dictionary = {}
				for c: Dictionary in offer:
					unique[str(c.id)] = true
					counts[str(c.rarity)] = int(counts.get(str(c.rarity), 0)) + 1
					check(pool.eligible(c, run), "draw respects prerequisites, stage and cap")
					check(int(c.next_level) == 1, "offer includes real next rank")
				check(unique.size() == offer.size(), "each offer unique")
				distributions["level%d_luck%.1f" % [crystal_level, luck]] = counts
	for card: Dictionary in database.cards:
		var run = _prepared_run(card)
		run.crystal_level = 37
		run.luck = 1.5
		var pool = CardPool.new(database.cards, 2466)
		for draw in 8000:
			for candidate: Dictionary in pool.draw_three(run):
				if str(candidate.id) == str(card.id): reach[str(card.id)] = true
			if reach.has(str(card.id)): break
		check(reach.has(str(card.id)), "%s remains reachable in a legal build" % card.id)
	var run = _prepared_run()
	var pool = CardPool.new(database.cards, 1223)
	for card: Dictionary in database.cards: run.buff_levels[str(card.id)] = int(card.max_stacks)
	check(pool.draw_three(run).is_empty(), "exhausted pool is explicit empty, no infinite fallback")
	observations.draw_distribution = distributions
	observations.reachable_cards = reach.size()
	# Endgame cards and plant forms present explicit forks.
	run = _prepared_run(card_by_id.mythic_eternal_support)
	run.buff_levels.mythic_projectile_storm = 1
	check(not pool.eligible(card_by_id.mythic_world_breaker, run), "mythic explosive route excludes projectile final route")
	check(not pool.eligible(card_by_id.mythic_eternal_support, run), "mythic support route excludes projectile final route")
	run = _prepared_run(card_by_id.device_melon)
	run.buff_levels.device_gatling = 1
	check(not pool.eligible(card_by_id.device_melon, run), "melon branch cannot silently overwrite Gatling investment")
	run = _prepared_run()
	check(not pool.eligible(card_by_id.relic_drop_orbit, run), "orbit relic cannot bypass its prerequisite")
	check(not pool.eligible(card_by_id.reinforcement_hydro, run), "already-present ally cannot appear as duplicate reinforcement")
	var distribution: Dictionary = {}
	var caps: Dictionary = {}
	for card: Dictionary in database.cards:
		distribution[str(card.rarity)] = int(distribution.get(str(card.rarity), 0)) + 1
		caps[str(int(card.max_stacks))] = int(caps.get(str(int(card.max_stacks)), 0)) + 1
	observations.rarity_counts = distribution
	observations.level_caps = caps

func _test_passives() -> void:
	var hero := {"id":0,"hp":5.0,"max_hp":100.0,"rate":1.0,"base_rate":1.0,"card_attack_idle":0.0,"card_levels":{"lethal_tempo":999,"conqueror":999}}
	var multiplier := 1.0
	for attack in 12: multiplier = Effects.on_attack(hero)
	check(is_equal_approx(float(hero.rate), 1.6), "old tempo stacks saturate at +60%")
	check(is_equal_approx(multiplier, 1.36), "conqueror is additive bounded 36%, not 2^levels")
	check(is_equal_approx(float(hero.hp), 53.0), "conqueror healing is 4 per hit at rank two")
	Effects.tick(hero, 3.01)
	check(is_equal_approx(float(hero.rate), 1.0) and int(hero.conqueror_attacks) == 0, "tempo and conqueror reset on actual idle")
	hero.card_levels = {"heartsteel":3}
	hero.max_hp = 100.0
	for enemy_id in 100:
		var enemy := {"id":enemy_id}
		Effects.on_target(hero, enemy)
		Effects.on_target(hero, enemy)
	check(is_equal_approx(float(hero.max_hp), 400.0), "heartsteel first-hit growth has a lifetime +300 cap")
	hero.card_levels = {"warmogs_armor":3}
	hero.hp = 100.0
	check(is_equal_approx(Effects.tick(hero, 5.0), 90.0), "Warmog's rank three heals 90 every five seconds")

func _test_integration() -> void:
	var Simulation = load("res://scripts/combat_simulation.gd")
	var sim = Simulation.new()
	var squad: Array[String] = ["traveler", "hero_03"]
	sim.reset_stage("stage_01", squad, 510052)
	sim.run_state.crystal_level = 40
	var hero: Dictionary = sim.heroes[0]
	var base := float(hero.base_damage)
	for rank in 3:
		var card := CardPool.card_for_level(card_by_id.single_attack_common, rank + 1)
		var old := float(hero.damage)
		sim.rewards.offered.assign([card])
		check(sim.rewards.take(0, sim, 0), "actual choice accepts attack level %d" % [rank + 1])
		check(is_equal_approx(float(hero.damage) - old, base * float(card.value)), "actual delta matches scaled preview")
	check(not sim.rewards.eligible(card_by_id.single_attack_common, sim.run_state), "real Sim excludes completed attack card")
	var old_cd := float(sim.skill_cooldown_reduction)
	for rank in 2:
		sim.rewards.offered.assign([card_by_id.v75_time_compression])
		check(sim.rewards.take(0, sim), "stale canonical offer uses actual cooldown rank")
	check(is_equal_approx(float(sim.skill_cooldown_reduction)-old_cd, .216), "real skill cooldown second rank is 9.6%, not double-scaled")
	var before := float(sim.energy_gain_bonus)
	for rank in 2:
		sim.rewards.offered.assign([card_by_id.v75_skill_overload])
		check(sim.rewards.take(0, sim), "energy skill bundle accepts rank %d" % rank)
	check(is_equal_approx(float(sim.energy_gain_bonus)-before, .144), "new energy semantic applies exact two-rank efficiency")
	sim.rewards.offered.assign([card_by_id.solo_leveling])
	check(sim.rewards.take(0, sim), "XP card actual choice applies")
	var xp_before := int(sim.run_state.crystal_xp)
	sim.grant_xp(100)
	check(int(sim.run_state.crystal_xp)-xp_before == 135, "rank-one XP is +35%, not triple")
	# Synthetic corrupt/old builds exercise runtime safety without changing stored record.
	for stat: String in ["projectile_count","pierce","chain_count","blast_radius","echo_ratio","rate","armor","range","speed"]: hero[stat] = 1000.0
	sim.apply_v2_card_effect(card_by_id.global_attack_1)
	check(int(hero.projectile_count) <= 5 and int(hero.pierce) <= 3 and int(hero.chain_count) <= 3, "extreme build projectile multipliers bounded")
	check(float(hero.blast_radius) <= 140 and float(hero.echo_ratio) <= .45 and float(hero.rate) <= 5, "extreme build splash echo speed bounded")
	check(float(hero.armor) <= 240 and float(hero.range) <= 600 and float(hero.speed) <= 260, "extreme build mobility and protection bounded")
	var snapshot: Dictionary = sim.export_run_snapshot()
	check(snapshot.has("energy_gain_bonus"), "new energy efficiency exported to continuation")
	# Relic descriptions describe immediate live effects, including existing orbitals.
	sim.reset_stage("stage_02", squad, 510053)
	sim.run_state.crystal_level = 40
	sim.rewards.offered.assign([card_by_id.orbit_arcane_blades])
	check(sim.rewards.take(0, sim, 0), "orbit build selects owner before foundry relic")
	var orbital: Dictionary = sim.orbitals[0]
	var count_before := int(orbital.count)
	var radius_before := float(orbital.radius)
	sim.rewards.offered.assign([card_by_id.relic_drop_orbit])
	check(sim.rewards.take(0, sim), "foundry has a real existing-orbit prerequisite")
	check(int(orbital.count) == count_before + 1 and is_equal_approx(float(orbital.radius), radius_before * 1.20), "foundry immediately upgrades existing blades without another card")
	sim.rewards.offered.assign([card_by_id.orbit_arcane_blades])
	check(sim.rewards.take(0, sim, 0), "later blade level retains foundry form")
	check(int(sim.orbitals[0].count) == count_before + 1, "blade rebuild does not lose relic extra copy")
	hero = sim.heroes[0]
	hero.hp = 1000.0
	hero.max_hp = 1000.0
	hero.armor = 0.0
	sim.crystal_shield = 0.0
	sim.rewards.offered.assign([card_by_id.relic_drop_glass])
	check(sim.rewards.take(0, sim), "glass cannon risk card selects successfully")
	sim.damage_hero(0, 100.0)
	check(is_equal_approx(float(hero.hp), 880.0), "glass cannon really raises incoming damage by 20%")
	observations.integrated_stats = {"damage":hero.damage,"rate":hero.rate,"projectiles":hero.projectile_count,"pierce":hero.pierce,"chains":hero.chain_count,"energy_gain_bonus":sim.energy_gain_bonus}
