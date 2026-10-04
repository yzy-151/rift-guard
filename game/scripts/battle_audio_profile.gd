extends RefCounted
## Events mark preparation, release and contact separately; no guessed damage time.
const Voices = preload("res://scripts/battle_voice_profiles.gd")
var voices = Voices.new()
const HERO_TIMBRES := {"traveler":"blade", "hero_01":"water", "hero_02":"wind", "hero_03":"water", "hero_04":"water", "hero_06":"arc", "hero_07":"music", "hero_08":"ice", "hero_10":"wind", "hero_13":"blade"}
const ELEMENT_TIMBRES := {"pyro":"fire", "hydro":"water", "electro":"arc", "cryo":"ice", "anemo":"wind", "geo":"stone", "none":"blade", "":"blade"}

func describe(event: Dictionary, sim = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var kind: String = str(event.get("kind", ""))
	var hero: Dictionary = _hero(event, sim)
	var character: String = str(event.get("character_id", hero.get("character_id", "traveler")))
	var element: String = str(event.get("element", hero.get("element", "none")))
	var timbre: String = str(HERO_TIMBRES.get(character, ELEMENT_TIMBRES.get(element, "blade")))
	if character == "traveler":
		timbre = str(ELEMENT_TIMBRES.get(element, "blade"))
	match kind:
		"terrain_react":
			var device:=str(event.get("type",""))
			var phase:=str(event.get("phase",""))
			if phase=="warning":
				result.append(_fx("warning","terrain_prepare",45,0.0,-13.0))
			elif phase=="active":
				result.append(_fx("arc_release" if device=="relay" else "fire_release","terrain_release",55,0.0,-9.0))
			elif device=="spring" and phase=="pulse":
				result.append(_fx("heal","terrain_spring",35,0.0,-15.0))
		"deploy", "down":
			result.append(_voice(character, kind, 100 if kind == "down" else 40))
			result.append(_fx("body_down" if kind == "down" else "deploy", "impact" if kind == "down" else "release", 80))
			if kind == "down": result.append(_fx("cloth_down", "tail", 60, 0.08, -8.0))
		"skill_cast", "ultimate_cast":
			result.append(_voice(character, "e" if kind == "ultimate_cast" else "q", 80 if kind == "ultimate_cast" else 55))
			result.append(_fx("ice_release" if timbre == "ice" else "deploy", "prepare", 50, 0.0, -10.0))
		"skill_geometry":
			var geometry: Dictionary = event.get("geometry", {})
			var shape: String = str(geometry.get("shape", "circle"))
			result.append(_fx(_release(timbre), "release", 70, 0.0, -3.0))
			match shape:
				"line": result.append(_fx("pierce", "release", 65, 0.045, -5.0))
				"cone": result.append(_fx("music_wave" if timbre == "music" else "wind_tail", "tail", 60, 0.06, -7.0))
				"cross", "rectangle": result.append(_fx("ice_tail" if timbre == "ice" else "stone_tail", "tail", 60, 0.1, -5.0))
				"lanes", "rows": result.append(_fx("wind_tail", "tail", 60, 0.12, -6.0))
				_: result.append(_fx(_tail(timbre), "tail", 60, 0.1, -7.0))
		"skill_impact", "ultimate_impact", "identity_resonance":
			result.append(_fx(_impact(timbre), "impact", 65, 0.0, -5.0))
			if kind == "ultimate_impact": result.append(_fx("low_impact", "body", 65, 0.035, -11.0))
		"shot", "attack_geometry":
			var style: String = str(event.get("style", hero.get("attack_style", "")))
			var sound: String = _release(timbre)
			if "pierc" in style or character == "hero_13": sound = "pierce"
			elif "homing" in style or character == "hero_06": sound = "orb_release"
			var shot := _fx(sound, "shot", 20, 0.0, -12.0)
			shot["min_interval"] = 0.16
			result.append(shot)
		"hit", "critical":
			var hit := _fx(_impact(str(ELEMENT_TIMBRES.get(element,"blade"))), "hit", 15, 0.0, -12.0 if kind == "hit" else -8.0)
			hit["min_interval"] = 0.09
			result.append(hit)
		"enemy_shot": result.append(_fx("arrow_release" if str(event.get("enemy_kind","")) == "ranged" else "orb_release", "shot", 30, 0.0, -9.0))
		"death":
			var enemy_kind: String = str(event.get("enemy_kind", ""))
			result.append(_fx("water_hit" if enemy_kind.begins_with("slime") else ("bat_down" if enemy_kind == "rift_bat" else "body_down"), "fall", 30, 0.0, -10.0))
		"enemy_volatile", "fireball_impact":
			result.append(_fx("heavy_impact", "impact", 70, 0.0, -6.0))
			result.append(_fx("low_impact", "body", 60, 0.02, -10.0))
		"heal", "signature_heal", "endless_supply":
			# One station pulse may heal several allies; its terrain cue plays once.
			if not event.has("terrain_id"):
				result.append(_fx("heal", "release", 40, 0.0, -11.0))
		"signature_needle_volley": result.append(_fx("pierce", "release", 55, 0.0, -6.0))
		"signature_needle_hit": result.append(_fx("blade_hit_b", "impact", 40, 0.0, -10.0))
		"signature_black_hit", "roxy_thunder": result.append(_fx("arc_hit", "impact", 45, 0.0, -9.0))
		"signature_salon_hit": result.append(_fx("water_hit", "impact", 45, 0.0, -8.0))
		"signature_chimera_pulse":
			result.append(_fx("arc_hit", "impact", 65, 0.0, -5.0))
			result.append(_fx("low_impact", "body", 60, 0.04, -11.0))
		"boss_enter", "boss_arrival":
			var boss_id: String = _boss_identity(event,sim)
			result.append(_fx("low_impact", "body", 90, 0.0, -7.0))
			result.append(_fx("slime_voice" if boss_id == "boss_02" else "rift_tail", "tail", 85, 0.08, -6.0))
			if boss_id != "boss_02": result.append(_voice(boss_id,"deploy",85))
		"boss_warning":
			var boss_id: String = _boss_identity(event,sim)
			result.append(_fx("slime_charge" if boss_id == "boss_02" else "warning", "prepare", 85, 0.0, -5.0))
			if boss_id == "boss_01":
				result.append(_voice(boss_id,"e" if int(event.get("phase",1)) >= 2 else "q",90))
			elif boss_id == "boss_03":
				var announcement: Dictionary = _voice("system","boss",85)
				announcement["min_interval"] = 12.0
				result.append(announcement)
		# boss_skill_charge and enemy_warning accompany boss_warning in simulation.
		# Use its identity-bearing event once, without duplicating the warning voice.
		"enemy_dash_warning": result.append(_fx("wind_tail", "prepare", 50, 0.0, -12.0))
		"enemy_spin": result.append(_fx("slash_b", "release", 55, 0.0, -8.0))
		"enemy_warning":
			if not bool(event.get("boss",false)):
				result.append(_fx("pierce", "prepare", 35, 0.0, -18.0))
		"rift_warning", "slime_warning", "endless_warning": result.append(_fx("warning", "prepare", 85, 0.0, -7.0))
		"rift_laser", "rift_orbs", "rift_overhead", "rift_storm":
			result.append(_fx("rift_release" if kind == "rift_laser" else ("orb_release" if kind == "rift_orbs" else "heavy_impact"), "release", 90, 0.0, -3.0))
			result.append(_fx("low_impact", "body", 85, 0.03, -9.0))
			result.append(_fx("rift_tail", "tail", 70, 0.12, -9.0))
		"slime_attack", "slime_bounce", "slime_burst", "slime_reflux", "slime_court":
			result.append(_fx("slime_voice", "release", 85, 0.0, -6.0))
			result.append(_fx("water_release", "release", 75, 0.06, -5.0))
		"slime_impact", "slime_bounce_hit", "slime_court_final":
			result.append(_fx("slime_land", "impact", 85, 0.0, -3.0))
			result.append(_fx("low_impact", "body", 70, 0.025, -10.0))
		"slime_glob_hit", "slime_court_hit": result.append(_fx("water_hit", "impact", 60, 0.0, -6.0))
		"rift_orb_hit": result.append(_fx("orb_hit", "impact", 70, 0.0, -5.0))
		"rift_arc": result.append(_fx("arc_hit", "impact", 65, 0.0, -8.0))
		"kindred_dance", "kindred_dread", "kindred_hunt":
			result.append(_fx("arrow_release", "release", 85, 0.0, -2.0))
			result.append(_fx("pierce", "tail", 70, 0.05, -5.0))
		"kindred_wolf", "kindred_wolf_strike": result.append(_fx("wolf_strike", "release", 75, 0.0, -5.0))
		"kindred_arrow_hit": result.append(_fx("arrow_hit", "impact", 65, 0.0, -6.0))
		"kindred_respite", "kindred_respite_end": result.append(_fx("respite", "release", 80, 0.0, -4.0))
		"galio_entrance", "galio_punch":
			result.append(_fx("stone_hit", "impact", 90, 0.0, -3.0))
			result.append(_fx("low_impact", "body", 85, 0.02, -6.0))
			if kind == "galio_entrance": result.append(_voice("boss_06","deploy",90))
		"galio_winds": result.append(_fx("wind_release", "release", 80, 0.0, -3.0))
		"galio_durand": result.append(_fx("respite", "release", 80, 0.0, -3.0))
	return result.filter(func(c:Dictionary)->bool:return not c.is_empty())

func _boss_identity(event: Dictionary, sim) -> String:
	var identity: String = str(event.get("boss_kind",event.get("enemy_kind",event.get("boss_id",""))))
	if identity.is_empty() and sim != null:
		for enemy: Dictionary in sim.enemies:
			if int(enemy.get("id",-1)) == int(event.get("enemy_id",-2)):
				identity = str(enemy.get("kind",""))
				break
	return "boss_06" if identity == "boss_galio" else ("boss_01" if identity.is_empty() else identity)

func _hero(event: Dictionary, sim) -> Dictionary:
	if sim == null: return {}
	var id: int = int(event.get("hero_id", event.get("source_id", -1)))
	return sim.heroes[id] if id >= 0 and id < sim.heroes.size() else {}

func _voice(character: String, slot: String, priority: int) -> Dictionary:
	var cue: Dictionary = voices.resolve(character,slot)
	if cue.is_empty(): return {}
	cue.merge({"key":cue.voice_id,"category":"voice","priority":priority,"volume_db":-1.0,"delay":0.0,"min_interval":1.0,"dedupe_key":"voice:"+character+":"+slot},true)
	return cue

func _fx(key: String, stage: String, priority: int, delay: float = 0.0, volume: float = -6.0) -> Dictionary:
	var cue: Dictionary = voices.manifest.get("assets", {}).get(key, {}).duplicate(true)
	if cue.is_empty(): return {}
	cue.merge({"key":key,"category":"sfx","stage":stage,"priority":priority,"delay":delay,"volume_db":volume,"min_interval":0.12 if priority < 70 else 0.35,"dedupe_key":"sfx:"+key+":"+stage},true)
	return cue

func _release(timbre: String) -> String:
	return {"blade":"slash_a","stone":"stone_tail"}.get(timbre,timbre+"_release")
func _impact(timbre: String) -> String:
	return {"blade":"blade_hit_a","wind":"body_down","music":"music_wave"}.get(timbre,timbre+"_hit")
func _tail(timbre: String) -> String:
	return {"blade":"slash_b","arc":"orb_hit","fire":"fire_hit","music":"music_wave"}.get(timbre,timbre+"_tail")
