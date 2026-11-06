extends Node
## Bounded, priority-aware combat mixer; no audio file I/O during combat.
signal cue_played(key: String)
const BANK_PATH := "res://data/combat_audio_v92.json"
const POOL_SIZE := 18
const CAPS := {"attack":4,"enemy_attack":3,"device_attack":2,"device_hit":2,"hit":3,"boss":5,"boss_charge":2,"boss_release":3,"boss_hit":3,"skill":4,"skill_pulse":2,"cast":2,"spawn":1,"voice":1,"down":2,"impact":2}
const GAP := {"attack":0.055,"enemy_attack":0.12,"device_attack":0.14,"device_hit":0.10,"hit":0.08,"boss":0.08,"boss_charge":0.06,"boss_release":0.06,"boss_hit":0.12,"skill":0.10,"skill_pulse":0.3,"cast":0.12,"spawn":3.5,"voice":0.3,"down":0.15,"impact":0.15}
const PALETTES := {"traveler":"metal","hero_01":"water","hero_02":"wind","hero_03":"water","hero_04":"ice","hero_05":"music","hero_06":"dark","hero_07":"music","hero_08":"ice","hero_09":"electric","hero_10":"wind","hero_11":"machine","hero_12":"machine","hero_13":"metal"}
var bank: Dictionary = {}
var streams: Dictionary = {}
var slots: Array[Dictionary] = []
var last_key: Dictionary = {}
var last_group: Dictionary = {}
var variants: Dictionary = {}
var voices: Array[Dictionary] = []
var pending_arrivals: Dictionary = {}
var observed_charges: Dictionary = {}
var focus_until := 0.0
var duck_db := 0.0
var audio_director: Node
var enabled := true
var last_skill_voice := -100.0
var played_count := 0
var dropped_count := 0

func _ready() -> void:
	bank = JSON.parse_string(FileAccess.get_file_as_string(BANK_PATH))
	for key: String in bank:
		var clips: Array[AudioStream] = []
		for path: String in bank[key].files:
			var clip = load(path)
			if clip is AudioStream: clips.append(clip)
		streams[key] = clips
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		slots.append({"player":player,"category":"","priority":-1,"started":0.0})

func reset() -> void:
	for slot: Dictionary in slots: slot.player.stop()
	voices.clear();pending_arrivals.clear();observed_charges.clear();last_key.clear();last_group.clear();focus_until=0.0
	if is_instance_valid(audio_director): audio_director.set_combat_duck(0.0)
	duck_db=0.0
	last_skill_voice=-100.0

func _process(dt: float) -> void:
	if not enabled:
		reset();return
	var now := Time.get_ticks_msec()*0.001
	if not voices.is_empty() and now >= float(voices[0].at):
		var busy := false
		for slot: Dictionary in slots:
			if slot.category == "voice" and slot.player.playing: busy=true
		if not busy:
			var pending: Dictionary=voices.pop_front()
			if now-float(pending.at)<6.0: play_cue(str(pending.key))
	var target := -4.0 if now < focus_until else 0.0
	duck_db=move_toward(duck_db,target,dt*(30.0 if target<duck_db else 8.0))
	if is_instance_valid(audio_director):audio_director.set_combat_duck(duck_db)

