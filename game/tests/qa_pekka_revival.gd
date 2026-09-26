extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
var failures=0
func check(value: bool,label: String):
 if not value:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 for endless in [false,true]:
  var sim=Sim.new(825,true)
  var squad: Array[String]=["traveler"]
  sim.reset_stage("stage_02",squad,825);sim.start()
  sim.endless_mode=endless
  sim.enemies.clear();sim.enemy_lookup.clear();sim.terrain_features.clear()
  var e=sim.spawn_enemy(Vector2(850,360),"shielded")
  e.armor=0;e.shield=0
  var kills=sim.kills
  sim.apply_hit(e,1e12,"",0)
  check(e.hp==0 and e.revive_pending,"First lethal enters down state")
  check(sim.kills==kills,"No premature kill reward")
  check(sim.apply_hit(e,1e12,"",0)==0,"Corpse cannot be hit")
  var position=e.pos
  sim._enemy_tick(float(e.revive_duration)-0.01)
  check(sim.enemies.has(e) and e.hp==0 and e.pos==position,"Corpse retained and motionless for animation plus four seconds")
  sim._enemy_tick(0.02)
  check(e.hp==e.max_hp and not e.revive_pending,"Full HP resurrection")
  check(sim.enemy_lookup.has(int(e.id)),"Target lookup restored")
  sim.apply_hit(e,1e12,"",0)
  check(e.hp<=0 and not e.revive_pending and sim.kills==kills+1,"Second lethal is final and rewards exactly once")
  sim._enemy_tick(0.1)
  check(not sim.enemies.has(e),"Final corpse removed from simulation")
 print("REVIVAL normal/endless checks=16 failures=",failures)
 quit(1 if failures else 0)
