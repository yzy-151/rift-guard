extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
const Mixer=preload("res://scripts/combat_audio_director.gd")
const AudioDirector=preload("res://scripts/audio_director.gd")
const Moves=["rift_laser","rift_orbs","rift_overhead","rift_storm","slime_bounce","slime_burst","slime_reflux","slime_court","kindred_dance","kindred_wolf","kindred_dread","kindred_hunt","kindred_lasers","galio_entrance","galio_punch","galio_winds","galio_durand"]
var checks:=0
var failures:Array[String]=[]
var played:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error("master，AUDIO REFERENCE QA: "+label)
func fixture():
	var sim=Sim.new(9284,true)
	sim.reset_stage("stage_endless",["traveler"],9284);sim.start()
	sim.enemies.clear();sim.events.clear();sim.supports.clear();sim.terrain_features.clear()
	sim.heroes[0].deployed=true;sim.heroes[0].pos=Vector2(900,600);sim.heroes[0].target=Vector2(900,600)
	sim.heroes[0].hp=1000000;sim.heroes[0].max_hp=1000000
	sim.active_view_rect=Rect2(300,300,1300,620)
	return sim
func active_slot(mixer,key:String)->Dictionary:
	for slot:Dictionary in mixer.slots:
		if str(slot.get("key",""))==key and slot.player.playing:return slot
	return {}
func actual_charge(sim,enemy:Dictionary,move:String)->void:
	enemy.special_pending=true;enemy.special_move=move
	if move.begins_with("rift_"):sim._start_rift_warning(enemy,move)
	elif move.begins_with("slime_"):sim._start_slime_warning(enemy,move)
	elif move.begins_with("kindred_"):sim._start_kindred_warning(enemy,move)
	else:sim._start_galio_warning(enemy,move)
