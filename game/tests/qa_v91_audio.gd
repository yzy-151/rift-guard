extends SceneTree
const Director = preload("res://scripts/battle_audio_director.gd")
const Profile = preload("res://scripts/battle_audio_profile.gd")
const Voices = preload("res://scripts/battle_voice_profiles.gd")
var failures: int = 0
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	var voices = Voices.new()
	for id in ["traveler","hero_01","hero_02","hero_03","hero_04","hero_06","hero_07","hero_08","hero_10","hero_13"]:
		for slot in ["deploy","q","e","down"]:
			var cue: Dictionary = voices.resolve(id,slot)
			check(not cue.is_empty() and FileAccess.file_exists(cue.get("path","")), id + " " + slot + " has playable voice coverage")
			check(not str(cue.get("authenticity", "")).is_empty(), id + " " + slot + " states authenticity")
	var original_fallback_ids: Array[String] = []
	for id in ["hero_02","hero_04","hero_07","hero_08","hero_13"]:
		for slot in (["q","e","down"] if id == "hero_13" else ["deploy","q","e","down"]):
			var cue: Dictionary = voices.resolve(id,slot)
			check(str(cue.authenticity) == "original_dialogue_stock_tts_not_original_actor", id+" "+slot+" explicitly labels stock synthetic dialogue")
			check(not str(cue.get("text","")).is_empty() and not original_fallback_ids.has(str(cue.voice_id)), id+" "+slot+" uses its own written line")
			original_fallback_ids.append(str(cue.voice_id))
	for key in voices.manifest.assets:
		var asset: Dictionary = voices.manifest.assets[key]
		check(not str(asset.get("license", "")).is_empty(), str(key) + " has rights record")
		var stream := AudioStreamOggVorbis.load_from_file(str(asset.path))
		check(stream != null and stream.get_length() > 0.02, str(key) + " decodes to nonempty audio")
	var profile = Profile.new()
	var sim := {"heroes":[{"character_id":"hero_06","element":"electro"}]}
	var cast: Array[Dictionary] = profile.describe({"kind":"skill_cast","hero_id":0},sim)
	check(cast.any(func(c:Dictionary)->bool:return c.get("voice_id","")=="hero_06_q"), "hero_id resolves real Amiya skill voice")
	check(not cast.any(func(c:Dictionary)->bool:return c.get("stage","")=="impact"), "cast does not play impact ahead of contact")
	var release: Array[Dictionary] = profile.describe({"kind":"skill_geometry","hero_id":0,"geometry":{"shape":"line"}},sim)
	check(release.any(func(c:Dictionary)->bool:return c.get("stage","")=="release"), "actual geometry event plays release")
	check(not release.any(func(c:Dictionary)->bool:return c.get("category","")=="voice"), "release does not repeat cast voice")
	check(profile.describe({"kind":"signature_start","hero_id":0},sim).is_empty(), "parallel signature event does not duplicate audio")
	var goblin: Array[Dictionary] = profile.describe({"kind":"death","enemy_kind":"grunt"},sim)
	check(not goblin.any(func(c:Dictionary)->bool:return c.key in ["heavy_impact","fire_hit","low_impact"]), "ordinary monster falls without explosion")
	var bug: Array[Dictionary] = profile.describe({"kind":"enemy_volatile","bug_blast":true},sim)
	check(bug.any(func(c:Dictionary)->bool:return c.key=="heavy_impact"), "worm explosion audio waits for resolved blast")
	var down: Array[Dictionary] = profile.describe({"kind":"down","hero_id":0},sim)
	check(down.any(func(c:Dictionary)->bool:return c.get("voice_id","")=="hero_06_down"), "down has character-specific voice")
	var arrival_sim := {"heroes":[],"enemies":[{"id":42,"kind":"boss_03","hp":100}]}
	var arrival: Array[Dictionary] = profile.describe({"kind":"boss_arrival","enemy_id":42},arrival_sim)
	check(arrival.any(func(c:Dictionary)->bool:return c.get("voice_id","")=="boss_03_deploy"), "real boss_arrival event resolves enemy identity")
	var warning: Array[Dictionary] = profile.describe({"kind":"boss_warning","boss_kind":"boss_01","phase":2})
	check(warning.any(func(c:Dictionary)->bool:return c.get("voice_id","")=="commander_e"), "real commander warning includes phase voice")
	check(not warning.any(func(c:Dictionary)->bool:return c.get("stage","")=="impact"), "boss warning does not sound its impact early")
	for contact in ["slime_glob_hit","slime_court_hit","slime_bounce_hit","slime_court_final","rift_orb_hit"]:
		check(profile.describe({"kind":contact}).any(func(c:Dictionary)->bool:return c.get("stage","")=="impact"), contact+" plays resolved contact")
	check(not profile.describe({"kind":"attack_geometry","hero_id":0},sim).is_empty(), "actual melee release has sound")
	check(profile.describe({"kind":"slash","hero_id":0},sim).is_empty(), "parallel slash event cannot double melee release")
	for contact in ["signature_needle_hit","signature_black_hit","signature_chimera_pulse","signature_salon_hit","roxy_thunder"]:
		check(profile.describe({"kind":contact}).any(func(c:Dictionary)->bool:return c.get("stage","")=="impact"), contact+" preserves delayed signature contact audio")
	var dash: Array[Dictionary] = profile.describe({"kind":"enemy_dash_warning","enemy_id":12})
	check(dash.any(func(c:Dictionary)->bool:return c.key=="wind_tail" and c.stage=="prepare"), "locked dash warning uses a rising air preparation layer")
	check(not dash.any(func(c:Dictionary)->bool:return c.get("stage","")=="impact"), "dash warning does not play premature contact")
	var spin: Array[Dictionary] = profile.describe({"kind":"enemy_spin","enemy_id":13})
	check(spin.any(func(c:Dictionary)->bool:return c.key=="slash_b" and c.stage=="release"), "actual axe spin releases its distinct swing")
	var director = Director.new()
	director.playback_enabled = false
	director.handle_events([{"kind":"skill_cast","hero_id":0}],sim)
	var first: int = director.debug_snapshot().played
	director.handle_events([{"kind":"skill_cast","hero_id":0}],sim)
	check(director.debug_snapshot().played == first, "duplicate event suppressed")
	director.advance(0.12)
	check(director.debug_snapshot().duck_db < -1.0, "speech ducks effects")
	director.handle_events([{"kind":"down","hero_id":0}],sim)
	check(director.debug_snapshot().voice_key == "hero_06_down", "down interrupts lower-priority skill voice")
	for i in 200:
		director.handle_events([{"kind":"shot","hero_id":0},{"kind":"hit","element":"electro"},{"kind":"rift_storm"}],sim)
	check(director.debug_snapshot().active_sfx <= Director.MAX_SFX, "combat burst respects concurrent SFX cap")
	check(director.debug_snapshot().queued <= Director.MAX_QUEUED, "combat burst respects queue cap")
	director.advance(20.0)
	check(director.debug_snapshot().voice_key == "" and is_zero_approx(director.debug_snapshot().duck_db), "duck recovers after speech ends")
	director.reset()
	check(director.debug_snapshot().active_sfx == 0 and director.debug_snapshot().queued == 0, "reset clears active and queued transients")
	director.set_enabled(false)
	director.handle_events([{"kind":"down","hero_id":0}],sim)
	check(director.debug_snapshot().active_sfx == 0 and director.debug_snapshot().voice_key == "", "mute prevents speech and effects")
	director.set_enabled(true)
	director.handle_events([{"kind":"deploy","hero_id":0}],sim)
	check(director.debug_snapshot().voice_key == "hero_06_deploy", "reenabling after reset allows new deployment")
	director.free()
	print("V91 AUDIO checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
