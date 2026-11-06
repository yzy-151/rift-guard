extends SceneTree
## New skill contract. The previous punchy baseline stays intact for comparison.
const OUT := "res://../outputs/skills_20261005/"
const EXPECTED := {"skill_hero_03_q":.62,"skill_hero_03_e":.87,"skill_hero_13_q":.52,"skill_hero_13_e":.48,"needle_volley":.38,"gwen_needle_hit":.17,"furina_salon_hit":.22,"furina_heal_pulse":.42,"device_place":.21,"device_pea_cast":.14,"device_pea_hit":.13,"device_explosion":.48}
var checks := 0
var failures := 0
var mixer
var played: Array[String] = []

class QuietSim extends RefCounted:
	var enemies: Array[Dictionary] = []
	var heroes: Array[Dictionary] = []
	func find_enemy(_id: int) -> Dictionary: return {}

func _initialize() -> void: run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS ",label)
	else: failures += 1; push_error(label)

func packet_sha(clip: AudioStream) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(clip.get("packet_sequence").get("packet_data")))
	return hash.finish().hex_encode()

func active(group: String) -> int:
	var count := 0
	for slot: Dictionary in mixer.slots:
		if slot.player.playing and slot.category == group: count += 1
	return count

func run() -> void:
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus(); AudioServer.set_bus_name(AudioServer.bus_count-1,"SFX")
	var limiter := AudioEffectLimiter.new(); limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"),limiter)
	mixer = load("res://scripts/combat_audio_director.gd").new(); root.add_child(mixer)
	await process_frame
	mixer.cue_played.connect(func(key: String) -> void: played.append(key))
	check(mixer.slots.size() == 18, "combat pool remains eighteen players")
	for key: String in mixer.bank:
		check(mixer.streams.get(key,[]).size() == mixer.bank[key].files.size(),key+" loads all clips")
	for key: String in EXPECTED:
		check(mixer.streams[key].size() == 2,key+" has two independent samples")
		check(bool(mixer.bank[key].fixed_pitch),key+" preserves its authored pitch")
		for clip: AudioStream in mixer.streams[key]:
			check(absf(clip.get_length()-float(EXPECTED[key])) < .045,key+" meets its exact short duration contract")
		check(float(mixer.bank[key].gain_db) <= -7.0,key+" keeps the skill below full-scale mixing")
	for element: String in ["none","anemo","hydro","pyro","geo","cryo","electro"]:
		for ultimate: bool in [false,true]:
			var key := "traveler_"+element+("_e" if ultimate else "_q")
			check(mixer.describe({"kind":"ability_audio","ultimate":ultimate},"traveler",element) == key,key+" selects the correct element and slot")
			if element == "anemo" and not ultimate: continue
			check(mixer.streams[key].size() == 2,key+" has two authored samples")
			for clip: AudioStream in mixer.streams[key]:
				check(absf(clip.get_length()-(.96 if ultimate else .72)) < .055,key+" has a bounded charge/release tail")
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"audio-preservation-baseline.json"))
	for key: String in before.cues:
		check(mixer.bank[key] == before.cues[key],key+" bank is identical to the previous packaged EXE")
		for index in mixer.streams[key].size():
			check(packet_sha(mixer.streams[key][index]) == before.sha256[mixer.bank[key].files[index]],key+" encoded sample is identical to the previous packaged EXE")
	var maps := {"signature_needle_volley":"needle_volley","signature_needle_hit":"gwen_needle_hit","gwen_needle_hit":"gwen_needle_hit","signature_salon_hit":"furina_salon_hit","signature_heal":"furina_heal_pulse","device_place":"device_place","device_pea_cast":"device_pea_cast","device_pea_hit":"device_pea_hit","device_explosion":"device_explosion","hurt":"hero_hurt"}
	for kind: String in maps: check(mixer.describe({"kind":kind}) == maps[kind],kind+" maps to its dedicated feedback")
	check(mixer.describe({"kind":"ultimate_cast"},"hero_13") == "skill_hero_13_e","Gwen needle preparation uses its authored charge")
	check(mixer.describe({"kind":"ability_audio","ability_kind":"needle_barrage"},"hero_13") == "","Gwen E never replays the full charge on each impact")
	for character: String in ["hero_03","hero_13"]:
		for ultimate: bool in [false,true]:
			check(mixer.describe({"kind":"ability_audio","ultimate":ultimate},character) == "skill_"+character+("_e" if ultimate else "_q"),character+" selects its own Q/E layer")
	check(mixer.bank.device_pea_cast.category == "device_attack" and mixer.bank.device_pea_hit.category == "device_hit","pea emitter groups never share skill/hero/enemy throttles")
	check(mixer.bank.furina_heal_pulse.category == "skill_pulse","two-second Furina heal pulses have a separate sparse group")
	var quiet := QuietSim.new()
	var visible := Rect2(0,0,1280,720)
	mixer.reset(); played.clear(); mixer.last_skill_voice = Time.get_ticks_msec() * .001
	var burst: Array[Dictionary] = [{"kind":"ability_audio","character_id":"hero_03","ultimate":true,"pos":visible.get_center()},{"kind":"shot","character_id":"traveler","pos":visible.get_center()},{"kind":"enemy_projectile_cast","enemy_kind":"buffer","pos":visible.get_center()}]
	for index in 6:
		burst.append({"kind":"device_pea_cast","pos":visible.get_center()})
		burst.append({"kind":"device_pea_hit","pos":visible.get_center()})
	mixer.accept(burst,quiet,visible)
	check(played.has("skill_hero_03_e") and played.has("attack_traveler") and played.has("enemy_bolt") and played.has("device_pea_cast") and played.has("device_pea_hit"),"same-frame skill, hero, enemy and pea feedback all remain audible")
	check(played.count("device_pea_cast") == 1 and played.count("device_pea_hit") == 1,"six simultaneous peas are merged into one release and one impact")
	check(active("device_attack") <= 2 and active("device_hit") <= 2 and mixer.slots.size() == 18,"pea subgroups retain strict pool caps")
	var dropped := int(mixer.dropped_count)
	for index in 1200: mixer.accept(burst,quiet,visible)
	check(int(mixer.dropped_count)-dropped >= 1200 and mixer.slots.size() == 18,"dense device battles cannot create extra players or bypass rate limits")
	mixer.reset(); played.clear()
	var offscreen: Array[Dictionary] = [{"kind":"device_pea_cast","pos":Vector2(-4000,-4000)},{"kind":"device_pea_hit","pos":Vector2(-4000,-4000)}]
	mixer.accept(offscreen,quiet,visible)
	check(played.is_empty(),"offscreen pea releases and hits are culled")
	check(mixer._event_attenuation({"pos":visible.position},visible,"device_attack") < -4.0,"edge device audio respects distance attenuation")
	check(mixer._event_priority("device_explosion") > mixer._event_priority("device_pea_cast"),"explosion gets feedback priority before ordinary pea sounds")
	await check_real_signature_events()
	if "--record" in OS.get_cmdline_user_args(): await record_preview(quiet,visible)
	mixer.reset(); mixer.queue_free(); await process_frame; await create_timer(.2).timeout
	var file := FileAccess.open(OUT+"skill-audio-qa.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"preservation_source":"previous packaged EXE cue entries and actual encoded Ogg packet SHA256","new_skill_contract":"Q .48-.72 s; E .48-.96 s; attack/impact .13-.22 s; five .066 s needle grains in each .38 s volley; 18-player mixer and dedicated capped pea groups","audio_input":"Model cannot hear audio; playable previews and objective tests supplied."},"\t")); file.close()
	print("SKILL AUDIO checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func check_real_signature_events() -> void:
	var sim = load("res://scripts/combat_simulation.gd").new()
	var squad: Array[String] = ["hero_03","hero_13"]
	sim.reset_stage("stage_endless",squad,1005); sim.start(); sim.enemies.clear(); sim.enemy_lookup.clear(); sim.terrain_features.clear()
	for index in sim.heroes.size():
		sim.heroes[index].deployed = true; sim.heroes[index].pos = Vector2(600,340); sim.heroes[index].hp = 100.0
	for pos: Vector2 in [Vector2(730,340),Vector2(790,340)]:
		var enemy: Dictionary = sim.spawn_enemy(pos,"grunt"); enemy.hp = 100000; enemy.max_hp = enemy.hp
		# The endless navigation grid can relocate a spawn after terrain is cleared;
		# this fixture specifically requires a victim on the true needle segment.
		enemy.pos = pos
	var furina: Dictionary = sim.heroes[0]; var gwen: Dictionary = sim.heroes[1]
	sim._execute_ability_impact(furina,furina.active_skill,Vector2(730,340),false)
	sim._execute_ability_impact(furina,furina.ultimate,Vector2(600,340),true)
	sim._execute_ability_impact(gwen,gwen.ultimate,Vector2(1000,340),true)
	sim.drain_events()
	var needle_times: Array[float] = []; var salon_hits := 0; var heals := 0; var needle_hits := 0
	for tick in 180:
		var time := float(tick+1)/120.0
		sim._skill_effect_tick(1.0/120.0)
		for event: Dictionary in sim.drain_events():
			if event.kind == "signature_needle_volley": needle_times.append(time)
			elif event.kind == "signature_salon_hit": salon_hits += 1; check(mixer.describe(event) == "furina_salon_hit","actual water projectile collision selects compact water pop")
			elif event.kind == "signature_heal": heals += 1; check(mixer.describe(event) == "furina_heal_pulse","actual two-second field healing selects sparse pulse")
			elif event.kind == "signature_needle_hit": needle_hits += 1
	check(needle_times.size() == 3 and absf(needle_times[1]-needle_times[0]-.65)<.018 and absf(needle_times[2]-needle_times[1]-.65)<.018,"real Gwen skill emits exactly three volleys at .65-second spacing")
	check(salon_hits > 0 and heals > 0 and needle_hits > 0,"real skill simulation produces water, recovery and penetrating needle impacts")
	var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"hero_device_audio_validation.json"))
	check(bool(metrics.ordinary_attack_bank_unchanged) and bool(metrics.wind_q_unchanged),"builder also guarded ordinary attack and wind Q preservation")
	sim = null

