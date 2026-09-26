extends RefCounted
static func polygon(v,points: PackedVector2Array,color: Color) -> void:
 if color.a<0.005 or Geometry2D.triangulate_polygon(points).is_empty(): return
 v.draw_colored_polygon(points,color)
# Screen-space ellipses share the gameplay projection; all calls precede actors.
static func ring(v,c: Vector2,r: Vector2,a: float,color: Color,width: float=2.0) -> void:
 color.a*=a
 v._draw_dedicated_arc(c,r,0.0,TAU,color,width)
static func feather(v,p: Vector2,d: Vector2,size: float,color: Color) -> void:
 if size<0.1 or color.a<0.001: return
 var side=d.orthogonal()
 polygon(v,PackedVector2Array([p-d*size,p+side*size*0.32,p+d*size,p-side*size*0.32]),color)
 v.draw_line(p-d*size,p+d*size,Color(0.94,1.0,0.88,color.a),1.2,true)
static func wind(v,c: Vector2,r: Vector2,t: float,a: float,healing: bool) -> void:
 var mint=Color(0.36,0.98,0.73,a)
 for band in 4:
  var points=PackedVector2Array()
  for j in 49:
   var f=float(j)/48.0
   var angle=f*TAU*1.25+t*2.5+band*TAU/4.0
   var radius=lerpf(0.97,0.12,f)
   points.append(c+Vector2(cos(angle)*r.x,sin(angle)*r.y)*radius+Vector2(0,-f*28))
  v.draw_polyline(points,Color(0.25,0.82,0.63,a*0.18),7.0,true)
  v.draw_polyline(points,Color(0.75,1.0,0.83,a*0.7),1.7,true)
 for i in 12:
  var angle=float(i)*TAU/12.0-t*0.9
  var p=c+Vector2(cos(angle)*r.x,sin(angle)*r.y)*0.88
  feather(v,p,Vector2(-sin(angle),cos(angle)*0.45).normalized(),10 if healing else 7,mint)
 ring(v,c,r,a*0.5,Color(0.52,1,0.78))
 if healing:
  for side in [-1,1]:
   for i in 5:
    var p=c+Vector2(side*(16+i*10),-20-i*7+sin(t*3)*4)
    feather(v,p,Vector2(side*0.65,-1).normalized(),19-i*1.6,Color(0.75,1,0.83,a*0.75))
static func tide(v,c: Vector2,r: Vector2,t: float,a: float) -> void:
 for i in 3:
  var f=fposmod(t*0.55+i/3.0,1.0)
  ring(v,c,r*(0.2+0.8*f),a*(1-f)*0.7,Color(0.54,0.87,1),2.7)
 for i in 6:
  var angle=i*TAU/6.0+t*0.65
  var p=c+Vector2(cos(angle)*r.x,sin(angle)*r.y)*0.86
  v._draw_dedicated_arc(p,Vector2(13,8),angle,PI*1.35,Color(0.65,0.94,1,a*0.9),3.3)
  feather(v,p+Vector2(0,-13),Vector2.UP,5,Color(0.82,0.96,1,a*0.8))
 ring(v,c,r,a*0.38,Color(0.32,0.65,1),3)
static func meteor(v,e: Dictionary) -> void:
 var total=maxf(0.01,float(e.total))
 var progress=clampf(1.0-float(e.life)/total,0,1)
 var c: Vector2=v.world_to_screen(e.pos)
 var r: Vector2=v.sim.ability_area_screen_radii(e.pos,float(e.get("radius",300)))
 var gold=Color(1,0.69,0.23)
 if e.kind=="fireball_fall":
  var a=smoothstep(0,0.18,progress)
  ring(v,c,r,a*0.65,gold,2.8)
  ring(v,c,r*(1.05-progress*0.15),a*0.4,gold)
  for i in 8:
   var angle=i*TAU/8.0
   var mark=c+Vector2(cos(angle)*r.x,sin(angle)*r.y)
   v.draw_line(mark,mark+(c-mark)*0.13,Color(1,0.82,0.4,a),3,true)
  var p=c+Vector2(-310,-520)*(1-pow(progress,2.3))
  var size=42+progress*46
  for i in 5:
   var shift=Vector2(-32,-55)*i
   v.draw_line(p+shift,p+shift+Vector2(-35,-90),Color(1,0.57,0.13,a*(0.5-i*0.08)),maxf(2,18-i*3),true)
  var poly=PackedVector2Array([p+Vector2(-size,-size*0.35),p+Vector2(-size*0.3,-size),p+Vector2(size*0.7,-size*0.7),p+Vector2(size,size*0.3),p+Vector2(0,size),p+Vector2(-size*0.7,size*0.6)])
  polygon(v,poly,Color(0.2,0.12,0.08,a))
  poly.append(poly[0]);v.draw_polyline(poly,Color(1,0.73,0.29,a),5,true)
  for i in 6:
   v.draw_line(poly[i],p,Color(1,0.54,0.11,a*0.8),3,true)
  polygon(v,PackedVector2Array([p+Vector2(-size*0.3,-size),p,p+Vector2(size*0.7,-size*0.7)]),Color(0.91,0.46,0.12,a))
 else:
  var a=1-smoothstep(0.48,1,progress)
  for i in 3:
   var spread=clampf(progress*3.2-i*0.20,0.01,1)
   ring(v,c,r*spread,a*(0.85-i*0.17),gold,9-i*2)
  for i in 16:
   var angle=i*TAU/16.0
   var direction=Vector2(cos(angle)*r.x,sin(angle)*r.y)
   var p=c+direction*minf(1,progress*2.0)+Vector2(0,-sin(progress*PI)*48)
   feather(v,p,Vector2(cos(angle),sin(angle)),(9+i%4)*a,Color(0.82,0.46,0.14,a))
   v.draw_line(c+direction*0.16,c+direction*0.72,Color(1,0.65,0.22,a*0.38),2,true)
