extends RefCounted
# Bounded per-enemy states. No extra per-frame full-neighbour scans.
const BUG_BLAST_RADIUS := 80.0
static func initialize(e: Dictionary) -> void:
 if e.kind=="armored": e.burrow_new=false
 if e.kind=="buffer": e.medic_timer=2.0+fposmod(float(e.id)*0.37,2.0)
static func begin_burrow(s,e: Dictionary) -> void:
 e.burrow_new=false
 var active=0
 for other in s.enemies:
  if other.hp>0 and float(other.get("burrow_timer",0))>0: active+=1
 if active>=2: return
 var options: Array=[]
 var route: Array=e.get("route_points",[])
 for p in route:
  if Vector2(p).x>450 and Vector2(p).x<1020: options.append(Vector2(p))
 if options.is_empty():
  var center: Vector2=s.active_view_rect.get_center() if s.endless_mode else Vector2(780,360)
  for i in 12:
   var raw=center+Vector2((i%4-1)*s.GRID_CELL_SIZE.x,(i/4-1)*s.GRID_CELL_SIZE.y)
   var cell=((raw-s.GRID_ORIGIN)/s.GRID_CELL_SIZE).floor()
   options.append(s.GRID_ORIGIN+(cell+Vector2.ONE*0.5)*s.GRID_CELL_SIZE)
 for offset in options.size():
  var p: Vector2=options[(int(e.id)+offset)%options.size()]
  if not s._movement_bounds().has_point(p) or p.x<300 or s._terrain_blocks(p,24): continue
  var occupied=false
  for h in s.heroes:
   if h.deployed and h.hp>0 and Vector2(h.pos).distance_squared_to(p)<150*150: occupied=true;break
  if occupied:continue
  for other in s.enemies:
   if other.id!=e.id and other.hp>0 and Vector2(other.pos).distance_squared_to(p)<65*65:occupied=true;break
  for rock in s.geo_constructs:
   if rock.hp>0 and Vector2(rock.pos).distance_squared_to(p)<65*65:occupied=true
  if occupied:continue
  e.pos=p;e.burrow_timer=1.85;e.attack_timer=1.0
  if not route.is_empty():
   var nearest=0
   for i in route.size():
    if p.distance_squared_to(route[i])<p.distance_squared_to(route[nearest]):nearest=i
   e.route_index=nearest
  s.projectile_neighbor_cache.clear()
  return
static func tick(s,e: Dictionary,dt: float) -> bool:
 if float(e.get("frozen_timer",0))>0:return true
 if e.kind in ["charger","hilichurl_brute"] and tick_committed_attack(s,e,dt):return true
 if bool(e.get("burrow_new",false)):begin_burrow(s,e)
 if float(e.get("burrow_timer",0))>0:
  e.burrow_timer=maxf(0,float(e.burrow_timer)-dt)
  e.attack_pending=false;e.attack_timer=0.8
  return true
 if e.kind=="buffer":
  e.medic_link=maxf(0,float(e.get("medic_link",0))-dt)
  e.medic_timer=float(e.get("medic_timer",4))-dt
  if e.medic_timer<=0 and e.frozen_timer<=0:
   e.medic_timer=4.0
   var best: Dictionary={}
   for other in s.enemies:
    if other.id==e.id or other.hp<=0 or other.hp>=other.max_hp or float(other.get("burrow_timer",0))>0:continue
    if Vector2(other.pos).distance_squared_to(e.pos)>220*220:continue
    if best.is_empty() or float(other.hp)/other.max_hp<float(best.hp)/best.max_hp:best=other
   if not best.is_empty():
    var amount=minf(best.max_hp-best.hp,minf(best.max_hp*0.10,e.max_hp*0.25)+16)
    best.hp+=amount;e.medic_target=best.id;e.medic_link=0.8
    s.events.append({"kind":"enemy_heal","pos":best.pos,"value":ceili(amount)})
 if e.kind=="rift_bat" and float(e.get("retreat_timer",0))>0:
  e.retreat_timer=maxf(0,float(e.retreat_timer)-dt)
  if e.frozen_timer<=0:
   e.pos=Vector2(e.pos).move_toward(e.retreat_pos,float(e.speed)*1.45*dt*(0.7 if e.slow_timer>0 else 1.0))
  return true
 return false