func record_preview(quiet,visible: Rect2) -> void:
	var record := AudioEffectRecord.new(); AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"),record); record.set_recording_active(true)
	var began := Time.get_ticks_msec(); var timeline: Array[Dictionary] = []
	for key: String in EXPECTED:
		timeline.append({"seconds":(Time.get_ticks_msec()-began)*.001,"cue":key})
		mixer.reset(); mixer.play_cue(key); await create_timer(maxf(.35,float(EXPECTED[key])+.15)).timeout
	timeline.append({"seconds":(Time.get_ticks_msec()-began)*.001,"cue":"six peas + attacks + enemy projectiles + three skill volleys"})
	for tick in 33:
		var events: Array[Dictionary] = [{"kind":"shot","character_id":"traveler","pos":visible.get_center()},{"kind":"enemy_projectile_cast","enemy_kind":"buffer","pos":visible.get_center()}]
		if tick % 3 == 0: events.append({"kind":"signature_needle_volley","pos":visible.get_center()})
		if tick % 11 == 0:
			for device in 6: events.append({"kind":"device_pea_cast","pos":visible.get_center()}); events.append({"kind":"device_pea_hit","pos":visible.get_center()})
		mixer.accept(events,quiet,visible); await create_timer(.10).timeout
	await create_timer(.6).timeout; record.set_recording_active(false)
	var recording := record.get_recording()
	check(recording != null and recording.data.size() > 16000,"actual AudioServer SFX bus produces nonempty recorded samples")
	if recording != null: check(recording.save_to_wav(ProjectSettings.globalize_path(OUT+"skill-audio-engine-preview.wav")) == OK,"actual limited/attenuated/throttled skill mix saves to WAV")
	var file := FileAccess.open(OUT+"skill-audio-engine-preview.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"driver":AudioServer.get_driver_name(),"timeline":timeline,"source":"Actual Godot SFX bus, cue gains, authored pitch, limiter and caps; no offline normalization"},"\t")); file.close()
