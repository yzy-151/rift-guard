extends SceneTree
var failures:=0
func check(ok:bool,msg:String):
 if not ok:failures+=1;push_error(msg)
func _initialize():call_deferred("run")
func run():
 var director=load("res://scripts/audio_director.gd").new();director.save_path="user://qa_audio_v91_settings.json";root.add_child(director)
 var mixer=load("res://scripts/combat_audio_director.gd").new();mixer.audio_director=director;root.add_child(mixer);await process_frame
 for key:String in mixer.bank:
  check(not mixer.streams[key].is_empty(),"missing stream "+key)
  for clip:AudioStream in mixer.streams[key]:check(clip.get_length()>0.04,"empty clip "+key)
 var chars=JSON.parse_string(FileAccess.get_file_as_string("res://data/v2/characters.json"))
 for hero:Dictionary in chars:
  check(mixer.bank.has(mixer.describe({"kind":"shot"},hero.id)),"attack "+hero.id)
  for ult in [false,true]:
   var ability:Dictionary=hero.ultimate if ult else hero.active_skill
   var key:String=mixer.describe({"kind":"ability_audio","ability_kind":ability.kind,"ultimate":ult},hero.id,hero.element)
   check(key=="" and ability.kind=="needle_barrage" or mixer.bank.has(key),"skill "+hero.id+str(ult)+" "+key)
 for element in ["none","anemo","pyro","hydro","electro","cryo","geo"]:
  for ult in [false,true]:check(mixer.bank.has(mixer.describe({"kind":"ability_audio","ultimate":ult},"traveler",element)),"traveler coverage")
 check(mixer.describe({"kind":"enemy_arrival","enemy_kind":"armored"})=="spawn_zombie","zombie spawn")
 check(mixer.describe({"kind":"enemy_arrival","enemy_kind":"grunt"})=="spawn_hilichurl","hilichurl spawn")
 for move in ["galio_winds","galio_durand","galio_entrance","galio_punch","kindred_lasers","kindred_wolf","kindred_respite"]:
  check(mixer.bank.has(mixer.describe({"kind":move})),"boss coverage "+move)
 mixer.reset();check(mixer.play_cue("attack_traveler"),"first attack")
 for i in 1000:mixer.play_cue("attack_traveler")
 check(mixer.played_count==1 and mixer.dropped_count==1000,"burst limiting")
 check(mixer.play_cue("hero_down"),"critical cue survives burst")
 var sim=load("res://scripts/combat_simulation.gd").new();var squad:Array[String]=["hero_06","hero_11"]
 sim.reset_stage("stage_endless",squad,42);sim.start();sim.drain_events();sim.spawn_enemy(Vector2(1600,1000),"armored")
 var spawned:=false
 for e:Dictionary in sim.drain_events():if e.kind=="enemy_arrival":spawned=true
 check(spawned,"simulation spawn hook")
 sim._execute_ability_impact(sim.heroes[0],sim.heroes[0].active_skill,sim.heroes[0].pos,false)
 var ability_audio:=false
 for e:Dictionary in sim.drain_events():if e.kind=="ability_audio":ability_audio=true
 check(ability_audio,"signature skill impact hook")
 mixer.reset();var batch:Array[Dictionary]=[{"kind":"down","hero_id":0,"pos":sim.heroes[0].pos}]
 mixer.accept(batch,sim,Rect2(0,0,3200,2200));check(mixer.voices.size()==1,"down voice queued")
 mixer.voices[0].at=Time.get_ticks_msec()*0.001-0.01
 mixer._process(.4)
 var voiced:=false
 for slot:Dictionary in mixer.slots:
  if slot.category=="voice":voiced=true
 check(voiced,"down voice playback")
 mixer.reset();check(mixer.voices.is_empty() and is_zero_approx(director.combat_duck_db),"reset restores music")
 print("AUDIO V91 cues=",mixer.bank.size()," failures=",failures)
 mixer.queue_free();director.queue_free();await process_frame;quit(1 if failures else 0)
