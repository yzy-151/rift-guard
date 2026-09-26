extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
var failures=0
func check(ok: bool, copy: String):
 if not ok:failures+=1;push_error(copy)
func _initialize():call_deferred("run")
func run():
 var squad: Array[String]=["traveler","hero_02","hero_06"]
 var s=Sim.new(82,true)
 for index in range(1,9):
  var id="stage_%02d"%index
  s.reset_stage(id,squad,82);s.start()
  var expected=1
  for w in s.stage_runtime.definition.waves:expected+=int(w.count)*(7 if w.enemy_id=="troop_cannon" else (3 if w.enemy_id=="rift_bat" else 1))
  var total=0
  for tick in 6000:
   s.elapsed=tick*0.1
   s._stage_spawn_tick(0.1);s._troop_spawn_tick(0.1)
   total+=s.enemies.size()
   s.enemies.clear();s.enemy_lookup.clear();s.drain_events()
   if s.stage_runtime.all_spawns_emitted and s.pending_stage_spawns.is_empty() and s.pending_troop_spawns.is_empty():break
  check(total==expected,"Spawn count mismatch "+id)
  print("SPAWN ",id," expected=",expected," actual=",total)
 s.reset_stage("stage_03",squad,82)
 for i in 12:
  var e=s.spawn_on_route("grunt","main",i)
  check(not e.is_empty() and e.kind=="grunt","Repeated normal monsters must not throw or inject elites")
 s.reset_stage("stage_02",squad,82);s.elapsed=0
 var early=s.spawn_enemy(Vector2(1100,360),"grunt")
 s.elapsed=245
 var late=s.spawn_enemy(Vector2(1100,360),"grunt")
 check(late.hp>early.hp*5 and late.level>early.level,"Level based late health progression")
 check(s.deployment_required_level(1)==2,"Second-stage reinforcement at level two")
 s.reset_stage("stage_06",squad,82)
 check(s.deployment_slot_unlocked(2),"Late campaign opens all three deployment slots")
 print("V82_SPAWNS failures=",failures)
 quit(1 if failures else 0)
