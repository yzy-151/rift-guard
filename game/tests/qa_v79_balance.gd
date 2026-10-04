extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
var failures=0
var checks=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error(label)
 else: print("PASS "+label)
func setup():
 var s=Sim.new(324,true)
 var squad: Array[String]=["traveler","hero_02","hero_01"]
 s.reset_stage("stage_02",squad,324);s.start()
 s.enemies.clear();s.enemy_lookup.clear();s.terrain_features.clear()
 for h in s.heroes: h.deployed=true;h.pos=Vector2(400+h.id*35,360);h.target=h.pos
 return s
func advance(s,seconds: float) -> void:
 for i in ceili(seconds*60):
  s.elapsed+=1.0/60;s._pending_impact_tick(1.0/60);s._skill_effect_tick(1.0/60)
func enemy(s,pos: Vector2):
 var e=s.spawn_enemy(pos,"grunt")
 e.hp=100000;e.max_hp=100000;e.armor=0;e.shield=0
 return e
func run() -> void:
 var s=setup()
 s.heroes[0].element="electro"
 for i in 12: enemy(s,Vector2(650+i*22,360))
 s.activate_hero_skill(0,Vector2(650,360));advance(s,2.5)
 check(s.enemies.filter(func(e):return e.hp<100000).size()==9,"Electro chain exactly nine unique targets")
 s=setup();s.heroes[0].element="cryo"
 var e=enemy(s,Vector2(700,360))
 s.activate_hero_skill(0,e.pos);advance(s,0.7)
 check(e.frozen_timer>0,"Cryo Q actually freezes")
 s=setup();s.heroes[0].element="geo"
 e=enemy(s,Vector2(740,360))
 s.activate_hero_skill(0,Vector2(700,360));advance(s,0.7)
 check(s.geo_constructs.size()==1,"Geo Q leaves one construct")
 var rock=s.geo_constructs[0]
 check(rock.hp==1200+s.heroes[0].damage*6,"Rock HP scales with attack")
 var before=Vector2(e.pos)
 s._enemy_tick(0.1)
 check(Vector2(e.pos).distance_to(before)<0.1,"Ground monster stopped by rock")
 s.damage_construct(rock.id,rock.hp+1)
 s._enemy_tick(0.1)
 check(s.geo_constructs.is_empty(),"Destroyed rock removed")
 s=setup()
 for h in s.heroes:h.hp=100
 var speed=s.heroes[1].speed
 # V91 healing is an aimed cone; commit it toward the injured ally.
 s.activate_hero_skill(1,s.heroes[0].pos);advance(s,0.8)
 check(s.heroes[0].hp>100,"Sylphie Q heals allies")
 check(s.heroes[0].invulnerable_timer>0,"Sylphie Q protection applied")
 check(s.heroes[1].speed==speed,"Healing does not permanently stack movement")
 s=setup()
 var damage=s.heroes[0].damage
 s.heroes[2].energy=s.heroes[2].max_energy
 s.activate_hero_ultimate(2,s.heroes[2].pos);advance(s,0.8)
 check(s.heroes[0].damage>damage,"Columbia E grants attack")
 advance(s,26)
 check(is_equal_approx(s.heroes[0].damage,damage),"Columbia E expires without stat leak")
 for kind in ["support_crossfire","support_barrage","support_finale"]:
  s=setup();e=enemy(s,Vector2(700,360))
  s._trigger_support(kind,{"kind":kind,"power":100.0,"stacks":1,"radius":200.0,"lane_y":360.0,"target_point":Vector2(700,360)})
  check(is_equal_approx(100000.0-e.hp,300),kind+" triple damage")
 s=setup();e=enemy(s,Vector2(700,360))
 var far=enemy(s,Vector2(1150,560))
 s.fireball_level=1;s.meteor_timer=0;s._evolution_tick(0.1)
 check(s.pending_impacts.size()==1,"Meteor queued")
 advance(s,2)
 check(is_equal_approx(100000.0-e.hp,264),"Meteor triple damage")
 check(far.hp==100000,"Meteor excludes out-of-area target")
 check(not s.skill_effects.any(func(z):return z.kind=="burning_ground"),"Old fireball burning ground retired")
 print("V79 checks=",checks," failures=",failures)
 quit(1 if failures else 0)
func _initialize():call_deferred("run")
