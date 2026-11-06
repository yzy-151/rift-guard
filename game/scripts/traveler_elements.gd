extends RefCounted
# Shared gameplay data also drives the HUD, aiming preview, and visual timings.
const CONFIG = {
 "pyro_q":["焰锋三叠",15.0,900.0,5.0,125.0,2.0,"向落点方向依次斩出三段火焰，各造成一次威力伤害，可重复命中。"],
 "pyro_e":["天火连坠",58.0,320.0,1.8,230.0,3.8,"锁定落点，三颗流星间隔0.7秒砸落，每颗造成威力伤害。"],
 "hydro_q":["涌泉恩典",18.0,80.0,0.45,255.0,5.8,"泉眼持续5秒，每秒治疗范围内已上场存活队友等同威力的生命，并伤害敌人。"],
 "hydro_e":["溯海奔流",54.0,390.0,2.0,235.0,3.0,"向指定方向推进宽幅浪潮，每名敌人仅受一次伤害并被推开，沿途治疗队友威力的50%。"],
 "electro_q":["雷索逐星",14.0,175.0,1.1,290.0,1.9,"从落点附近一名敌人开始依次连锁最多9名敌人，每跳不超过190距离，同一敌人只命中一次。"],
 "electro_e":["三相雷狱",60.0,145.0,0.9,320.0,6.8,"三座导雷节点维持6秒，每0.75秒电击雷阵内所有敌人。"],
 "geo_q":["荒星",13.0,190.0,1.2,125.0,2.7,"落点召出荒星并伤敌，生命1200+600%攻击力，阻挡地面怪物，可被摧毁，最多3颗。"],
 "geo_e":["群山回响",62.0,260.0,1.6,350.0,3.6,"四次由近及远的地脉震波，各伤害命中敌人一次，并提供等同威力的全队共享护盾。"],
 "cryo_q":["霜羽穿心",17.0,150.0,0.95,165.0,2.0,"五枚冰枪依次汇聚落点，每枚造成威力伤害并冻结1.2秒。"],
 "cryo_e":["寂冬棱镜",57.0,140.0,0.8,315.0,5.0,"冰域每秒伤敌并减速，蓄积4秒后冰棱爆裂造成3倍威力伤害并冻结2秒。"],
 "anemo_e":["风眼升天",52.0,170.0,1.0,310.0,3.9,"风眼牵引范围内敌人，每0.6秒伤害一次，3秒后上升气爆造成2.5倍威力伤害。"]
}
static func supports(element: String, ultimate: bool) -> bool:
 return CONFIG.has(element+("_e" if ultimate else "_q"))
static func definition(element: String, ultimate: bool) -> Dictionary:
 var key=element+("_e" if ultimate else "_q")
 if not CONFIG.has(key): return {}
 var c=CONFIG[key]
 return {"kind":"traveler_"+key,"element":element,"name":c[0],"cooldown":c[1],"power":c[2],"attack_ratio":c[3],"radius":c[4],"duration":c[5],"description":c[6],"energy_cost":130,"targeting":"point","cast_range":550.0}
static func handles(kind: String) -> bool:
 return CONFIG.has(kind.trim_prefix("traveler_"))
static func target_point(sim,hero: Dictionary,target: Vector2) -> Vector2:
 return sim._clamp_ability_target(Vector2(hero.pos)+(target-Vector2(hero.pos)).limit_length(550.0))
