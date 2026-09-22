extends RefCounted

const CardEffects = preload("res://scripts/rewards/combat_card_effects.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("CARD PASS: ", label)
	else:
		failures += 1
		push_error("CARD FAIL: " + label)

func find_card(cards: Array[Dictionary], card_id: String) -> Dictionary:
	for card: Dictionary in cards:
		if str(card.get("id", "")) == card_id:
			return card
	return {}

func run(game) -> void:
	var sim = game.sim
	var cards: Array[Dictionary] = sim.database.cards
	check(cards.size() == 80, "expanded 80-card pool loads")
	var bound_cards := 0
	var element_gated := 0
	var resonances := 0
	for card: Dictionary in cards:
		if not str(card.get("character_id", "")).is_empty(): bound_cards += 1
		if not str(card.get("requires_element", "")).is_empty(): element_gated += 1
		if str(card.get("effect", "")) == "assign_traveler_element": resonances += 1
	check(bound_cards == 0 and element_gated == 0 and resonances == 6, "no character or element gated duplicates remain")
	check(find_card(cards, "orbit_arcane_blades").get("target", "") == "character" and find_card(cards, "orbit_spell_rings").get("target", "") == "character", "orbit cards now require a selected owner")
	check(find_card(cards, "global_laststand_1").get("name", "") == "坚毅不倒" and find_card(cards, "mechanic_execution").get("name", "") == "收集者", "requested card names are current")
	check(float(find_card(cards, "single_attack_common").get("value", 0.0)) < float(find_card(cards, "single_attack_rare").get("value", 0.0)) and float(find_card(cards, "single_attack_rare").get("value", 0.0)) < float(find_card(cards, "single_attack_epic").get("value", 0.0)) and float(find_card(cards, "single_attack_epic").get("value", 0.0)) < float(find_card(cards, "single_attack_legendary").get("value", 0.0)), "advanced attack tiers increase power")
	check(float(find_card(cards, "global_speed_1").get("value", 0.0)) < float(find_card(cards, "global_speed_rare").get("value", 0.0)) and float(find_card(cards, "global_speed_rare").get("value", 0.0)) < float(find_card(cards, "global_speed_epic").get("value", 0.0)) and float(find_card(cards, "global_speed_epic").get("value", 0.0)) < float(find_card(cards, "global_speed_legendary").get("value", 0.0)), "advanced team speed tiers increase power")
	check(int(find_card(cards, "single_range_rare").get("value", 0)) < int(find_card(cards, "single_range_epic").get("value", 0)) and int(find_card(cards, "single_range_epic").get("value", 0)) < int(find_card(cards, "single_range_legendary").get("value", 0)), "advanced range tiers increase power")
	var squad: Array[String] = ["traveler", "hero_01", "hero_04"]
	sim.reset_stage("stage_01", squad, 7101)
	sim.start()
	check(sim.database.errors.is_empty(), "new card content validates")
	var attack_card := find_card(cards, "single_attack_common")
	sim.state = "reward"
	sim.rewards.offered.clear()
	for i in 3: sim.rewards.offered.append(attack_card)
	game.hud.reward_panel.display(sim)
	var traveler_damage := float(sim.heroes[0].damage)
	var second_damage := float(sim.heroes[1].damage)
	game.choose_reward(0)
	check(sim.state == "reward" and game.hud.reward_panel.target_overlay.visible, "single character card requests a target")
	game.hud.reward_panel._pick_target(1)
	check(sim.state == "running" and is_equal_approx(float(sim.heroes[0].damage), traveler_damage) and float(sim.heroes[1].damage) > second_damage, "selected character alone receives the card")
	var global_card := find_card(cards, "global_attack_1")
	sim.state = "reward"
	sim.rewards.offered.clear()
	for i in 3: sim.rewards.offered.append(global_card)
	game.hud.reward_panel.display(sim)
	traveler_damage = float(sim.heroes[0].damage)
	second_damage = float(sim.heroes[1].damage)
	game.choose_reward(0)
	check(sim.state == "running" and float(sim.heroes[0].damage) > traveler_damage and float(sim.heroes[1].damage) > second_damage, "team card applies immediately to the whole squad")
	var advanced_single := find_card(cards, "single_attack_legendary")
	second_damage = float(sim.heroes[1].damage)
	traveler_damage = float(sim.heroes[0].damage)
	sim.apply_v2_card_effect(advanced_single, 1)
	check(is_equal_approx(float(sim.heroes[1].damage) - second_damage, float(sim.heroes[1].base_damage) * 1.0) and is_equal_approx(float(sim.heroes[0].damage), traveler_damage), "advanced single-target card applies its listed value")
	var advanced_team := find_card(cards, "global_speed_legendary")
	var traveler_rate := float(sim.heroes[0].rate)
	sim.apply_v2_card_effect(advanced_team)
	check(is_equal_approx(float(sim.heroes[0].rate) - traveler_rate, float(sim.heroes[0].base_rate) * 0.55), "advanced team card applies its listed value")
	var original_range := float(sim.attack_range_screen_radii(sim.heroes[1]).x)
	sim.apply_v2_card_effect(find_card(cards, "single_range_legendary"), 1)
	check(float(sim.attack_range_screen_radii(sim.heroes[1]).x) > original_range, "advanced range card expands the shared visual and hit radius")
	var pyro := find_card(cards, "element_resonance_pyro")
	check(sim.rewards.eligible(pyro, sim.run_state), "traveler can draw one element resonance")
	sim.rewards.apply_card(pyro, sim.run_state)
	sim.apply_v2_card_effect(pyro)
	check(str(sim.heroes[0].element) == "pyro" and str(sim.heroes[1].element) != "pyro", "element resonance applies only to traveler")
	check(not sim.rewards.eligible(pyro, sim.run_state) and not sim.rewards.eligible(find_card(cards, "element_resonance_hydro"), sim.run_state), "all new element cards disappear after attunement")
	var solo := find_card(cards, "solo_leveling")
	sim.rewards.apply_card(solo, sim.run_state)
	sim.rewards.apply_card(solo, sim.run_state)
	var xp_before := int(sim.run_state.crystal_xp)
	sim.grant_xp(5)
	check(int(sim.run_state.crystal_xp) - xp_before == 45, "solo leveling triples XP per stack")
	var hero := {"id":0,"rate":1.0,"base_rate":1.0,"hp":50.0,"max_hp":100.0}
	CardEffects.apply_to_hero(hero, "lethal_tempo")
	for i in 10: CardEffects.on_attack(hero)
	check(is_equal_approx(float(hero.rate), 3.0), "lethal tempo caps at +200 percent")
	CardEffects.tick(hero, 3.01)
	check(is_equal_approx(float(hero.rate), 1.0), "lethal tempo resets after three idle seconds")
	CardEffects.apply_to_hero(hero, "conqueror")
	CardEffects.apply_to_hero(hero, "conqueror")
	hero.hp = 10.0
	var sixth_multiplier := 1.0
	for i in 6: sixth_multiplier = CardEffects.on_attack(hero)
	check(is_equal_approx(sixth_multiplier, 4.0) and is_equal_approx(float(hero.hp), 100.0), "conqueror stacks damage and heals per attack")
	CardEffects.apply_to_hero(hero, "heartsteel")
	CardEffects.apply_to_hero(hero, "heartsteel")
	var enemy := {"id":100}
	CardEffects.on_target(hero, enemy)
	CardEffects.on_target(hero, enemy)
	check(is_equal_approx(float(hero.max_hp), 108.0), "heartsteel grants four HP per layer once per enemy per hero")
	CardEffects.apply_to_hero(hero, "warmogs_armor")
	CardEffects.apply_to_hero(hero, "warmogs_armor")
	hero.hp = 20.0
	var healing: float = CardEffects.tick(hero, 5.0)
	check(is_equal_approx(healing, 60.0) and is_equal_approx(float(hero.hp), 80.0), "warmog healing stacks every five seconds")
	sim.apply_v2_card_effect(find_card(cards, "lethal_tempo"), 1)
	var orbit_card := find_card(cards, "orbit_arcane_blades")
	sim.apply_v2_card_effect(orbit_card, 1)
	sim.apply_v2_card_effect(orbit_card, 2)
	check(sim.orbitals.size() == 2 and int(sim.orbitals[0].hero_id) == 1 and int(sim.orbitals[1].hero_id) == 2 and int(sim.orbitals[1].level) == 1, "orbit card tracks levels per selected hero")
	sim.state = "running"
	sim.terrain_features.clear()
	sim.enemies.clear()
	for index in sim.heroes.size(): sim.heroes[index].deployed = index == 1
	var combat_hero: Dictionary = sim.heroes[1]
	combat_hero.pos = Vector2(500, 360)
	combat_hero.target = combat_hero.pos
	combat_hero.range = 1000.0
	combat_hero.crit_chance = 0.0
	combat_hero.attack_timer = 0.0
	var rate_before := float(combat_hero.rate)
	var target: Dictionary = sim.spawn_enemy(Vector2(540, 360), "grunt")
	target.hp = 10000.0
	sim._hero_tick()
	check(int(combat_hero.shots) > 0 and float(combat_hero.rate) > rate_before, "new card fires through the real hero attack loop")
	var baseline_damage := float(sim.projectiles.back().damage)
	var last_stand := find_card(cards, "global_laststand_1")
	var original_mode: String = str(sim.run_state.mode_id)
	sim.run_state.mode_id = "endless_survival"
	check(sim.rewards.eligible(last_stand, sim.run_state), "low-health card can appear in endless mode")
	sim.run_state.mode_id = original_mode
	sim.run_state.buff_levels[last_stand.id] = 1
	combat_hero.hp = float(combat_hero.max_hp) * 0.29
	combat_hero.attack_timer = 0.0
	sim._hero_tick()
	var low_health_damage := float(sim.projectiles.back().damage)
	combat_hero.hp = float(combat_hero.max_hp) * 0.31
	combat_hero.attack_timer = 0.0
	sim._hero_tick()
	check(is_equal_approx(low_health_damage, baseline_damage * 1.5) and is_equal_approx(float(sim.projectiles.back().damage), baseline_damage), "last stand follows hero HP rather than crystal HP")
	var snapshot: Dictionary = sim.export_run_snapshot()
	check(snapshot.heroes[1].has("card_levels") and snapshot.orbitals.size() == 2, "character cards and orbitals are exported for continuation")
	print("CARD QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.audio_director.music_player.stop()
	await game.get_tree().process_frame
	game.get_tree().quit(failures)
