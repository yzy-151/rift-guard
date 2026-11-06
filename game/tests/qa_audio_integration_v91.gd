extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://main.tscn").instantiate();root.add_child(g);await process_frame
 g.set_process(false);g.set_physics_process(false);g.test_mode=false;g.muted=false
 g.mode_select_panel.close();g.stage_select_panel.close();g.squad_panel.root.hide();g.dialogue.hide()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 g.sim.reset_stage("stage_endless",squad,42);g.sim.start();g.sim.terrain_features.clear();g.battle.camera_center=Vector2(1600,1100)
 for h:Dictionary in g.sim.heroes:h.pos=Vector2(1600,1100);h.hp=1000000;h.max_hp=h.hp;h.range=600;h.rate=5;h.energy=100
 for i in 80:g.sim.spawn_enemy(Vector2(1660+(i%8)*12,1070+(i/8)*6),["grunt","armored","ranged","hilichurl_brute"][i%4])
 var samples:Array[float]=[]
 for frame in 180:
  if frame%60==0:
   var id:=frame/60;g.sim.activate_hero_skill(id,Vector2(1680,1100))
  g.sim.tick(1.0/60)
  var start:=Time.get_ticks_usec();g.process_events();samples.append((Time.get_ticks_usec()-start)/1000.0)
  await process_frame
 var fatal:Array[Dictionary]=[{"kind":"down","character_id":"hero_06","hero_id":0,"pos":g.sim.heroes[0].pos}]
 g.combat_audio.accept(fatal,g.sim,g.battle.visible_world_rect());assert(not g.combat_audio.voices.is_empty())
 var active:=0
 for slot:Dictionary in g.combat_audio.slots:if slot.player.playing:active+=1
 assert(active<=18);samples.sort()
 print("INTEGRATED AUDIO PASS played=",g.combat_audio.played_count," dropped=",g.combat_audio.dropped_count," active=",active," event_p95_ms=",samples[171])
 g.combat_audio.reset();g.queue_free();await process_frame;quit()
