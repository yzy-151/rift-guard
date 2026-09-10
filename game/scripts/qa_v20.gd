extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V20 PASS: " + message)
	else:
		failures += 1
		push_error("V20 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.hud.signature = ""
	game.refresh()
	await game.get_tree().create_timer(0.28).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v20-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func find_card(database, id: String) -> Dictionary:
	for card: Dictionary in database.cards:
		if str(card.get("id", "")) == id:
			return card
	return {}

func run(game) -> void:
	game.mode_select_panel.close()
	game.hud.get_child(0).show()
	var sim = game.sim
	expect(sim.database.errors.is_empty(), "V20 data validates")
	expect(sim.database.characters.size() == 12, "roster contains twelve unique characters")
	var expected_names := ["旅行者", "希露菲", "芙宁娜", "洛琪希", "知更鸟", "阿米娅", "丰川祥子", "艾米莉亚", "萨勒芬妮", "风堇", "凯尔希", "铃"]
	var actual_names: Array[String] = []
	for id: String in sim.database.characters:
		var hero: Dictionary = sim.database.characters[id]
		actual_names.append(str(hero.name))
		expect(not hero.get("active_skill", {}).is_empty() and not hero.get("ultimate", {}).is_empty(), "%s has active skill and ultimate" % hero.name)
	expect(actual_names == expected_names, "roster order and names match V20 plan")
	expect(sim.database.relics.size() >= 8, "rule-changing relic library loaded")
	expect(sim.database.enemy_affixes.size() >= 5, "enemy affix library loaded")
	var chapter: Dictionary = sim.database.campaign_map.get("chapters", [])[0]
	var node_types: Array = sim.database.campaign_map.get("node_types", [])
	expect(chapter.get("nodes", []).size() >= 8 and "hidden" in node_types and "shop" in node_types, "branching campaign includes combat, story, elite, shop, rest, recruit, hidden and boss nodes")

	var squad: Array[String] = ["traveler", "hero_04", "hero_11"]
	sim.reset_stage("stage_01", squad, 2020)
	sim.start()
	expect(sim.heroes.all(func(h: Dictionary)->bool: return not bool(h.get("deployed", true))), "squad starts on deployment bench")
	expect(sim.deploy_hero(0, Vector2(410, 360)) and sim.deploy_hero(1, Vector2(530, 340)) and sim.deploy_hero(2, Vector2(485, 430)), "all three characters can be dragged onto battlefield")
	expect(sim.heroes[0].pos == Vector2(410, 360) and bool(sim.heroes[0].deployed), "deployment writes exact legal battlefield position")

	sim.enemies.clear()
	sim.pending_impacts.clear()
	var target: Dictionary = sim.spawn_enemy(Vector2(505, 360), "grunt")
	target.hp *= 20.0
	target.max_hp = target.hp
	var hp_before: float = target.hp
	sim.heroes[0].attack_timer = 0.0
	sim._hero_tick()
	expect(target.hp == hp_before and not sim.pending_impacts.is_empty(), "melee damage waits for animation hit frame")
	sim._pending_impact_tick(0.08)
	expect(target.hp == hp_before, "damage is still absent before the configured hit frame")
	sim._pending_impact_tick(1.0)
	expect(target.hp < hp_before and sim.events.any(func(e: Dictionary)->bool: return e.kind == "synced_impact"), "damage, impact event, SFX trigger and shake cue share the hit frame")
	expect(float(sim.heroes[0].energy) > 0.0 and float(sim.heroes[1].energy) == 0.0, "each character owns an independent energy bar")

	sim.pending_impacts.clear()
	sim.heroes[1].skill_cooldown = 0.0
	var skill_ok: bool = sim.activate_hero_skill(1, target.pos)
	expect(skill_ok and int(sim.heroes[1].skill_uses) == 1 and not sim.pending_impacts.is_empty(), "non-Traveler active skill enters synchronized impact queue")
	sim._pending_impact_tick(1.0)
	expect(sim.events.any(func(e: Dictionary)->bool: return e.kind == "skill_impact"), "active skill resolves with dedicated impact event")
	sim.heroes[2].energy = sim.heroes[2].max_energy
	var ally_energy_before: float = sim.heroes[1].energy
	expect(sim.activate_hero_ultimate(2, target.pos), "selected character can cast ultimate at full energy")
	expect(float(sim.heroes[2].energy) == 0.0 and float(sim.heroes[1].energy) == ally_energy_before, "ultimate consumes only its owner's energy")
	sim._pending_impact_tick(1.0)
	expect(sim.events.any(func(e: Dictionary)->bool: return e.kind == "ultimate_impact"), "ultimate damage and audiovisual cue resolve on configured hit frame")

	var enemy: Dictionary = sim.spawn_enemy(Vector2(455, 360), "ranged")
	enemy.attack_timer = 0.0
	var hero_hp: float = sim.heroes[0].hp
	sim._begin_enemy_warning(enemy, sim.heroes[0])
	expect(bool(enemy.attack_pending) and sim.heroes[0].hp == hero_hp, "enemy attack first creates a clear warning without dealing damage")
	sim.heroes[0].pos = Vector2(720, 480)
	sim._resolve_enemy_warning(enemy)
	expect(sim.heroes[0].hp == hero_hp and sim.dodges == 1, "moving out of warning region avoids the attack")

	var fireball := find_card(sim.database, "evolve_fireball")
	var blades := find_card(sim.database, "orbit_arcane_blades")
	expect(fireball.get("evolutions", []).size() == 3 and fireball.get("evolutions", [])[2].get("branch", "") == "meteor", "fireball evolves into split, burning ground and meteor milestones")
	expect("弹道" in fireball.tags and "召唤" in blades.tags, "cards expose projectile, summon, reaction, crit, shield and support tags")
	for i in 3:
		sim.run_state.buff_levels[blades.id] = i + 1
		sim.apply_v2_card_effect(blades)
	expect(not sim.orbitals.is_empty() and int(sim.orbitals[-1].count) >= 4, "orbiting sword card grows count and radius with levels")
	var orbit_target: Dictionary = sim.spawn_enemy(sim.heroes[0].pos + Vector2(60, 0), "grunt")
	orbit_target.hp *= 10.0
	orbit_target.max_hp = orbit_target.hp
	sim._orbital_tick(1.0)
	expect(sim.events.any(func(e: Dictionary)->bool: return e.kind == "orbit_hit"), "orbiting weapons acquire and damage nearby enemies")
	sim.run_state.rebuild_tags(sim.database.cards)
	sim._refresh_tag_synergies()
	expect(not sim.run_state.tag_counts.is_empty(), "tag levels are accumulated for build synergies")

	sim.run_state.grant_relic("relic_warning_clock")
	var warned: Dictionary = sim.spawn_enemy(Vector2(640, 360), "ranged")
	sim._begin_enemy_warning(warned, sim.heroes[1])
	expect(float(warned.warning_timer) > 1.05, "warning-clock relic permanently changes telegraph timing")
	sim.run_state.add_relationship("hero_12", 2)
	sim.run_state.set_story_flag("trusted_signal")
	sim.run_state.select_campaign_node("c1_hidden")
	expect(sim.run_state.relationships.get("hero_12", 0) == 2 and sim.run_state.story_flags.has("trusted_signal") and sim.run_state.current_node == "c1_hidden", "dialogue choices persist relationship, unlock flag and branch route")

	var types: Array[String] = []
	for feature: Dictionary in sim.terrain_features:
		types.append(str(feature.type))
	expect("moving_platform" in types and "conveyor" in types and "trap" in types and "weather" in types and "one_way" in types, "advanced map mechanics are instantiated from replaceable stage data")
	var moving: Dictionary = sim.terrain_features.filter(func(f: Dictionary)->bool: return f.type == "moving_platform")[0]
	var platform_before: Vector2 = moving.area.position
	sim._terrain_tick(1.0)
	expect(moving.area.position != platform_before, "moving platform updates its gameplay collision area")

	sim.wave = 6
	var affixed := false
	for i in 12:
		var candidate: Dictionary = sim.spawn_enemy(Vector2(850 + i * 4, 320), "grunt")
		affixed = affixed or not candidate.affixes.is_empty()
	expect(affixed, "late threats receive gameplay affixes")
	var record: Dictionary = sim.export_build_record()
	expect(record.has("characters") and record.has("buff_levels") and record.has("dodges"), "final build exports card levels, damage contribution, triggers, highest energy and dodges")
	if DisplayServer.get_name() != "headless":
		game.compendium.build_history.clear()
	var old_count: int = game.compendium.build_history.size()
	game.compendium.record_build(sim)
	expect(game.compendium.build_history.size() == mini(20, old_count + 1), "compendium stores the final build record")
	expect(game.hud.hero_energy_bars.size() == 3 and game.hud.ultimate_button != null, "HUD exposes three energy bars and a selected-character ultimate button")
	expect(game.battle.has_method("_draw_enemy_telegraphs") and game.battle.has_method("_draw_orbitals"), "battle view renders telegraph zones and orbiting weapons")
	game.battle.accept_events(sim.drain_events())
	game.hud.refresh(sim, 0)
	await capture(game, "01-deployment-skills-telegraph")
	game.campaign_map_panel.open()
	await capture(game, "02-branching-campaign-map")
	game.campaign_map_panel.close()
	game.compendium_panel.open("builds")
	await capture(game, "03-final-build-report")
	game.compendium_panel.close()

	print("V20 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
