extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
var checks=0
func check(ok: bool, copy: String):
 checks+=1
 if not ok:push_error(copy);quit(1)
func _initialize():call_deferred("run")
func run():
 var s=Sim.new(81,true)
 var squad: Array[String]=["traveler","hero_02","hero_06"]
 s.reset_stage("stage_03",squad,81);s.start()
 var text=s.rewards.preview({"effect":"projectile_count_add","value":1,"target":"global"},s)
 check(not text.contains("\n") and text.length()<25,"Team preview must be brief")
 check(s.deployment_required_level(1)==2 and s.deployment_required_level(2)==5,"Stage three deployment thresholds")
 s.events.clear();s.grant_xp(40)
 check(s.deployment_slot_unlocked(1),"Second hero unlocks at first card")
 check(s.events.any(func(e):return e.kind=="deployment_unlocked"),"Unlock notification emitted")
 var early=s.spawn_enemy(Vector2(1000,360),"grunt").max_hp
 s.elapsed=120
 var late=s.spawn_enemy(Vector2(1000,360),"grunt").max_hp
 check(late>early*2.0,"Opening easing ends without lowering late pressure")
 var brute_times=[]
 for w in s.stage_runtime.definition.waves:
  if w.enemy_id=="hilichurl_brute":brute_times.append(float(w.at))
 check(brute_times.min()>=120,"Elite cannot precede opening growth")
 s.reset_stage("stage_02",squad,82);s.start();s.enemies.clear();s.enemy_lookup.clear()
 s._spawn_troop_group_on_route("upper",0)
 check(s.enemies.size()==1 and s.pending_troop_spawns.size()==6,"One cannon and six delayed troops")
 for i in 6:check(is_equal_approx(s.pending_troop_spawns[i].delay,(i+1)*1.5),"Troop interval")
 s._troop_spawn_tick(1.49);check(s.enemies.size()==1,"No early troop spawn")
 s._troop_spawn_tick(0.02);check(s.enemies.size()==2,"First soldier appears after 1.5 seconds")
 check(s.stage_runtime.definition.waves[8].interval>=3.5,"Second procession follows last soldier")
 print("V81_FIXES checks=",checks)
 quit()
