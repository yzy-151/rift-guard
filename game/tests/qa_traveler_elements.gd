extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
var failures:=0
var checks:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error(label)
 else: print("PASS "+label)
func advance(sim,seconds: float) -> void:
 for i in ceili(seconds*60):
  sim.elapsed+=1.0/60
  sim._pending_impact_tick(1.0/60)
  sim._skill_effect_tick(1.0/60)
func run() -> void:
 for key in Sim.TravelerElements.CONFIG:
  var element=str(key).get_slice("_",0)
  var ultimate=str(key).ends_with("_e")
  var sim=Sim.new(271,true)
  var squad: Array[String]=["traveler","hero_03"]
  sim.reset_stage("stage_02",squad,271)
  sim.start()
  sim.enemies.clear();sim.enemy_lookup.clear();sim.terrain_features.clear()
  var h: Dictionary=sim.heroes[0]
  h.element=element;h.pos=Vector2(350,360);h.target=h.pos;h.deployed=true;h.energy=h.max_energy
  var ally: Dictionary=sim.heroes[1]
  ally.pos=Vector2(680,360);ally.deployed=true;ally.hp=100
  var near: Dictionary=sim.spawn_enemy(Vector2(720,360),"grunt")
  near.hp=100000;near.max_hp=100000;near.armor=0;near.shield=0
  var far: Dictionary=sim.spawn_enemy(Vector2(1180,570),"grunt")
  far.hp=100000;far.max_hp=100000;far.armor=0;far.shield=0
  var data: Dictionary=sim.hero_ability(0,ultimate)
  check(str(data.kind)=="traveler_"+key,key+" dynamic definition")
  var accepted=sim.activate_hero_ultimate(0,Vector2(720,360)) if ultimate else sim.activate_hero_skill(0,Vector2(720,360))
  check(accepted,key+" cast accepted")
  var repeated=sim.activate_hero_ultimate(0,Vector2(720,360)) if ultimate else sim.activate_hero_skill(0,Vector2(720,360))
  check(not repeated,key+" cooldown prevents duplicate cast")
  if ultimate: check(h.ultimate_cooldown>=40,key+" ultimate minimum cooldown")
  advance(sim,float(data.duration)+1.5)
  check(near.hp<100000,key+" damages intended target")
  check(far.hp==100000,key+" excludes distant enemy")
  check(sim.skill_effects.is_empty(),key+" no lingering damaging zones")
  if key in ["pyro_e","cryo_q"]:
   var power=(float(data.power)+float(h.damage)*float(data.attack_ratio))*(1+sim.skill_power_bonus)
   check(is_equal_approx(100000.0-float(near.hp),power*(5 if key=="cryo_q" else 3)),key+" exact hit count")
  if element=="hydro":check(ally.hp>100,"Hydro restores allied HP")
  if key=="geo_e":check(sim.crystal_shield>0,"Geo shared shield")
  if key=="anemo_e":check(near.pos.distance_to(Vector2(720,360))<1,"Anemo center target stable")
 var sim=Sim.new(111,true)
 var squad: Array[String]=["traveler"]
 sim.reset_stage("stage_02",squad,111);sim.start()
 sim.heroes[0].element="anemo";sim.heroes[0].deployed=true
 sim.activate_hero_skill(0,Vector2(700,360));advance(sim,0.5)
 check(sim.skill_effects.any(func(z: Dictionary)->bool:return z.kind=="anemo_tornado"),"Wind Q retains existing tornado implementation")
 check(not sim.skill_effects.any(func(z: Dictionary)->bool:return bool(z.get("traveler_zone",false))),"Wind Q does not use replacement module")
 print("TRAVELER ELEMENTS checks=",checks," failures=",failures)
 quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
