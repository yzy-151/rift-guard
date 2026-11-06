extends SceneTree

## Tests the active cue bank and mixer rather than a guessed list of sounds.
var checks := 0
var failures := 0
var mixer

class QuietSim extends RefCounted:
	var enemies: Array[Dictionary] = []
	var heroes: Array[Dictionary] = []
	func find_enemy(_id: int) -> Dictionary:
		return {}

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error(label)

func _run() -> void:
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), limiter)
	mixer = load("res://scripts/combat_audio_director.gd").new()
	root.add_child(mixer)
	await process_frame
	check(mixer.slots.size() == 18, "bounded 18-player mixer")
	for key: String in mixer.bank:
		check(mixer.streams.get(key, []).size() == mixer.bank[key].files.size(), key + " loads every bank clip")
	var characters: Array[String] = ["traveler"]
	for index in range(1, 14):
		characters.append("hero_%02d" % index)
	for character in characters:
		var attack: String = "attack_" + character
		var hit: String = "hit_" + character
		check(mixer.streams.get(attack, []).size() == 3, character + " has three release variants")
		check(mixer.streams.get(hit, []).size() == 3, character + " has three quiet impact variants")
		for key: String in [attack, hit, "skill_" + character + "_q", "skill_" + character + "_e"]:
			check(mixer.bank.has(key) and mixer.streams.get(key, []).size() > 0, key + " loads")
			check(bool(mixer.bank[key].get("fixed_pitch", false)), key + " keeps authored pitch")
			for path: String in mixer.bank[key].files:
				check(path.contains("punchy_20261005"), key + " uses refreshed source")
		for stream: AudioStream in mixer.streams[attack]:
			check(stream.get_length() < 0.22, attack + " has a short release")
		for stream: AudioStream in mixer.streams[hit]:
			check(stream.get_length() < 0.18, hit + " has a short impact")
		check(mixer.describe({"kind":"hit", "hero_id":0}, character) == hit, character + " normal hit uses its palette")
		check(mixer.describe({"kind":"critical", "hero_id":0}, character) == "critical_ping", character + " critical has distinct compact feedback")
		check(mixer.describe({"kind":"hit", "critical":true, "hero_id":0}, character) == "critical_ping", character + " true critical hit flag selects compact feedback")
	for element: String in ["none", "anemo", "hydro", "pyro", "geo", "cryo", "electro"]:
		for suffix: String in ["q", "e"]:
			var key: String = "traveler_" + element + "_" + suffix
			check(mixer.streams[key].size() == 1 and mixer.streams[key][0].get_length() < 0.8, key + " is a compact skill")
	for enemy_kind: String in ["ranged", "buffer", "troop_ranged"]:
		var expected: String = "enemy_arrow" if enemy_kind == "ranged" else "enemy_bolt"
		check(mixer.describe({"kind":"enemy_projectile_cast", "enemy_kind":enemy_kind}) == expected, enemy_kind + " release maps to independent enemy sound")
		check(mixer.bank[expected].category == "enemy_attack", enemy_kind + " cannot share hero release throttle")
	check(mixer.describe({"kind":"enemy_shot", "enemy_kind":"troop_cannon"}) == "enemy_cannon", "legacy enemy shot mapping remains available")
	check(mixer.describe({"kind":"hurt"}) == "hero_hurt", "hero hurt is distinct from enemy damage")
	check(mixer.describe({"kind":"signature_salon_hit"}) == "hit_hero_03", "Furina salon uses soft impact")
	check(mixer.describe({"kind":"fireball_impact"}) == "hit_fire", "fireball impact does not replay an unrelated skill cast")
	check(mixer.describe({"kind":"skill_impact"}, "traveler", "geo") == "hit_earth", "skill impact does not duplicate full cast audio")
	var old_bank_path := ProjectSettings.globalize_path("res://../outputs/audio-reference-20261005/before-bank.json")
	var before = JSON.parse_string(FileAccess.get_file_as_string(old_bank_path))
	var identity_ok := true
	for key: String in before:
		if str(before[key].category) in ["boss", "voice", "down", "spawn"]:
			identity_ok = identity_ok and mixer.bank.has(key) and mixer.bank[key].files == before[key].files
	check(identity_ok, "boss, down, monster identity and character voices preserve their source files")
	var visible := Rect2(0, 0, 1000, 700)
	check(is_zero_approx(mixer._event_attenuation({"pos":visible.get_center()}, visible, "attack")), "camera center has no attenuation")
	check(mixer._event_attenuation({"pos":visible.position}, visible, "attack") < -4.0, "edge attacks attenuate by distance")
	check(is_zero_approx(mixer._event_attenuation({"pos":Vector2(-4000, -4000)}, visible, "voice")), "important identity voice stays audible")
	var played: Array[String] = []
	mixer.cue_played.connect(func(key: String) -> void: played.append(key))
	var sim := QuietSim.new()
	var simultaneous: Array[Dictionary] = [{"kind":"shot", "character_id":"traveler", "pos":visible.get_center()}, {"kind":"enemy_projectile_cast", "enemy_kind":"buffer", "pos":visible.get_center()}]
	mixer.accept(simultaneous, sim, visible)
	check(played.has("attack_traveler") and played.has("enemy_bolt"), "hero and enemy attacks both play in one frame")
	mixer.reset()
	played.clear()
	var offscreen: Array[Dictionary] = [{"kind":"shot", "pos":Vector2(-2000, -2000)}, {"kind":"enemy_projectile_cast", "pos":Vector2(-2000, -2000), "enemy_kind":"ranged"}]
	mixer.accept(offscreen, sim, visible)
	check(played.is_empty(), "offscreen ordinary attacks are culled")
	mixer.reset()
	check(mixer.play_cue("attack_traveler"), "new release drives an actual audio player")
	var dropped_before: int = mixer.dropped_count
	for index in 1000:
		mixer.play_cue("attack_traveler")
	check(mixer.dropped_count - dropped_before >= 1000 and mixer.slots.size() == 18, "high-density bursts remain bounded and throttled")
	mixer.reset()
	var simulation = load("res://scripts/combat_simulation.gd").new()
	var squad: Array[String] = ["traveler"]
	simulation.reset_stage("stage_endless", squad, 1005)
	simulation.start()
	simulation.terrain_features.clear()
	var hero: Dictionary = simulation.heroes[0]
	hero.pos = Vector2(1400, 900)
	hero.target = hero.pos
	hero.deployed = true
	for enemy_kind: String in ["ranged", "buffer", "troop_ranged"]:
		var enemy: Dictionary = simulation.spawn_enemy(Vector2(1550, 900), enemy_kind)
		simulation._begin_enemy_warning(enemy, hero)
		simulation.drain_events()
		simulation._resolve_enemy_warning(enemy)
		var batch: Array[Dictionary] = simulation.drain_events()
		var casts: Array[Dictionary] = batch.filter(func(event: Dictionary) -> bool: return str(event.kind) == "enemy_projectile_cast")
		check(casts.size() == 1, enemy_kind + " real simulation emits one release event")
		check(batch.filter(func(event: Dictionary) -> bool: return str(event.kind) == "enemy_shot").is_empty(), enemy_kind + " real simulation does not double its release")
		if not casts.is_empty():
			check(mixer.bank[mixer.describe(casts[0])].category == "enemy_attack", enemy_kind + " real event selects independent channel")
	hero.attack_timer = 0.0
	hero.range = 900.0
	hero.crit_chance = 1.0
	for enemy: Dictionary in simulation.enemies:
		enemy.hp = 1000000.0
		enemy.max_hp = enemy.hp
	simulation.drain_events()
	simulation._hero_tick()
	simulation._pending_impact_tick(1.0)
	simulation._projectile_tick(1.0)
	var hero_batch: Array[Dictionary] = simulation.drain_events()
	var true_crits: Array[Dictionary] = hero_batch.filter(func(event: Dictionary) -> bool: return str(event.kind) == "hit" and bool(event.get("critical", false)))
	check(not true_crits.is_empty(), "real strengthened normal attack carries critical hit flag")
	if not true_crits.is_empty():
		check(mixer.describe(true_crits[0], "traveler") == "critical_ping", "real critical normal attack plays distinct compact cue")
	mixer.reset()
	played.clear()
	var critical_batch: Array[Dictionary] = [{"kind":"hit", "pos":visible.get_center()}, {"kind":"hit", "critical":true, "pos":visible.get_center()}]
	mixer.accept(critical_batch, sim, visible)
	check(played.size() == 1 and played[0] == "critical_ping", "critical feedback takes priority over the same-frame plain impact")
	simulation = null
	if "--record" in OS.get_cmdline_user_args():
		await _record_preview()
	mixer.reset()
	mixer.queue_free()
	await process_frame
	await process_frame
	print("PUNCHY COMBAT AUDIO checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func _record_preview() -> void:
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), record)
	record.set_recording_active(true)
	var timeline: Array[Dictionary] = []
	var sections: Array[Dictionary] = [
		{"name":"Traveler / Furina / Amiya", "cues":["attack_traveler", "hit_traveler", "attack_hero_03", "hit_hero_03", "attack_hero_06", "hit_hero_06"]},
		{"name":"Hero + enemy overlapping releases", "cues":["attack_traveler", "enemy_arrow", "attack_hero_03", "enemy_bolt", "critical_ping", "hero_hurt"]},
		{"name":"Skill and recovery layers", "cues":["skill_hero_03_q", "skill_hero_06_e", "needle_volley", "heal", "shield_break"]}
	]
	var began := Time.get_ticks_msec()
	for section: Dictionary in sections:
		timeline.append({"seconds":(Time.get_ticks_msec() - began) * .001, "label":section.name})
		if str(section.name).begins_with("Hero +"):
			for index in 4:
				mixer.play_cue("attack_traveler" if index % 2 == 0 else "attack_hero_03")
				mixer.play_cue("enemy_arrow" if index % 2 == 0 else "enemy_bolt")
				await create_timer(.10).timeout
				mixer.play_cue("critical_ping" if index % 2 == 0 else "hero_hurt")
				await create_timer(.28).timeout
		else:
			for key: String in section.cues:
				mixer.play_cue(key)
				await create_timer(.46 if section == sections[0] else .72).timeout
	timeline.append({"seconds":(Time.get_ticks_msec() - began) * .001, "label":"High-density battle with independent hero / enemy release groups"})
	var sim := QuietSim.new()
	var visible := Rect2(0, 0, 1000, 700)
	for index in 30:
		var batch: Array[Dictionary] = [{"kind":"shot", "character_id":"traveler", "pos":visible.get_center()}, {"kind":"shot", "character_id":"hero_03", "pos":visible.get_center()}, {"kind":"enemy_projectile_cast", "enemy_kind":"buffer", "pos":visible.get_center()}, {"kind":"hit", "hero_id":0, "critical":index % 5 == 0, "pos":visible.get_center()}]
		mixer.accept(batch, sim, visible)
		await create_timer(.09).timeout
	await create_timer(.7).timeout
	record.set_recording_active(false)
	var output := ProjectSettings.globalize_path("res://../outputs/audio-reference-20261005/engine-mixer-preview.wav")
	var recording := record.get_recording()
	check(recording != null and recording.data.size() > 16000, "actual AudioServer recording produces samples")
	if recording != null:
		check(recording.save_to_wav(output) == OK, "actual mixer preview is saved")
	var info := {"audio_driver":AudioServer.get_driver_name(), "timeline":timeline, "source":"Actual Godot SFX bus output, no BGM, with limiter / cue gains / priority / throttle applied"}
	var metadata := FileAccess.open(output.get_basename() + ".json", FileAccess.WRITE)
	metadata.store_string(JSON.stringify(info, "\t"))
	metadata.close()
