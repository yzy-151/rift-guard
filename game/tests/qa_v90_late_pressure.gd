extends SceneTree
func _initialize():call_deferred("run")
func run():
 var s=load("res://scripts/combat_simulation.gd").new();var squad:Array[String]=["traveler","hero_01","hero_04"]
 s.reset_stage("stage_endless",squad,42);s.start();s.elapsed=900;s.endless_next_boss_at=901
 for h in s.heroes:
  h.hp=100000;h.max_hp=100000;h.damage*=50;h.rate*=3;h.range=500;h.projectile_count=4;h.pierce=3
 var peak:=0;var timings:Array[float]=[]
 for i in 3600:
  if s.state=="lost":break
  if s.state=="reward":s.choose_reward(0,0)
  var t=Time.get_ticks_usec();s.tick(1.0/60);timings.append((Time.get_ticks_usec()-t)/1000.0);s.drain_events();peak=maxi(peak,s.enemies.size())
 assert(s.state=="lost","late strong squad must be overwhelmed")
 timings.sort();print("V90 LATE SQUAD LOST at=",s.elapsed," peak=",peak," cpu_p95=",timings[int(timings.size()*0.95)])
 quit()
