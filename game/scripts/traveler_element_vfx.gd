extends RefCounted
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
 var key=str(e.get("skill",""))
 var color=COLORS.get(str(e.get("element","")),Color.WHITE)
 var t=clampf(1-float(e.life)/float(e.total),0,1)
 var alpha=1-smoothstep(0.15,1.0,t)
 var c=v.world_to_screen(e.pos)+Vector2(0,8)
 var r=v.sim.ability_area_screen_radii(e.pos,float(e.get("radius",160)))
 if e.kind=="traveler_fx_cast":
  ring(v,c,r*(0.86+t*0.14),color,sin(t*PI)*0.7,1.8)
  if key=="pyro_e": meteor(v,c,180*(1-t),color,0.25+0.75*t)
  elif key=="cryo_q":
   for i in 5:
    var p=v.world_to_screen(e.source)+Vector2((i-2)*25,-50)
    crystal(v,p.lerp(c,t*0.5),25,color,t)
  return
 if e.kind=="traveler_fx_arc":
  if e.has("targets"):
   var index=0
   for point in e.targets:
    var angle=float((index+int(e.get("step",0)))%3)*TAU/3-PI/2
    var source=c+Vector2(cos(angle)*r.x,sin(angle)*r.y)-Vector2(0,55)
    bolt(v,source,v.world_to_screen(point),color,alpha,index)
    index+=1
  else: bolt(v,v.world_to_screen(e.source),c,color,alpha)
  ring(v,c,Vector2(23,9)*(0.4+t),color,alpha,2)
  return
 ring(v,c,r*maxf(0.06,minf(1,t*2.8)),color,alpha*0.9,3.5)
 match key:
  "pyro_q":
   for i in 3:
    var arc=PackedVector2Array()
    for j in 22:
     var a=-PI+float(j)/21*PI*1.3+t*2
     arc.append(c+Vector2(cos(a)*r.x,sin(a)*r.y)*(0.5+float(i)*0.2))
    v.draw_polyline(arc,Color(color,alpha*0.16),12,true)
    v.draw_polyline(arc,Color(color.lightened(i*0.24),alpha),3.5,true)
  "pyro_e":
   for i in 14:
    var a=float(i)*TAU/14
    var d=Vector2(cos(a)*r.x,sin(a)*r.y)
    var p=c+d*minf(1,t*2.2)-Vector2(0,sin(t*PI)*float(15+i%4*12))
    v.draw_line(p,p-Vector2(4,14)*(1-t),Color(color.lightened(0.4),alpha),3,true)
   v.draw_circle(c-Vector2(0,12),25*(1-t),Color("#ffe5b5",alpha*0.32))
  "geo_q","geo_e":
   var count=5 if key=="geo_q" else 10
   for i in count:
    var a=float(i)*TAU/count
    var p=c+Vector2(cos(a)*r.x,sin(a)*r.y)*(0.35+0.45*t)
    crystal(v,p,(32+i%3*14)*sin(minf(1,t*3)*PI/2),color,alpha)
    v.draw_line(c,p,Color(color,alpha*0.5),2,true)
   ring(v,c,r*(0.3+t*0.7),color.lightened(0.7),alpha,5)
  "cryo_q":
   crystal(v,c,38*(1-t),color,alpha)
   for i in 6:
    var a=i*TAU/6.0
    v.draw_line(c,c+Vector2(cos(a)*r.x,sin(a)*r.y)*t,Color(color,alpha),1.6,true)
  "cryo_e":
   if int(e.get("step",0))>=4:
    for i in 16:
     var a=float(i)*TAU/16
     var p=c+Vector2(cos(a)*r.x,sin(a)*r.y)*t
     crystal(v,p,30*(1-t),color,alpha,a+PI/2)
  "anemo_e":
   if int(e.get("step",0))>=5:
    for i in 5:
     ring(v,c+Vector2(0,-t*100-i*13),r*(0.9-i*0.12)*(0.7+t*0.3),color,alpha*(1-i*0.12),3)
  "hydro_q":
   ring(v,c,r*(0.2+t*0.8),color.lightened(0.5),alpha*0.65,3)
