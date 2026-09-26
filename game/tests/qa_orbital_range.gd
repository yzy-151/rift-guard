extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
var failures=0
var checks=0
func check(ok: bool,text: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(text)
 else:print("PASS "+text)
func _initialize():call_deferred("run")
func run():
 for endless in [false,true]:
  var s=Sim.new(21,true)
  var squad: Array[String]=["traveler"]
  s.reset_stage("stage_02",squad,21);s.start();s.endless_mode=endless
  s.enemies.clear();s.enemy_lookup.clear();s.terrain_features.clear()
  var h=s.heroes[0];h.deployed=true;h.pos=Vector2(650,360)
  s.active_view_rect=Rect2(0,0,1400,800)
  var radius=248.0
  var c=Vector2(h.pos) if endless else Sim.StageProjection.project(h.pos)
  var r=s.ability_area_screen_radii(h.pos,radius)
  for factor in [0.98,1.02]:
   var projected=c+Vector2(r.x*factor,8)
   var pos=projected if endless else Sim.StageProjection.unproject(projected)
   var e=s.spawn_enemy(pos,"grunt");e.hp=10000;e.max_hp=10000;e.armor=0;e.shield=0
  var o={"hero_id":0,"source_card":"orbit_arcane_blades","count":3,"radius":radius,"damage":50.0,"timer":0.0,"interval":0.7,"life":99.0,"element":"","visual":"blade","level":1}
  s.orbitals.append(o);s._orbital_tick(0.05)
  check(s.enemies[0].hp<10000,"Inside outline is hit "+str(endless))
  check(s.enemies[1].hp==10000,"Outside outline is excluded "+str(endless))
  check(o.phase>0,"Simulation owns orbital phase")
  var events=s.drain_events().filter(func(e):return e.kind=="orbit_hit")
  check(events.size()==1 and events[0].has("angle") and events[0].radius==radius,"Strike carries orbit source and radius")
  var hp=s.enemies[0].hp;h.hp=0;s._orbital_tick(1)
  check(s.enemies[0].hp==hp,"Downed owner cannot deal orbital damage")
  h.hp=100;s._orbital_tick(1)
  check(s.enemies[0].hp<hp,"Orbital resumes after revive")
 print("ORBITAL checks=",checks," failures=",failures)
 quit(1 if failures else 0)