static func tick_committed_attack(s,e: Dictionary,dt: float) -> bool:
 e.tactic_cooldown=maxf(0.0,float(e.get("tactic_cooldown",2.0))-dt)
 if float(e.get("dash_windup",0.0))>0.0:
  e.dash_windup=maxf(0.0,float(e.dash_windup)-dt)
  if float(e.dash_windup)<=0.0:e.dash_time=0.66;e.dash_hits=[]
  return true
 if float(e.get("dash_time",0.0))>0.0:
  var step=minf(dt,float(e.dash_time))
  e.dash_time=maxf(0.0,float(e.dash_time)-dt)
  var start=Vector2(e.pos)
  var finish=start+Vector2(e.dash_direction)*440.0*step*(0.7 if float(e.get("slow_timer",0))>0 else 1.0)
  if s.terrain_line_blocked(start,finish,16.0):e.dash_time=0.0;return true
  e.pos=finish
  for hero: Dictionary in s.heroes:
   if hero.hp<=0 or not bool(hero.deployed) or int(hero.id) in e.dash_hits:continue
   if Geometry2D.get_closest_point_to_segment(hero.pos,start,finish).distance_to(hero.pos)<=34.0:
    e.dash_hits.append(int(hero.id))
    s.damage_hero(int(hero.id),float(e.damage)*1.15,{"source_name":"野猪骑士","source_skill":"锁向冲锋"})
  return true
 if float(e.get("spin_windup",0.0))>0:
  e.spin_windup=maxf(0,float(e.spin_windup)-dt)
  if float(e.spin_windup)<=0:e.spin_time=1.8;e.spin_pulse=0.0
  return true
 if float(e.get("spin_time",0.0))>0:
  e.spin_time=maxf(0,float(e.spin_time)-dt)
  e.spin_pulse=float(e.get("spin_pulse",0))-dt
  if float(e.spin_pulse)<=0:
   e.spin_pulse+=0.55
   for hero: Dictionary in s.heroes:
    if hero.hp>0 and bool(hero.deployed) and s.is_in_ability_area(e.pos,hero.pos,125.0):
     s.damage_hero(int(hero.id),float(e.damage)*0.40,{"source_name":"丘丘暴徒","source_skill":"旋斧"})
   s.events.append({"kind":"enemy_spin","pos":e.pos,"radius":125.0,"duration":0.55,"enemy_id":e.id})
  return true
 if float(e.tactic_cooldown)>0.0 or bool(e.get("attack_pending",false)):return false
 var target: Dictionary=s._nearest_live_hero(e.pos) if s.endless_mode or Array(e.get("route_points",[])).size()<2 else s.EnemyMelee.target(s,e)
 if target.is_empty():return false
 var distance=Vector2(e.pos).distance_to(target.pos)
 if str(e.kind)=="charger" and distance<=300.0 and distance>=80.0 and not s.terrain_line_blocked(e.pos,target.pos,16.0):
  e.tactic_cooldown=6.0;e.dash_windup=0.72;e.dash_direction=(Vector2(target.pos)-Vector2(e.pos)).normalized()
  e.dash_target=Vector2(e.pos)+Vector2(e.dash_direction)*290.0
  e.attack_pending=false
  s.events.append({"kind":"enemy_dash_warning","pos":e.pos,"target":e.dash_target,"width":68.0,"duration":0.72,"enemy_id":e.id})
  return true
 if str(e.kind)=="hilichurl_brute" and distance<=160.0 and distance>=s.EnemyMelee.distance(e)-2.0:
  e.tactic_cooldown=7.0;e.spin_windup=0.9;e.attack_pending=false
  s.events.append({"kind":"enemy_warning","pos":e.pos,"source":e.pos,"radius":125.0,"life":0.9,"duration":0.9,"boss":false,"name":"旋斧蓄力","enemy_id":e.id})
  return true
 return false
static func bat_destination(s,e: Dictionary,fallback: Vector2) -> Vector2:
 if not s.endless_mode:return fallback
 if e.kind!="rift_bat":return fallback
 var target: Dictionary=s._nearest_live_hero(e.pos)
 if target.is_empty() or Vector2(e.pos).distance_squared_to(target.pos)>650*650:return fallback
 return target.pos
static func after_attack(s,e: Dictionary) -> void:
 if e.kind!="rift_bat":return
 var direction=(Vector2(e.pos)-Vector2(e.warning_pos)).normalized()
 if direction.length_squared()<0.01:direction=Vector2.RIGHT
 var side=direction.orthogonal()*float(int(e.id)%3-1)*36
 var bounds: Rect2=s._movement_bounds()
 var p=Vector2(e.pos)+direction*135+side
 e.retreat_pos=Vector2(clampf(p.x,bounds.position.x,bounds.end.x),clampf(p.y,bounds.position.y,bounds.end.y))
 e.retreat_timer=1.25;e.attack_timer=maxf(e.attack_timer,1.7)
static func on_death(s,e: Dictionary) -> void:
 if e.kind!="originium_bug":return
 s.pending_impacts.append({"kind":"bug_blast","pos":e.pos,"life":1.0,"radius":BUG_BLAST_RADIUS,"damage":float(e.damage)*1.5})
