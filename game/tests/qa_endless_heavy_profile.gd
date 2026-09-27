extends SceneTree
func _initialize():call_deferred("run")
func run():
 var s=load("res://scripts/combat_simulation.gd").new()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 for kind in ["grunt","hilichurl_brute","shielded"]:
  s.reset_stage("stage_endless",squad,42);s.start();s.active_view_rect=Rect2(1056,935,1248,490)
  for i in 80:
   var e:Dictionary=s.spawn_enemy(Vector2(1900+(i%10)*8,1180+(i/10)*8),kind);e.hp=1000000;e.max_hp=e.hp
  var samples:Array[float]=[]
  for frame in 180:
   for h:Dictionary in s.heroes:h.hp=h.max_hp
   var t:=Time.get_ticks_usec();s._enemy_tick(1.0/60);samples.append((Time.get_ticks_usec()-t)/1000.0);s.drain_events()
  samples.sort();print(kind," enemy_tick p50=",samples[90]," p95=",samples[171])
 quit()
