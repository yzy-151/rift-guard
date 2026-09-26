extends RefCounted
# Bounded per-enemy states. No extra per-frame full-neighbour scans.
static func initialize(e: Dictionary) -> void:
 if e.kind=="armored": e.burrow_new=true
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
static func bat_destination(s,e: Dictionary,fallback: Vector2) -> Vector2:
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
 s.pending_impacts.append({"kind":"bug_blast","pos":e.pos,"life":1.0,"radius":125.0,"damage":float(e.damage)*1.5})
static func explode(s,impact: Dictionary) -> void:
 for h in s.heroes:
  if h.hp>0 and h.deployed and s.is_in_ability_area(impact.pos,h.pos,float(impact.radius)):s.damage_hero(h.id,float(impact.damage),{"source_name":"源石虫","source_skill":"死亡爆炸"})
 s.events.append({"kind":"enemy_volatile","pos":impact.pos,"value":ceili(impact.damage),"bug_blast":true,"radius":impact.radius,"duration":0.85})
static func draw_ground(v) -> void:
 for impact in v.sim.pending_impacts:
  if impact.kind!="bug_blast":continue
  var c: Vector2=v.world_to_screen(impact.pos)+Vector2(0,8)
  var r: Vector2=v.sim.ability_area_screen_radii(impact.pos,impact.radius)
  var t=clampf(1.0-float(impact.life),0,1)
  var pulse=0.5+0.5*sin(v.clock*(12+t*18))
  var outline=v._ability_ellipse_points(c,r)
  var fill=outline.duplicate();fill.resize(fill.size()-1)
  v.draw_colored_polygon(fill,Color(0.92,0.025,0.07,0.15+pulse*0.12))
  v.draw_polyline(outline,Color(1,0.10,0.18,0.95),3.5,true)
  v._draw_dedicated_arc(c,r*(1-t*0.88),0,TAU,Color(1,0.38,0.38,0.72),2)
  for i in 12:
   var angle=i*TAU/12
   var a=c+Vector2(cos(angle)*r.x,sin(angle)*r.y)
   v.draw_line(a,a.lerp(c,0.13),Color(1,0.35,0.35,0.9),3,true)
  v.draw_polyline(PackedVector2Array([c+Vector2(0,-24),c+Vector2(16,4),c+Vector2(-16,4),c+Vector2(0,-24)]),Color(1,0.6,0.6),2.5,true)
  v.caption(c+Vector2(-4,-1),"!",Color(1,0.9,0.9),20)

 for e in v.sim.enemies:
  if e.hp<=0:continue
  if float(e.get("burrow_timer",0))>0:
   var c: Vector2=v.world_to_screen(e.pos)
   v._draw_dedicated_arc(c,Vector2(28,10),0,TAU,Color(0.75,0.47,0.3,0.9),3)
   for i in 5:
    var d=Vector2(cos(i*TAU/5)*38,sin(i*TAU/5)*14)
    v.draw_polyline(PackedVector2Array([c+d*0.2,c+d*0.55+Vector2(4,-3),c+d]),Color(0.94,0.61,0.3),2,true)
  if float(e.get("medic_link",0))>0:
   var target: Dictionary=v.sim.find_enemy(int(e.get("medic_target",-1)))
   if target.is_empty() or target.hp<=0:continue
   var a: Vector2=v.world_to_screen(e.pos)+Vector2(0,-25)
   var b: Vector2=v.world_to_screen(target.pos)+Vector2(0,-20)
   var alpha=minf(1,float(e.medic_link)/0.25)
   v.draw_line(a,b,Color(0.3,1,0.58,alpha*0.65),3,true)
   for i in 3:v.draw_circle(a.lerp(b,fposmod(v.clock*1.8+i/3.0,1)),3,Color(0.8,1,0.85,alpha))

static func draw_blast(v,e: Dictionary) -> void:
 var t=clampf(1-float(e.life)/float(e.total),0,1)
 var fade=1-smoothstep(0.25,1,t)
 var c: Vector2=v.world_to_screen(e.pos)+Vector2(0,8)
 var r: Vector2=v.sim.ability_area_screen_radii(e.pos,float(e.radius))
 var outline=v._ability_ellipse_points(c,r*maxf(0.05,minf(1,t*4)))
 var fill=outline.duplicate();fill.resize(fill.size()-1)
 v.draw_colored_polygon(fill,Color(1,0.08,0.13,fade*0.25))
 v.draw_polyline(outline,Color(1,0.22,0.24,fade),6*(1-t)+1,true)
 for i in 12:
  var angle=i*TAU/12
  var d=Vector2(cos(angle)*r.x,sin(angle)*r.y)
  var p=c+d*minf(0.95,t*2.8)
  v.draw_line(p-d*0.13,p,Color(1,0.58,0.29,fade),3,true)
 if t<0.3:v.draw_circle(c,18*(1-t/0.3),Color(1,0.9,0.7,(1-t/0.3)*0.9))

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
