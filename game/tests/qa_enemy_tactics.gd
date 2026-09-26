extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
var checks=0
var failures=0
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;push_error(label)
 else:print("PASS "+label)
func setup():
 var s=Sim.new(825,true)
 var squad: Array[String]=["traveler"]
 s.reset_stage("stage_02",squad,825);s.start()
 s.enemies.clear();s.enemy_lookup.clear();s.terrain_features.clear()
 s.heroes[0].deployed=true;s.heroes[0].pos=Vector2(600,360);s.heroes[0].armor=0;s.heroes[0].hp=720
 return s
func run():
 var s=setup()
 var h=s.heroes[0]
 var bug=s.spawn_enemy(h.pos,"originium_bug");bug.armor=0;bug.shield=0;bug.affixes=["volatile"]
 var hp=h.hp
 s.apply_hit(bug,100000,"",0)
 check(h.hp==hp,"Bug death does not damage before warning")
 check(s.pending_impacts.filter(func(p):return p.kind=="bug_blast").size()==1,"One delayed blast queued")
 s._pending_impact_tick(0.9);check(h.hp==hp,"Full pre-blast dodge window")
 s._pending_impact_tick(0.11);check(h.hp<hp,"Blast damages hero inside ellipse")
 s=setup();h=s.heroes[0];bug=s.spawn_enemy(h.pos,"originium_bug");bug.armor=0;bug.shield=0
 s.apply_hit(bug,100000,"",0);h.pos+=Vector2(400,0);hp=h.hp;s._pending_impact_tick(1.1)
 check(h.hp==hp,"Moving away avoids blast")
 s=setup();var shaman=s.spawn_enemy(Vector2(800,360),"buffer")
 var ally=s.spawn_enemy(Vector2(850,360),"grunt");ally.hp=20
 var other=s.spawn_enemy(Vector2(840,360),"grunt");other.hp=other.max_hp*0.8
 shaman.medic_timer=0
 var before=other.hp
 Sim.EnemyTactics.tick(s,shaman,0.01)
 check(ally.hp>20 and other.hp==before,"Shaman heals only most injured ally")
 check(shaman.medic_target==ally.id and shaman.medic_link>0,"Heal exposes source-target link")
 var healed=ally.hp;Sim.EnemyTactics.tick(s,shaman,0.5)
 check(ally.hp==healed,"Healing respects cooldown")
 s=setup();var bat=s.spawn_enemy(Vector2(700,360),"rift_bat")
 check(Sim.EnemyTactics.bat_destination(s,bat,Vector2.ZERO)==s.heroes[0].pos,"Bat seeks nearest live hero")
 bat.warning_pos=s.heroes[0].pos;Sim.EnemyTactics.after_attack(s,bat)
 var distance=Vector2(bat.pos).distance_to(s.heroes[0].pos)
 Sim.EnemyTactics.tick(s,bat,0.5)
 check(Vector2(bat.pos).distance_to(s.heroes[0].pos)>distance,"Bat retreats after strike")
 bat.frozen_timer=2;var pos=Vector2(bat.pos);Sim.EnemyTactics.tick(s,bat,0.1)
 check(bat.pos==pos,"Frozen bat cannot retreat")
 s=setup();check(s._try_spawn_stage_event({"enemy_id":"rift_bat","route_id":"main","sequence":0}),"Bat wave accepted")
 check(s.enemies.size()==3 and s.enemies.all(func(e):return e.kind=="rift_bat"),"Bat wave is three actual bats")
 s=setup()
 for i in 4:s.spawn_enemy(Vector2(1100,200+i*80),"armored")
 s._enemy_tick(0.01)
 var burrows=s.enemies.filter(func(e):return float(e.get("burrow_timer",0))>0)
 check(burrows.size()==2,"At most two burrowing zombies")
 for e in burrows:
  check(not s._terrain_blocks(e.pos,24) and Vector2(e.pos).distance_to(s.heroes[0].pos)>=150,"Burrow avoids walls and hero")
  pos=e.pos;var health=e.hp
  s.apply_hit(e,10000,"",0);Sim.EnemyTactics.tick(s,e,0.1)
  check(e.hp==health and e.pos==pos and not e.attack_pending,"Underground zombie neither moves nor fights")
  Sim.EnemyTactics.tick(s,e,2)
  check(e.burrow_timer==0,"Zombie finishes emergence")
 check(s.enemies.size()==4,"Burrowing adds no extra monsters")
 print("ENEMY TACTICS checks=",checks," failures=",failures)
 quit(1 if failures else 0)
func _initialize():call_deferred("run")