func accept(batch: Array[Dictionary], sim, visible: Rect2) -> void:
	if not enabled:return
	_observe_warning_cues(sim,visible)
	# Offscreen spawns announce once when they first reach the camera, not across the map.
	for enemy:Dictionary in sim.enemies:
		var enemy_id:=int(enemy.id)
		if pending_arrivals.has(enemy_id) and visible.grow(100).has_point(enemy.pos):
			var arrival_key:=describe({"kind":"enemy_arrival","enemy_kind":enemy.kind})
			if not arrival_key.is_empty():play_cue(arrival_key)
			pending_arrivals.erase(enemy_id)
	for enemy_id in pending_arrivals.keys():
		if sim.find_enemy(int(enemy_id)).is_empty():pending_arrivals.erase(enemy_id)
	# Important cues get pool access before a burst of hits in the same frame.
	var ordered := batch.duplicate()
	var restoration_release := batch.any(func(event:Dictionary)->bool:return str(event.get("kind",""))=="kindred_respite_end")
	ordered.sort_custom(func(a:Dictionary,b:Dictionary):return _event_priority(str(a.kind),bool(a.get("critical",false)))>_event_priority(str(b.kind),bool(b.get("critical",false))))
	for event: Dictionary in ordered:
		var kind := str(event.get("kind",""))
		# The specific sanctuary restoration replaces linked generic heal taps.
		if restoration_release and kind == "heal": continue
		var id := int(event.get("hero_id",-1))
		var hero: Dictionary = sim.heroes[id] if id>=0 and id<sim.heroes.size() else {}
		var character := str(event.get("character_id",hero.get("character_id","traveler")))
		if kind=="ability_audio":
			try_skill_voice(character,str(hero.get("element","none")),bool(event.get("ultimate",false)))
		var key := describe(event,character,str(hero.get("element","none")))
		if key.is_empty():continue
		var category := str(bank.get(key,{}).get("category",""))
		if category in ["hit","attack","enemy_attack","device_attack","device_hit","skill_pulse","spawn"] and event.has("pos") and not visible.grow(180).has_point(event.pos):
			if kind=="enemy_arrival" and pending_arrivals.size()<128:pending_arrivals[int(event.enemy_id)]=true
			continue
		# Charge stems are exactly 2 seconds; even the 0.85-second support cue ends at release.
		var pitch := clampf(2.0/maxf(.1,float(event.get("duration",2.0))),.25,4.0) if kind=="boss_skill_charge" and key.ends_with("_charge") else 1.0
		if not key.ends_with("_charge"):
			_stop_charge(key+"_charge")
		if play_cue(key,pitch,_event_attenuation(event,visible,category)) and kind=="down":
			var voice := "voice_down_"+character
			if bank.has(voice):
				# Downed lines supersede queued skill chatter.
				voices.clear()
				voices.append({"key":voice,"at":Time.get_ticks_msec()*0.001+0.32})

func _stop_charge(key: String) -> void:
	for slot: Dictionary in slots:
		if str(slot.get("key",""))==key and slot.player.playing: slot.player.stop()

func _observe_warning_cues(sim,visible: Rect2) -> void:
	if str(sim.state)!="running": return
	var active := {}
	var now := Time.get_ticks_msec()*.001
	for enemy: Dictionary in sim.enemies:
		var move := str(enemy.get("special_move",""))
		# Kindred/Galio already emit boss_skill_charge. Rift/slime only expose pending state.
		if bool(enemy.get("special_pending",false)) and (move.begins_with("kindred_") or move.begins_with("galio_")):
			active["boss:%d"%int(enemy.id)]={"signature":"%s:%d"%[move,int(enemy.get("boss_cast_index",0))],"key":move+"_charge","announced":true,"retry_at":0.0}
			continue
		if not bool(enemy.get("special_pending",false)) or not (move.begins_with("rift_") or move.begins_with("slime_")): continue
		var source := "boss:%d"%int(enemy.id)
		var signature := "%s:%d"%[move,int(enemy.get("boss_cast_index",0))]
		var key := move+"_charge"
		var previous: Dictionary=observed_charges.get(source,{})
		active[source]=previous.duplicate() if previous.get("signature","")==signature else {"signature":signature,"key":key,"announced":false,"retry_at":0.0}
		if bool(active[source].announced) or now<float(active[source].retry_at): continue
		# Joining a warning late consumes the remaining duration, never overruns its release.
		var remaining := maxf(.1,float(enemy.get("special_warning",2)))
		active[source].announced=play_cue(key,clampf(2.0/remaining,.25,4.0),_event_attenuation({"pos":enemy.pos},visible,"boss_charge"))
		active[source].retry_at=now+.075
	for source in ["support_crossfire","support_barrage"]:
		if not sim.supports.has(source) or sim.enemies.is_empty(): continue
		var support: Dictionary=sim.supports[source]
		var limit := .85 if source=="support_crossfire" else 1.35
		var remaining := float(support.get("timer",99))
		var lock := "lane_y" if source=="support_crossfire" else "target_point"
		if remaining<=0 or remaining>limit or not support.has(lock): continue
		var key := "crossfire_charge" if source=="support_crossfire" else "barrage_charge"
		active[source]=observed_charges.get(source,{"signature":key,"key":key,"announced":false,"retry_at":0.0}).duplicate()
		if bool(active[source].announced) or now<float(active[source].retry_at): continue
		var point := Vector2(visible.get_center().x,float(support.lane_y)) if source=="support_crossfire" else Vector2(support.target_point)
		active[source].announced=play_cue(key,clampf(2.0/maxf(.1,remaining),.25,4.0),_event_attenuation({"pos":point},visible,"boss_charge"))
		active[source].retry_at=now+.075
	for source in observed_charges:
		var old_key:=str(observed_charges[source].key)
		if not active.has(source) or str(active[source].key)!=old_key:
			var still_pending := false
			for pending: Dictionary in active.values():
				if str(pending.key)==old_key: still_pending=true;break
			if not still_pending: _stop_charge(old_key)
	observed_charges=active