static func start(sim,hero: Dictionary,ability: Dictionary,target: Vector2,power: float,radius: float) -> void:
 var key=str(ability.kind).trim_prefix("traveler_")
 var duration=float(ability.duration)
 var source=Vector2(hero.pos)
 var direction=(target-source).normalized() if target.distance_squared_to(source)>1 else Vector2.RIGHT
 var z={"kind":key,"traveler_zone":true,"hero_id":int(hero.id),"element":ability.element,"pos":target,"source":source,"direction":direction,"power":power,"radius":radius,"life":duration,"total":duration,"elapsed":0.0,"next":0.0,"step":0,"hit_ids":[],"heal_ids":[],"last":source,"cancelled":false}
 if key=="hydro_e": z.pos=source
 if key=="cryo_q": z.next=0.24
 if key=="geo_q":
  var construct_id=int(sim.next_construct_id)
  sim.next_construct_id+=1
  var hp=1200.0+float(hero.damage)*6.0
  sim.geo_constructs.append({"id":construct_id,"pos":target,"hp":hp,"max_hp":hp})
  var stars=0
  for construct: Dictionary in sim.geo_constructs:
   if not bool(construct.get("device",false)): stars+=1
  if stars>3:
   for index in sim.geo_constructs.size():
    if not bool(sim.geo_constructs[index].get("device",false)):
     sim.geo_constructs.remove_at(index)
     break
 if key=="geo_e":
  sim.crystal_shield+=power
  sim.events.append({"kind":"crystal_guard","pos":hero.pos,"value":ceili(power)})
 sim.skill_effects.append(z)
 sim.events.append({"kind":"traveler_fx_start","skill":key,"element":ability.element,"pos":target,"source":source,"radius":radius,"vfx_revision":"white_core_20261005"})
static func targets(sim,pos: Vector2,radius: float) -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 for e: Dictionary in sim.enemies:
  if e.hp>0 and sim._ability_target_visible(e.pos) and sim.is_in_ability_area(pos,e.pos,radius): result.append(e)
 return result
static func hit(sim,z: Dictionary,pos: Vector2,radius: float,scale: float=1.0,freeze: float=0.0) -> void:
 for e: Dictionary in targets(sim,pos,radius):
  sim.apply_hit(e,float(z.power)*scale,str(z.element),int(z.hero_id))
  if freeze>0 and e.hp>0: e.frozen_timer=maxf(float(e.get("frozen_timer",0)),freeze)
 sim.events.append({"kind":"traveler_fx_hit","skill":z.kind,"element":z.element,"pos":pos,"source":z.source,"radius":radius,"step":z.step,"delay":0.48 if str(z.kind).ends_with("_e") else 0.36,"vfx_revision":"white_core_20261005"})
static func heal(sim,z: Dictionary,pos: Vector2,amount: float,once: bool=false) -> void:
 for h: Dictionary in sim.heroes:
  if h.hp<=0 or not bool(h.deployed) or not sim.is_in_ability_area(pos,h.pos,float(z.radius)): continue
  if once and int(h.id) in z.heal_ids: continue
  var value=minf(float(h.max_hp)-float(h.hp),amount)
  h.hp+=value
  z.heal_ids.append(int(h.id))
  if value>0: sim.events.append({"kind":"heal","pos":h.pos,"value":ceili(value)})
