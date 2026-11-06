extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS ", message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var mixer = load("res://scripts/combat_audio_director.gd").new()
	root.add_child(mixer)
	await process_frame
	for key: String in ["attack_traveler", "hit_traveler", "attack_hero_03", "hit_hero_03"]:
		check(mixer.bank.has(key) and mixer.streams[key].size() == 3, key+" has three recorded variants")
		check(bool(mixer.bank[key].fixed_pitch), key+" avoids random musical detuning")
		for index in 3:
			check(str(mixer.bank[key].files[index]).contains("comic_20261005") and mixer.streams[key][index].get_length() < .35, key+" uses a short new recording "+str(index))
	for element in ["none", "anemo", "pyro", "hydro", "cryo", "electro", "geo"]:
		check(mixer.describe({"kind":"hit", "hero_id":0, "element":element}, "traveler", element) == "hit_traveler", "Traveler "+element+" hit avoids old heavy element impact")
	check(mixer.describe({"kind":"critical", "hero_id":1}, "hero_03", "hydro") == "hit_hero_03", "Furina critical uses the same quiet drop, no second old hit")
	check(mixer.describe({"kind":"hit", "element":"hydro"}) == "hit_water", "unattributed monster/support hits remain compatible")
	check(mixer.describe({"kind":"signature_salon_hit"}) == "hit_hero_03", "Furina salon impact shares the light drop")
	var sim = load("res://scripts/combat_simulation.gd").new()
	var squad: Array[String] = ["traveler", "hero_03"]
	sim.reset_stage("stage_endless", squad, 5705)
	sim.start()
	sim.terrain_features.clear()
	sim.drain_events()
	for hero: Dictionary in sim.heroes:
		hero.pos = Vector2(1600, 1000)
		hero.target = hero.pos
		hero.deployed = true
		hero.attack_timer = 0
		hero.range = 900
		hero.crit_chance = 1.0
		hero.secondary_element = "electro"
		hero.echo_ratio = .25
		hero.chain_count = 2
		hero.blast_radius = 100.0
		hero.splash = true
	for index in 45:
		var enemy: Dictionary = sim.spawn_enemy(Vector2(1650 + index % 5 * 12, 1000 + index / 5 * 8), "grunt")
		enemy.hp = 1000000
		enemy.max_hp = enemy.hp
		enemy.armor = 0.0
		enemy.aura = ""
	sim.drain_events()
	sim._hero_tick()
	sim._pending_impact_tick(1.0)
	sim._projectile_tick(1.0)
	var batch: Array[Dictionary] = sim.drain_events()
	var shot_count := 0
	var hit_count := 0
	var traveler_hit := false
	var furina_hit := false
	for event: Dictionary in batch:
		if not str(event.kind) in ["shot", "hit", "critical"]:
			continue
		var id := int(event.get("hero_id", -1))
		var character := str(sim.heroes[id].character_id) if id >= 0 and id < sim.heroes.size() else ""
		var key: String = mixer.describe(event, character)
		if event.kind == "shot":
			shot_count += 1
			check(key in ["attack_traveler", "attack_hero_03"], "real normal attack chooses refreshed release")
		else:
			hit_count += 1
			traveler_hit = traveler_hit or key == "hit_traveler"
			furina_hit = furina_hit or key == "hit_hero_03"
			check(key in ["hit_traveler", "hit_hero_03"], "real strengthened hit has attribution and no legacy impact")
	check(shot_count == 2 and hit_count > 2 and traveler_hit and furina_hit, "actual melee/projectile + crit/chain/echo/splash produce both refreshed hit cues")
	check(sim.attack_audio_source_override == -1, "audio-only context is cleared after normal attack")
	var played: Array[String] = []
	mixer.cue_played.connect(func(key: String) -> void: played.append(key))
	mixer.accept(batch, sim, Rect2(0, 0, 4000, 3000))
	check(not played.is_empty() and played.all(func(key: String) -> bool: return key in ["hit_traveler", "hit_hero_03", "attack_traveler", "attack_hero_03"]), "actual mixer never plays old chop/knife in this attack batch")
	mixer.reset()
	var victim: Dictionary = sim.enemies[0]
	sim._emit_hit_feedback(victim, 1, "hydro", 0)
	sim._emit_hit_feedback(victim, 2, "hydro", 1)
	var mixed_sources: Array[Dictionary] = sim._compact_cosmetic_events(sim.drain_events())
	check(mixed_sources.size() == 2 and int(mixed_sources[0].hero_id) != int(mixed_sources[1].hero_id), "dense-fight feedback merging preserves different hero sound attribution")
	victim.aura = ""
	var first: float = sim.apply_hit(victim, 10.0, "", 0)
	sim.attack_audio_source_override = 1
	victim.aura = ""
	var second: float = sim.apply_hit(victim, 10.0, "", 0)
	sim.attack_audio_source_override = -1
	check(is_equal_approx(first, second), "audio context does not change damage formula")
	mixer.reset()
	check(mixer.play_cue("attack_traveler"), "new cue starts actual AudioStreamPlayer")
	for index in 1000:
		mixer.play_cue("attack_traveler")
	check(mixer.dropped_count >= 1000 and mixer.slots.size() == 18, "new attacks retain bounded pool and burst throttling")
	mixer.reset()
	mixer.queue_free()
	sim = null
	await process_frame
	await process_frame
	print("COMIC HERO AUDIO checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