func run()->void:
	var mixer=Mixer.new();root.add_child(mixer)
	await process_frame
	mixer.cue_played.connect(func(key:String):played.append(key))
	var patch:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("../qa/combat-audio-reference-20261006/audio-patch.json"))
	var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("../qa/combat-audio-reference-20261006/audio-audit.json"))
	var before:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("../qa/combat-audio-reference-20261006/before-bank.json"))
	check(patch.size()==47,"47 skill-specific Boss/support/protection/actual-impact cues")
	check(not audit.source_videos_shipped,"no extracted reference soundtrack in product")
	for key:String in before:
		if not patch.has(key):check(before[key]==mixer.bank.get(key),"untouched hero/signature/voice/device cue "+key)
	for row:Dictionary in audit.cues:
		var key:=str(row.key)
		check(int(row.sample_rate)==32000 and int(row.clipped_samples)==0 and float(row.peak_dbfs)<-2.7,"actual PCM headroom and sampling "+key)
		check(mixer.streams.has(key) and mixer.streams[key].size()==1,"real imported AudioStream "+key)
		check(mixer.bank[key]==patch[key],"bound reviewed source "+key)
		var length:float=mixer.streams[key][0].get_length()
		check(absf(length-float(row.seconds))<.001,"quantized duration equals actual playback "+key)
		if key.ends_with("_charge"):
			check(length==2.0 and float(row.envelope_peak_seconds)>1.2,"charge contraction occurs late, no continuous drone "+key)
		else:check(length<=.55,"short non-looping release/hit "+key)
	var visible:=Rect2(300,300,1300,620)
	for move:String in Moves:
		for phase:int in [1,3]:
			mixer.reset();played.clear()
			var sim=fixture()
			var kind:="boss_01" if move.begins_with("rift_") else ("boss_02" if move.begins_with("slime_") else ("boss_03" if move.begins_with("kindred_") else "boss_galio"))
			var enemy:Dictionary=sim.spawn_enemy(Vector2(900,600),kind)
			enemy.boss_phase=phase
			actual_charge(sim,enemy,move)
			mixer.accept(sim.drain_events(),sim,visible)
			check(played==[move+"_charge"],"actual phase%d warning starts once %s"%[phase,move])
			var slot:=active_slot(mixer,move+"_charge")
			check(not slot.is_empty(),"real warning player running "+move)
			if not slot.is_empty():
				var total:float=slot.player.stream.get_length()/slot.player.pitch_scale
				check(absf(total-float(enemy.special_warning))<.001,"actual pitch matched warning "+move)
				check(mixer.focus_until-Time.get_ticks_msec()*.001<=total+.02,"music duck does not overrun pitched container "+move)
			for frame in 12:mixer.accept([],sim,visible)
			check(played.size()==1,"warning polling is idempotent "+move)
			enemy.special_pending=false;sim._execute_boss_special(enemy)
			mixer.accept(sim.drain_events(),sim,visible)
			check(played.has(move),"actual release cue phase%d %s"%[phase,move])
			check(active_slot(mixer,move+"_charge").is_empty(),"release stops old warning stem "+move)
			mixer.reset();played.clear();actual_charge(sim,enemy,move)
			mixer.accept(sim.drain_events(),sim,visible)
			sim.enemies.clear();mixer.accept([],sim,visible)
			check(active_slot(mixer,move+"_charge").is_empty(),"removed/canceled Boss never leaves charge running "+move)
	for kind:String in ["crossfire","barrage"]:
		mixer.reset();played.clear()
		var sim=fixture()
		var support_key:="support_crossfire" if kind=="crossfire" else "support_barrage"
		var total:=.85 if kind=="crossfire" else 1.35
		sim.spawn_enemy(Vector2(900,600),"grunt")
		sim.supports[support_key]={"timer":total,"interval":8.0,"power":1,"radius":105,"stacks":1}
		sim._support_tick(.001);mixer.accept([],sim,visible)
		var slot:=active_slot(mixer,kind+"_charge")
		check(played==[kind+"_charge"] and not slot.is_empty(),"real support lock starts charge "+kind)
		if not slot.is_empty():check(absf(slot.player.stream.get_length()/slot.player.pitch_scale-(total-.001))<.001,"support exactly aligned "+kind)
		for frame in 12:mixer.accept([],sim,visible)
		check(played.size()==1,"support warning not retriggered "+kind)
		sim.supports[support_key].timer=8.0;mixer.accept([],sim,visible)
		check(active_slot(mixer,kind+"_charge").is_empty(),"support cancel stops contraction "+kind)
		mixer.last_group.clear();sim._trigger_support(support_key,sim.supports[support_key]);mixer.accept(sim.drain_events(),sim,visible)
		check(played.has(kind),"real support release event "+kind)
	for kind:String in ["kindred_wolf_strike","galio_winds_pulse"]:
		mixer.reset();played.clear();var sim=fixture()
		mixer.accept([{"kind":kind,"pos":Vector2(700,600),"hits":0}],sim,visible)
		check(played.is_empty(),"empty persistent area has no fake impact "+kind)
		mixer.accept([{"kind":kind,"pos":Vector2(700,600),"hits":1}],sim,visible)
		check(played.size()==1,"actual area contact plays one hit "+kind)
	mixer.reset();played.clear()
	var storm:Array[Dictionary]=[]
	for i in 100:storm.append({"kind":"kindred_arrow_hit","pos":Vector2(700,600)})
	mixer.accept(storm,fixture(),visible)
	check(played==["boss_spectral_hit"],"100 same-frame impacts merge to bounded one accent")
	check(Mixer.POOL_SIZE==18 and mixer.slots.size()==18 and Mixer.CAPS.voice==1,"original 18-slot and single voice limit")
	mixer.reset();played.clear()
	for key:String in ["rift_laser","slime_bounce","galio_entrance"]:
		mixer.last_group.clear();check(mixer.play_cue(key),"first three simultaneous Boss releases admitted "+key)
	mixer.last_group.clear();check(not mixer.play_cue("kindred_hunt"),"fourth simultaneous Boss release bounded")
	check(Mixer._event_priority("rift_storm")>Mixer._event_priority("kindred_arrow_hit"),"release keeps priority over hit spam")
	semantic_events(mixer,visible)
	support_truth()
	var report:={"checks":checks,"failures":failures,"audio_files":patch.size(),"pool_size":mixer.slots.size(),"actual_warning_release_pairs":34,"source_videos_shipped":false,"captured":"actual simulation events, cue_played and AudioStreamPlayer.playing"}
	var file=FileAccess.open("../qa/combat-audio-reference-20261006/audio-event-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	# Let the final real WAV player drain before headless audio-server teardown.
	await create_timer(.65).timeout
	mixer.reset();mixer.queue_free()
	print("master，AUDIO REFERENCE QA ",checks," checks, ",failures.size()," failures")
	await create_timer(.15).timeout
	quit.call_deferred(0 if failures.is_empty() else 1)
func semantic_events(mixer,visible:Rect2)->void:
	mixer.reset();played.clear()
	var sim=fixture()
	var sheep:Dictionary=sim.spawn_enemy(Vector2(900,600),"boss_03")
	sim.events.clear();sim.heroes[0].hp=500000
	sim._activate_kindred_respite(sheep);mixer.accept(sim.drain_events(),sim,visible)
	check(played==["kindred_respite"],"real sanctuary activation plays protection, not bite")
	var empty:Array[Dictionary]=[]
	for frame in 12:mixer.accept(empty,sim,visible)
	check(played.size()==1,"5s protection does not loop audio or retrigger")
	mixer.last_group.clear();sim._tick_kindred_respite(sheep,5.01)
	var batch:Array[Dictionary]=sim.drain_events()
	check(batch.any(func(event:Dictionary)->bool:return str(event.kind)=="heal"),"actual protection expiry restores hero health")
	mixer.accept(batch,sim,visible)
	check(played==["kindred_respite","kindred_respite_end"],"actual restoration uses one specific chime without generic heal stack")
	mixer.reset();played.clear();sim=fixture()
	var king:Dictionary=sim.spawn_enemy(Vector2(900,600),"boss_02")
	actual_charge(sim,king,"slime_bounce");sim.events.clear();king.special_pending=false
	sim._execute_boss_special(king);mixer.accept(sim.drain_events(),sim,visible)
	check(played==["slime_bounce"],"slime jump launch plays gel, no false landing sound")
	mixer.last_group.clear();sim._enemy_hazard_tick(.001);mixer.accept(sim.drain_events(),sim,visible)
	check(played.has("boss_slime_slam_hit"),"real slime floor contact plays separate heavy wet landing")
	mixer.reset();played.clear();sim=fixture()
	sheep=sim.spawn_enemy(Vector2(900,600),"boss_03")
	actual_charge(sim,sheep,"kindred_wolf");sim.events.clear();sheep.special_pending=false
	sim._execute_boss_special(sheep);mixer.accept(sim.drain_events(),sim,visible)
	check(played==["kindred_wolf"],"spectral wolf manifest uses distinct release")
	mixer.last_group.clear();sim._enemy_hazard_tick(.001);mixer.accept(sim.drain_events(),sim,visible)
	check(played.has("kindred_wolf_strike") and not played.has("boss_spectral_hit"),"real wolf target bite differs from arrow crystal contact")
	played.clear();mixer.last_group.clear();mixer.last_key.clear();sim.heroes[0].pos=Vector2(1800,1300)
	for hazard:Dictionary in sim.enemy_hazards:hazard.pulse=0
	sim._enemy_hazard_tick(.001);mixer.accept(sim.drain_events(),sim,visible)
	check(not played.has("kindred_wolf_strike"),"empty wolf field has no fabricated biting")
	mixer.reset();played.clear();sim=fixture()
	var galio:Dictionary=sim.spawn_enemy(Vector2(900,600),"boss_galio")
	actual_charge(sim,galio,"galio_winds");sim.events.clear();galio.special_pending=false
	sim._execute_boss_special(galio);mixer.accept(sim.drain_events(),sim,visible)
	check(played==["galio_winds"],"twin winds release does not fabricate collision")
	sim._enemy_hazard_tick(.73);mixer.accept(sim.drain_events(),sim,visible)
	check(not played.has("galio_winds_pulse"),"wind travel phase has no target hit cue")
	mixer.last_group.clear();sim._enemy_hazard_tick(.001);mixer.accept(sim.drain_events(),sim,visible)
	check(played.has("galio_winds_pulse"),"actual arrived twin wind contact plays convergence cue")
func support_truth()->void:
	for kind:String in ["support_crossfire","support_barrage"]:
		var sim=fixture()
		var points:Array[Vector2]=[Vector2(900,600),Vector2(940,600),Vector2(925,600),Vector2(900,810)]
		var enemies:Array[Dictionary]=[]
		for point:Vector2 in points:
			var enemy:Dictionary=sim.spawn_enemy(point,"grunt")
			enemy.hp=10000;enemy.max_hp=10000;enemy.armor=0;enemy.aura="";enemy.shield=0
			enemies.append(enemy)
		enemies[1].shield=100000;enemies[1].max_shield=100000
		enemies[2].spawn_timer=.5
		sim.events.clear()
		var support:={"timer":8.0,"interval":8.0,"power":100,"radius":140,"stacks":1,"lane_y":600.0,"target_point":Vector2(900,600)}
		sim._trigger_support(kind,support)
		var event:Dictionary={}
		for row:Dictionary in sim.drain_events():
			if str(row.kind)==("crossfire" if kind=="support_crossfire" else "barrage"):event=row
		check(not event.is_empty(),"support actual release metadata "+kind)
		if event.is_empty():continue
		check(event.hit_positions==[points[0],points[1]],"only actual health/shield contacts produce painted impacts "+kind)
		check(enemies[0].hp==10000-100*Sim.SUPPORT_DAMAGE_SCALE,"support actual damage unchanged "+kind)
		check(enemies[1].shield==100000-100*Sim.SUPPORT_DAMAGE_SCALE and enemies[1].hp==10000,"shield damage unchanged "+kind)
		check(enemies[2].hp==10000 and enemies[3].hp==10000,"skyfall immune and out-of-area units untouched "+kind)
		for point:Vector2 in event.hit_positions:check(points.has(point),"impacts use real pre-hit positions "+kind)
