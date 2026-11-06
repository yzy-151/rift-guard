extends RefCounted
const SkillVfx = preload("res://scripts/traveler_skill_vfx_20261005.gd")
const COLORS={"pyro":Color("#ff8052"),"hydro":Color("#67cfff"),"electro":Color("#caa0ff"),"geo":Color("#e9bf67"),"cryo":Color("#b8efff"),"anemo":Color("#80f0c4")}
static func ring(v,c: Vector2,r: Vector2,color: Color,alpha: float,width: float=2.0) -> void:
 if alpha<0.005 or minf(r.x,r.y)<0.1: return
 v._draw_dedicated_arc(c,r,0,TAU,Color(color,clampf(alpha,0,1)),width)
static func crystal(v,p: Vector2,size: float,color: Color,alpha: float,angle: float=0.0) -> void:
 if size<0.2 or alpha<0.005: return
 var shape=PackedVector2Array([Vector2(0,-1),Vector2(0.28,-0.28),Vector2(0.2,0.08),Vector2(0,0.20),Vector2(-0.24,0.03),Vector2(-0.30,-0.33)])
 for i in shape.size(): shape[i]=p+shape[i].rotated(angle)*size
 v.draw_colored_polygon(shape,Color(color,alpha*0.65))
 var edge=shape.duplicate();edge.append(edge[0])
 v.draw_polyline(edge,Color(color.lightened(0.6),alpha),2.0,true)
 v.draw_line(p+Vector2(0,-size).rotated(angle),p+Vector2(0,size*0.2).rotated(angle),Color(Color.WHITE,alpha*0.7),1.5,true)
static func bolt(v,a: Vector2,b: Vector2,color: Color,alpha: float,phase: float=0.0) -> void:
 var d=b-a
 var normal=d.orthogonal().normalized()
 var line=PackedVector2Array()
 for i in 9:
  var t=float(i)/8.0
  line.append(a+d*t+normal*sin(i*3.7+phase)*sin(t*PI)*13.0)
 v.draw_polyline(line,Color(color,alpha*0.14),11.0,true)
 v.draw_polyline(line,Color(color,alpha*0.8),4.5,true)
 v.draw_polyline(line,Color(color.lightened(0.8),alpha),1.5,true)
static func meteor(v,p: Vector2,height: float,color: Color,alpha: float) -> void:
 var head=p+Vector2(-height*0.6,-height)
 var tail=head+Vector2(-56,-92)
 v.draw_line(tail,head,Color(color,alpha*0.15),28.0,true)
 v.draw_line(tail,head,Color(color,alpha*0.65),11.0,true)
 v.draw_circle(head,12.0,Color(color,alpha*0.82))
 v.draw_circle(head,6.0,Color("#fff3c9",alpha))
static func preview(v,h: Dictionary,data: Dictionary,target: Vector2) -> void:
 var point=v.sim.TravelerElements.target_point(v.sim,h,target)
 var color=COLORS[data.element]
 var radius=float(data.radius)*(1.0+v.sim.skill_area_bonus)
 var key=str(data.kind).trim_prefix("traveler_")
 if key.ends_with("_e") and v.sim.run_state.equipped_relics.has("relic_resonant_core"): radius*=1.2
 if key=="pyro_q":
  var count=3 if key=="pyro_q" else 4
  for i in count:
   v._draw_skill_area_ellipse(Vector2(h.pos).lerp(point,float(i+1)/count),radius,color,0.85)
 elif key=="hydro_e":
  var direction=(point-Vector2(h.pos)).normalized()
  for i in 4:
   v._draw_skill_area_ellipse(v.sim._clamp_ability_target(Vector2(h.pos)+direction*float(i)*180),radius,color,0.7)
 else: v._draw_skill_area_ellipse(point,radius,color,0.95)
 v.draw_dashed_line(v.world_to_screen(h.pos),v.world_to_screen(point),Color(color,0.5),1.5,9,true)
 v.caption(v.world_to_screen(point)+Vector2(-55,-75),str(data.name),color,15)
static func event(v,e: Dictionary) -> void:
 SkillVfx.event(v,e)
static func zone(v,z: Dictionary) -> void:
 SkillVfx.zone(v,z)
static func legacy_event(v,e: Dictionary) -> bool:
 return SkillVfx.legacy_event(v,e)
static func construct(v,z: Dictionary) -> void:
 SkillVfx.construct(v,z)
