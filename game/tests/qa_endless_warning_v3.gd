extends SceneTree
func _initialize():
 var s=load("res://scripts/combat_simulation.gd").new()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 s.reset_stage("stage_endless",squad,42);s.start();s.drain_events()
 var count:=0
 for i in 110:
  s.elapsed=169.0+i*0.1;s.expedition.tick(s,0.1)
  for e:Dictionary in s.drain_events():
   if e.kind=="expedition_boss_warning":count+=1
 print("BOSS WARNING AUDIO CUES ",count," expected 4")
 quit(0 if count==4 else 1)