func try_skill_voice(character: String, element: String, ultimate: bool) -> bool:
	var now := Time.get_ticks_msec()*0.001
	if now-last_skill_voice<5.0 or not voices.is_empty():return false
	var suffix := "e" if ultimate else "q"
	var effect_key := "traveler_"+_element(element)+"_"+suffix if character=="traveler" else "skill_"+character+"_"+suffix
	if bool(bank.get(effect_key,{}).get("contains_voice",false)):return false
	var key := "voice_skill_"+character+"_"+suffix
	if character=="traveler":key="voice_skill_traveler_"+_element(element)+"_"+suffix
	if play_cue(key):
		last_skill_voice=now
		return true
	return false

static func _event_priority(kind: String, critical: bool = false) -> int:
	if kind=="down":return 6
	if kind in ["rift_orb_hit","slime_bounce_hit","slime_glob_hit","slime_court_hit","kindred_arrow_hit","kindred_wolf_strike","galio_winds_pulse"]:return 3
	if kind.begins_with("galio_") or kind.begins_with("kindred_") or kind.begins_with("rift_") or kind.begins_with("slime_") or kind in ["boss_skill_charge","crossfire","barrage"]:return 4
	if kind in ["ability_audio","ultimate_cast","skill_cast","signature_needle_volley","device_explosion"]:return 3
	if kind in ["enemy_shot","enemy_projectile_cast","hurt","device_place","signature_heal"]:return 2
	if kind in ["critical","signature_salon_hit","signature_needle_hit","gwen_needle_hit","device_pea_cast"] or (kind=="hit" and critical):return 1
	return 0

static func _event_attenuation(event: Dictionary, visible: Rect2, category: String) -> float:
	if not event.has("pos") or category in ["voice","down","spawn"]:return 0.0
	var point: Vector2 = event.pos
	var relative: float = point.distance_to(visible.get_center()) / maxf(220.0, visible.size.length() * 0.5)
	var maximum: float = 4.0 if category in ["boss","boss_charge","boss_release","boss_hit","skill","skill_pulse","impact"] else 7.0
	return -minf(maximum, relative * relative * maximum)