static func explode(s,impact: Dictionary) -> void:
 for h in s.heroes:
  if h.hp>0 and h.deployed and s.is_in_ability_area(impact.pos,h.pos,float(impact.radius)):s.damage_hero(h.id,float(impact.damage),{"source_name":"源石虫","source_skill":"死亡爆炸"})
 s.events.append({"kind":"enemy_volatile","pos":impact.pos,"value":ceili(impact.damage),"bug_blast":true,"radius":impact.radius,"duration":0.85})
static func draw_ground(v) -> void:
 for impact in v.sim.pending_impacts:
  if impact.kind!="bug_blast":continue
  var c: Vector2=v.world_to_screen(impact.pos)+v.ground_visual_offset()
  var r: Vector2=v.sim.ability_area_screen_radii(impact.pos,impact.radius)
  var t=clampf(1.0-float(impact.life),0,1)
  var pulse=0.5+0.5*sin(v.clock*(10+t*14))
  var outline=v._ability_ellipse_points(c,r)
  var fill=outline.duplicate();fill.resize(fill.size()-1)
  v.draw_colored_polygon(fill,Color(0.92,0.025,0.07,0.055+pulse*0.035))
  v.draw_polyline(outline,Color(1,0.16,0.26,0.68+pulse*0.20),1.8,true)
  # One honest blast footprint; urgency stays at the source, not wheel spokes.
  var tip=c+Vector2(0,-20-t*8)
  v.draw_line(tip+Vector2(-4,0),tip+Vector2(-4,9),Color(1,0.76,0.66),2.8,true)
  v.draw_circle(tip+Vector2(-4,14),1.5,Color(1,0.76,0.66))
  var bar=Rect2(c+Vector2(-15,10),Vector2(30,3))
  v.draw_rect(bar,Color(0.16,0.02,0.04,0.85))
  v.draw_rect(Rect2(bar.position,Vector2(bar.size.x*(1-t),3)),Color(1,0.26,0.31))

 for e in v.sim.enemies:
  if e.hp<=0:continue
  if float(e.get("burrow_timer",0))>0:
   var c: Vector2=v.world_to_screen(e.pos)
   preload("res://scripts/impact_flash_vfx.gd").rift(v,c+Vector2(0,-25),26,Color("#c2a3ff"),v.clock,0.8,-1.0)
  if float(e.get("medic_link",0))>0:
   var target: Dictionary=v.sim.find_enemy(int(e.get("medic_target",-1)))
   if target.is_empty() or target.hp<=0:continue
   var a: Vector2=v.world_to_screen(e.pos)+Vector2(0,-25)
   var b: Vector2=v.world_to_screen(target.pos)+Vector2(0,-20)
   var alpha=minf(1,float(e.medic_link)/0.25)
   v.draw_line(a,b,Color(0.3,1,0.58,alpha*0.65),3,true)
   for i in 3:v.draw_circle(a.lerp(b,fposmod(v.clock*1.8+i/3.0,1)),3,Color(0.8,1,0.85,alpha))

static func draw_blast(v,e: Dictionary) -> void:
 var age=maxf(0.0,float(e.total)-float(e.life))
 if age>0.48:return
 var center:Vector2=v.world_to_screen(e.pos)+v.ground_visual_offset()
 var seed_value:int=int(e.get("enemy_id",e.get("seed",17)))
 var radii:Vector2=v.sim.ability_area_screen_radii(e.pos,float(e.get("radius",BUG_BLAST_RADIUS)))
 # Painted clouds fit the same projected footprint as the unchanged warning/damage.
 preload("res://scripts/cartoon_explosion_vfx.gd").burst(v,center,age,1.0,seed_value,v.reduced_effects,radii/80.0)

# Keep a defeated shielded unit in the simulation, but HP zero excludes all targeting.
static var revival_sequences = preload("res://scripts/enemy_sequence_library.gd").new()
static func begin_revival(s,e: Dictionary) -> bool:
 if e.kind!="shielded" or bool(e.get("revive_used",false)):return false
 e.revive_used=true;e.revive_pending=true;e.revive_elapsed=0.0
 e.revive_duration=revival_sequences.duration("shielded","down")+4.0
 e.hp=0.0;e.shield=0.0;e.attack_pending=false;e.special_pending=false
 s.projectile_neighbor_cache.clear()
 return true
static func tick_revival(s,e: Dictionary,dt: float) -> bool:
 if not bool(e.get("revive_pending",false)):return false
 e.revive_elapsed=float(e.revive_elapsed)+dt
 if e.revive_elapsed>=float(e.revive_duration):
  e.revive_pending=false;e.hp=e.max_hp
  e.attack_timer=0.8;e.frozen_timer=0.0;e.slow_timer=0.0
  e.aura="";e.aura_timer=0.0;e.reaction_timer=0.0;e.flash=0.2
  s.enemy_lookup[int(e.id)]=e
  s.projectile_neighbor_cache.clear()
 return true