static func tick(sim,z: Dictionary,dt: float) -> bool:
 z.life=maxf(0,float(z.life)-dt)
 z.elapsed=float(z.total)-float(z.life)
 var h: Dictionary=sim.heroes[int(z.hero_id)]
 if h.hp<=0 or not bool(h.deployed):
  z.cancelled=true
  z.life=minf(float(z.life),0.45)
 if bool(z.cancelled): return z.life>0
 var key=str(z.kind)
 if key=="hydro_e":
  z.pos=sim._clamp_ability_target(Vector2(z.source)+Vector2(z.direction)*minf(560,float(z.elapsed)*260))
  if z.elapsed<2.2:
   for e: Dictionary in targets(sim,z.pos,float(z.radius)):
    if int(e.id) in z.hit_ids: continue
    z.hit_ids.append(int(e.id))
    sim.apply_hit(e,float(z.power),"hydro",int(z.hero_id))
    if e.hp>0:
     sim._push_enemy_grid_cells(e,Vector2(z.source),1)
     e.slow_timer=maxf(float(e.slow_timer),1.0)
   heal(sim,z,z.pos,float(z.power)*0.5,true)
  return z.life>0
 if key=="anemo_e" and z.elapsed<3.0:
  for e: Dictionary in targets(sim,z.pos,float(z.radius)):
   e.pos=Vector2(e.pos).move_toward(z.pos,38.0*dt)
   e.slow_timer=maxf(float(e.slow_timer),0.4)
 if float(z.elapsed)+0.0001<float(z.next): return z.life>0
 var step=int(z.step)
 match key:
  "pyro_q":
   var count=3 if key=="pyro_q" else 4
   if step<count:
    var p=Vector2(z.source).lerp(Vector2(z.pos),float(step+1)/float(count))
    hit(sim,z,p,float(z.radius))
    z.next=float(z.next)+(0.25 if key=="pyro_q" else 0.34)
   else: z.next=9999
  "geo_q":
   if step==0: hit(sim,z,z.pos,float(z.radius))
   z.next=9999
  "pyro_e":
   if step<3:
    hit(sim,z,z.pos,float(z.radius))
    z.next=float(z.next)+0.7
   else: z.next=9999
  "cryo_q":
   if step<5:
    hit(sim,z,z.pos,float(z.radius),1.0,1.2)
    z.next=float(z.next)+0.24
   else: z.next=9999
  "electro_q":
   var candidates: Array[Dictionary]=targets(sim,z.pos,float(z.radius)) if step==0 else sim.enemies.duplicate()
   var best: Dictionary={}
   var distance=INF if step==0 else 190.0*190.0
   for e: Dictionary in candidates:
    if e.hp<=0 or int(e.id) in z.hit_ids or not sim._ability_target_visible(e.pos): continue
    var d=Vector2(e.pos).distance_squared_to(z.pos if step==0 else z.last)
    if d<distance: best=e;distance=d
   if best.is_empty() or step>=9: z.next=9999
   else:
    var from=Vector2(z.source) if step==0 else Vector2(z.last)
    z.last=Vector2(best.pos)
    z.hit_ids.append(int(best.id))
    sim.apply_hit(best,float(z.power),"electro",int(z.hero_id))
    sim.events.append({"kind":"traveler_fx_arc","skill":key,"element":"electro","pos":best.pos,"source":from,"radius":35.0,"delay":0.25,"vfx_revision":"white_core_20261005"})
    z.next=float(z.next)+0.12
  "hydro_q":
   if step<5:
    hit(sim,z,z.pos,float(z.radius))
    heal(sim,z,z.pos,float(z.power))
    z.next=float(z.next)+1.0
   else: z.next=9999
  "electro_e":
   if step<8:
    var points: Array[Vector2]=[]
    for e: Dictionary in targets(sim,z.pos,float(z.radius)):
     sim.apply_hit(e,float(z.power),"electro",int(z.hero_id))
     if points.size()<8: points.append(e.pos)
    sim.events.append({"kind":"traveler_fx_arc","skill":key,"element":"electro","pos":z.pos,"source":z.pos,"targets":points,"radius":z.radius,"step":step,"delay":0.25,"vfx_revision":"white_core_20261005"})
    z.next=float(z.next)+0.75
   else: z.next=9999
  "geo_e":
   if step<4:
    hit(sim,z,z.pos,float(z.radius)*float(step+1)/4.0)
    z.next=float(z.next)+0.55
   else: z.next=9999
  "cryo_e":
   if step<4:
    hit(sim,z,z.pos,float(z.radius),0.45)
    for e: Dictionary in targets(sim,z.pos,float(z.radius)): e.slow_timer=maxf(float(e.slow_timer),1.2)
    z.next=float(z.next)+1.0
   elif step==4:
    hit(sim,z,z.pos,float(z.radius),3.0,2.0)
    z.next=9999
  "anemo_e":
   if step<5:
    hit(sim,z,z.pos,float(z.radius),0.45)
    z.next=float(z.next)+0.6
   elif step==5:
    hit(sim,z,z.pos,float(z.radius),2.5)
    z.next=9999
 z.step=step+1
 return z.life>0
