extends RefCounted
# The orbit outline, weapon positions and strike sources share one projected radius.
static func point(c: Vector2,r: Vector2,a: float) -> Vector2:
 return c+Vector2(cos(a)*r.x,sin(a)*r.y)
static func draw(v,o: Dictionary,h: Dictionary) -> void:
 var c: Vector2=v.world_to_screen(h.pos)+v.ground_visual_offset()
 var r: Vector2=v.sim.ability_area_screen_radii(h.pos,float(o.radius))
 var fade=smoothstep(0,0.85,float(o.life))*smoothstep(0,0.35,float(o.get("age",1)))
 var blade=str(o.get("visual",""))=="blade"
 var color=Color("#ffd38e") if blade else Color("#b49aff")
 var count=mini(24,maxi(1,int(o.count)))
 var phase=float(o.get("phase",0))
 v._draw_dedicated_arc(c,r,0,TAU,Color(color,fade*0.22),1.4)
 for i in count:
  var a=phase+i*TAU/count
  var p=point(c,r,a)
  var tangent=Vector2(-sin(a)*r.x,cos(a)*r.y).normalized()
  var tail=PackedVector2Array()
  for j in 13:tail.append(point(c,r,a-float(j)*0.035))
  v.draw_polyline(tail,Color(color,fade*0.12),9,true)
  v.draw_polyline(tail,Color(color,fade*0.55),2,true)
  if blade:
   var side=tangent.orthogonal()
   var shape=PackedVector2Array([p+tangent*25,p+side*5,p-tangent*13,p-side*5])
   v.draw_colored_polygon(shape,Color(0.95,0.80,0.52,fade))
   v.draw_line(p-tangent*11,p+tangent*25,Color(1,1,0.91,fade),2,true)
   v.draw_line(p-tangent*14-side*8,p-tangent*14+side*8,Color(0.99,0.65,0.29,fade),3,true)
   v.draw_line(p-tangent*14,p-tangent*23,Color(0.50,0.30,0.16,fade),4,true)
  else:
   v.draw_circle(p,15,Color(color,fade*0.13))
   v.draw_circle(p,7,Color(color,fade*0.86))
   v.draw_circle(p+Vector2(-2,-2),3,Color(1,0.95,1,fade))
   v._draw_dedicated_arc(p,Vector2(12,8),-phase,PI*1.55,Color(color.lightened(0.4),fade),1.6)
   for k in 3:
    var q=p+Vector2.from_angle(k*TAU/3+phase)*17
    v.draw_line(q-tangent*2,q+tangent*2,Color(color,fade*0.8),2,true)
static func effect(v,e: Dictionary) -> void:
 var t=clampf(1-float(e.life)/float(e.total),0,1)
 var fade=1-smoothstep(0.35,1,t)
 var color=Color("#ffd38e") if str(e.get("visual",""))=="blade" else Color("#b49aff")
 var center: Vector2=v.world_to_screen(e.get("center",e.pos))+v.ground_visual_offset()
 var r: Vector2=v.sim.ability_area_screen_radii(e.get("center",e.pos),float(e.radius))
 if e.kind=="orbit_storm":
  for i in 3:
   var f=clampf(t*2.4-i*0.16,0.01,1)
   v._draw_dedicated_arc(center,r*f,0,TAU,Color(color,fade*(0.65-i*0.15)),4-i)
  return
 var source=point(center,r,float(e.angle))
 var target: Vector2=v.world_to_screen(e.pos)
 var p=source.lerp(target,minf(1,t*3.0))
 v.draw_line(source,p,Color(color,fade*0.16),7,true)
 v.draw_line(source,p,Color(color,fade*0.9),2,true)
 v.draw_circle(p,3,Color(1,0.97,0.85,fade))
 if t>0.3:
  for i in 4:
   var dir=Vector2.from_angle(i*TAU/4+PI/4)
   v.draw_line(target+dir*4,target+dir*(6+t*18),Color(color,fade),2,true)
