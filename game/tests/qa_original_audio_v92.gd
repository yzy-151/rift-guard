extends SceneTree
var failures:=0
func check(ok:bool,msg:String):
 if not ok:failures+=1;push_error(msg)
func _initialize():call_deferred("run")
func run():
 var director=load("res://scripts/audio_director.gd").new();director.save_path="user://qa_audio_v92_settings.json";root.add_child(director)
 var mixer=load("res://scripts/combat_audio_director.gd").new();mixer.audio_director=director;root.add_child(mixer);await process_frame
 for key:String in mixer.bank:
  check(not mixer.streams[key].is_empty(),"missing stream "+key)
  for clip:AudioStream in mixer.streams[key]:check(clip.get_length()>.04,"empty "+key)
 for key in ["galio_winds","galio_durand","galio_punch","galio_entrance","kindred_respite","kindred_wolf","kindred_dance","needle_volley","attack_hero_13"]:
  check(str(mixer.bank[key].get("provenance","")).begins_with("original"),"original replacement "+key)
 check(mixer.try_skill_voice("hero_03","hydro",false),"Furina skill voice")
 check(not mixer.try_skill_voice("hero_10","anemo",true),"global voice throttling")
 mixer.reset()
 check(mixer.try_skill_voice("traveler","hydro",true),"Lumine element voice")
 for slot in mixer.slots:
  if slot.player.playing:check(slot.player.pitch_scale==1.0,"voice must preserve pitch")
 mixer.reset()
 mixer.voices.append({"key":"voice_down_hero_03","at":999.0})
 check(not mixer.try_skill_voice("hero_10","anemo",true),"queued down line wins")
 mixer.reset()
 check(not mixer.try_skill_voice("traveler","electro",true),"embedded voice avoids duplicate speech")
 for i in 1000:mixer.play_cue("galio_winds_pulse")
 check(mixer.slots.size()==18,"bounded pool")
 print("V92 ORIGINAL AUDIO failures=",failures," cues=",mixer.bank.size())
 mixer.reset();mixer.queue_free();director.queue_free();await process_frame;quit(failures)