static func zone(v,z: Dictionary) -> void:
 var key=str(z.kind)
 var color=COLORS[z.element]
 var alpha=minf(1,float(z.elapsed)/0.24)*minf(1,float(z.life)/0.75)
 if bool(z.get("cancelled",false)): alpha=minf(alpha,float(z.life)/0.45)
 var c=v.world_to_screen(z.pos)+Vector2(0,8)
 var r=v.sim.ability_area_screen_radii(z.pos,float(z.radius))
 var time=float(z.elapsed)
 if key=="cryo_q":
  if int(z.step)<5:
   var origin=v.world_to_screen(z.source)+Vector2((int(z.step)-2)*25,-45)
   var progress=clampf((time-float(z.step)*0.24)/0.24,0,1)
   var p=origin.lerp(c,progress)
   v.draw_line(origin.lerp(c,maxf(0,progress-0.18)),p,Color(color,alpha*0.8),3,true)
   crystal(v,p,38,color,alpha,(c-origin).angle()+PI/2)
  return
 if key in ["pyro_q","geo_q","electro_q"]: return
 if key=="pyro_e":
  if time<1.4:
   meteor(v,c,160*(1-fposmod(time,0.7)/0.7),color,alpha)
  return
 if key=="geo_e": return
 ring(v,c,r,color,alpha*0.45,1.7)
 match key:
  "hydro_q":
   for i in 6:
    var a=i*TAU/6.0+time*0.35
    var end=c+Vector2(cos(a)*r.x,sin(a)*r.y)*0.6
    var arc=PackedVector2Array()
    for j in 16:
     var t=float(j)/15
     arc.append(c.lerp(end,t)-Vector2(0,sin(t*PI)*45))
    v.draw_polyline(arc,Color(color,alpha*0.4),2,true)
    var bead=arc[int(fposmod(time*0.8+i*0.13,1)*15)]
    v.draw_circle(bead,3,Color(color.lightened(0.6),alpha))
   for i in 3: ring(v,c,r*(0.2+fposmod(time*0.5+i/3.0,1)*0.8),color,alpha*0.4)
  "hydro_e":
   for layer in 4:
    var pts=PackedVector2Array()
    for j in 25:
     var a=-PI+float(j)/24*PI
     pts.append(c+Vector2(cos(a)*r.x,sin(a)*r.y)-Vector2(0,sin(float(j)/24*PI)*(28+layer*9)))
    v.draw_polyline(pts,Color(color,alpha*(0.25+layer*0.15)),9-layer*1.7,true)
   for i in 12:
    var a=i*TAU/12+time
    var p=c+Vector2(cos(a)*r.x,sin(a)*r.y)
    v.draw_circle(p,2.5,Color(color.lightened(0.8),alpha*0.7))
  "electro_e":
   var nodes: Array[Vector2]=[]
   for i in 3:
    var a=i*TAU/3.0-PI/2
    var p=c+Vector2(cos(a)*r.x,sin(a)*r.y)
    crystal(v,p,52+sin(time*5+i)*3,color,alpha)
    nodes.append(p-Vector2(0,40))
    ring(v,p,Vector2(22,8),color,alpha*0.7)
   for i in 3: bolt(v,nodes[i],nodes[(i+1)%3],color,alpha*0.45,time*4)
   ring(v,c,r*0.7,color,alpha*0.2)
  "cryo_e":
   var growth=minf(1,time/4.0)
   if time<4:
    crystal(v,c,35+growth*75,color,alpha*0.8)
    for i in 8:
     var a=i*TAU/8
     var p=c+Vector2(cos(a)*r.x,sin(a)*r.y)*0.8
     crystal(v,p,15+growth*32,color,alpha*0.65)
     v.draw_line(c,p,Color(color,alpha*0.25),1.4,true)
   for i in 3: ring(v,c,r*(0.9-i*0.12),color,alpha*0.25)
  "anemo_e":
   if time<3:
    for strand in 4:
     var points=PackedVector2Array()
     for i in 35:
      var f=float(i)/34
      var a=f*TAU*1.4+strand*TAU/4-time*3
      points.append(c+Vector2(cos(a)*r.x,sin(a)*r.y)*(1-f)-Vector2(0,f*32))
     v.draw_polyline(points,Color(color,alpha*0.10),9,true)
     v.draw_polyline(points,Color(color.lightened(0.3),alpha*0.8),2.2,true)