func describe(event: Dictionary, character: String="traveler", element: String="none") -> String:
	var kind := str(event.get("kind",""))
	match kind:
		"rift_orb_hit":return "boss_rift_hit"
		"slime_bounce_hit","slime_court_final":return "boss_slime_slam_hit"
		"slime_glob_hit","slime_court_hit":return "boss_slime_hit"
		"kindred_arrow_hit":return "boss_spectral_hit"
		"kindred_wolf_strike":return "kindred_wolf_strike" if int(event.get("hits",1)) > 0 else ""
		"galio_winds_pulse":return "galio_winds_pulse" if int(event.get("hits",1)) > 0 else ""
		"device_melon_hit":return "device_explosion"
		"down":return "hero_down"
		"shot":return "attack_"+character if bank.has("attack_"+character) else "attack_traveler"
		"enemy_shot","enemy_projectile_cast":
			var enemy_kind := str(event.get("enemy_kind", "ranged"))
			if enemy_kind in ["troop_cannon","artillery"]:return "enemy_cannon"
			if enemy_kind in ["buffer","samachurl","caster","troop_ranged"]:return "enemy_bolt"
			return "enemy_arrow"
		"hurt":return "hero_hurt"
		"skill_cast":return "cast_small"
		"ultimate_cast":return "skill_hero_13_e" if character == "hero_13" else "cast_big"
		"ability_audio":
			if str(event.get("ability_kind",""))=="needle_barrage":return "" # Each volley has its own cue.
			var slot := "e" if bool(event.get("ultimate",false)) else "q"
			if character=="traveler":return "traveler_"+_element(element)+"_"+slot
			return "skill_"+character+"_"+slot
		"skill_impact":
			if character=="traveler" and not event.has("ability_kind"):
				return "hit_"+str({"pyro":"fire","hydro":"water","cryo":"ice","electro":"electric","anemo":"wind","geo":"earth"}.get(_element(element),"metal"))
		"signature_needle_volley":return "needle_volley"
		"signature_needle_hit","gwen_needle_hit":return "gwen_needle_hit"
		"signature_chimera_pulse":return "hit_dark"
		"signature_salon_hit":return "furina_salon_hit"
		"roxy_thunder":return "hit_electric"
		"fireball_impact":return "hit_fire"
		"boss_move":
			var move := str(event.get("value",""))
			if move in ["artillery","triple_artillery","carpet_bomb","burning_ground"]:return "galio_entrance"
			if move in ["guard","rewind","heal_summon"]:return "kindred_respite"
			if move in ["crossfire","fan_burst","sweep","spiral"]:return "rift_laser"
			return "rift_storm"
		"signature_heal":return "furina_heal_pulse"
		"heal","revive":return "heal"
		"critical":return "critical_ping"
		"hit":
			if bool(event.get("critical",false)):return "critical_ping"
			# Unattributed monster/support hits keep their palette. Hero damage
			# carries audio-only attribution, including normal-attack card extras.
			if int(event.get("hero_id", -1)) >= 0 or event.has("character_id"):
				var hero_key := "hit_"+character
				if bank.has(hero_key):return hero_key
			return "hit_"+str({"pyro":"fire","hydro":"water","cryo":"ice","electro":"electric","anemo":"wind","geo":"earth"}.get(_element(str(event.get("element","none"))),"metal"))
		"shield_break","terrain_break":return "shield_break"
		"enemy_arrival":
			var enemy := str(event.get("enemy_kind",""))
			if enemy=="armored":return "spawn_zombie"
			if enemy in ["grunt","ranged","buffer","hilichurl_brute"]:return "spawn_hilichurl"
			if enemy in ["shielded","troop_cannon"]:return "spawn_heavy"
		"boss_skill_charge":
			var key := str(event.get("skill",""))+"_charge"
			return key if bank.has(key) else "cast_big"
	if bank.has(kind):return kind
	return ""

static func _element(value:String)->String:
	return str({"":"none","wind":"anemo","water":"hydro","fire":"pyro","ice":"cryo","lightning":"electro","earth":"geo","physical":"none"}.get(value,value))

func play_cue(key: String, pitch_override: float = 1.0, attenuation_db: float = 0.0) -> bool:
	if not enabled or not bank.has(key) or streams.get(key,[]).is_empty():return false
	var now := Time.get_ticks_msec()*0.001
	var cue: Dictionary=bank[key]
	var group := str(cue.category)
	var priority := int(cue.priority)
	if now-float(last_key.get(key,-100.0))<float(cue.cooldown) or now-float(last_group.get(group,-100.0))<float(GAP.get(group,0.1)):
		dropped_count+=1;return false
	var count := 0
	var chosen := -1
	var lowest := 100
	for i in slots.size():
		var slot:Dictionary=slots[i]
		if slot.player.playing:
			if str(slot.category)==group:count+=1
		elif chosen<0:chosen=i
	if count>=int(CAPS.get(group,3)):
		dropped_count+=1;return false
	if chosen<0:
		for i in slots.size():
			if int(slots[i].priority)<priority and int(slots[i].priority)<lowest:
				chosen=i;lowest=int(slots[i].priority)
	if chosen<0:dropped_count+=1;return false
	var index: int = int(variants.get(key,0))%streams[key].size()
	variants[key]=index+1
	var slot:Dictionary=slots[chosen]
	var player:AudioStreamPlayer=slot.player
	player.stop();player.stream=streams[key][index]
	player.pitch_scale=1.0 if bool(cue.get("fixed_pitch",false)) else (pitch_override if group in ["voice","down","boss","boss_charge","boss_release","boss_hit"] else randf_range(.97,1.03))
	player.volume_db=float(cue.gain_db)+clampf(attenuation_db,-18.0,0.0)-(4.0 if now<focus_until and priority<3 else 0.0)
	slot.category=group;slot.priority=priority;slot.started=now;slot.key=key
	if priority>=4:
		focus_until=maxf(focus_until,now+minf(3.0,player.stream.get_length()/maxf(.01,player.pitch_scale)))
		for other:Dictionary in slots:
			if other.player.playing and int(other.priority)<3:other.player.volume_db=minf(other.player.volume_db,-23.0)
	player.play();last_key[key]=now;last_group[group]=now;played_count+=1;cue_played.emit(key)
	return true
