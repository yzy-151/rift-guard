extends RefCounted
const RED=Color("#ff405c")
static func outline(v,points: PackedVector2Array,remaining: float,total: float,fill: bool=true) -> void:
 if points.size()<3:return
 var ratio=clampf(remaining/maxf(total,0.01),0,1)
 var progress=1.0-ratio
 var urgency=smoothstep(0.55,1.0,progress)
 if fill and Geometry2D.triangulate_polygon(points).size()>0:v.draw_colored_polygon(points,Color(RED,0.025+urgency*0.06))
 var closed=points.duplicate();closed.append(points[0])
 # The full damage footprint stays fixed; only the perimeter timer progresses.
 # This also keeps donut interiors genuinely empty instead of shrinking a
 # misleading danger ring across the safe center.
 v.draw_polyline(closed,Color(RED,0.40+urgency*0.42),1.2+urgency*0.4,true)
 var length=0.0
 for i in range(1,closed.size()):length+=closed[i-1].distance_to(closed[i])
 var left=length*progress
 var elapsed_edge=PackedVector2Array([closed[0]])
 for i in range(1,closed.size()):
  var segment=closed[i-1].distance_to(closed[i])
  if left<=0.0:break
  elapsed_edge.append(closed[i-1].lerp(closed[i],minf(1.0,left/maxf(0.001,segment))))
  left-=segment
 if elapsed_edge.size()>1:v.draw_polyline(elapsed_edge,Color("#ffd9d1",0.4+urgency*0.32),1.0,true)
 # Bold corner marks read on both dark floors and pale illustrated terrain.
 for i in range(0,points.size(),maxi(1,points.size()/4)):
  var tangent=(points[(i+1)%points.size()]-points[i]).normalized()
  var side=tangent.orthogonal()
  v.draw_line(points[i]-side*4.0,points[i]+side*4.0,Color("#fff4d6",0.4+urgency*0.3),1.2,true)
static func circle_points(v,point: Vector2,radius: float) -> PackedVector2Array:
 var points=PackedVector2Array()
 for i in 48:points.append(v.world_to_screen(point+Vector2.from_angle(i*TAU/48)*radius))
 return points
static func capsule_points(v,source: Vector2,target: Vector2,radius: float) -> PackedVector2Array:
 var points=PackedVector2Array()
 var heading=(target-source).angle()
 for i in 17:points.append(v.world_to_screen(target+Vector2.from_angle(heading-PI/2+i*PI/16)*radius))
 for i in 17:points.append(v.world_to_screen(source+Vector2.from_angle(heading+PI/2+i*PI/16)*radius))
 return points
static func area(v,point: Vector2,radius: float,remaining: float,total: float) -> void:
 var center: Vector2=v.world_to_screen(point)+v.ground_visual_offset()
 var radii: Vector2=v.sim.ability_area_screen_radii(point,radius)
 var points=PackedVector2Array()
 for i in 48:points.append(center+Vector2(cos(i*TAU/48)*radii.x,sin(i*TAU/48)*radii.y))
 outline(v,points,remaining,total)
static func polygon_world(v,points: Array,remaining: float,total: float) -> void:
 var screen=PackedVector2Array()
 for point in points:screen.append(v.world_to_screen(point))
 outline(v,screen,remaining,total)
static func generic(v,e: Dictionary) -> void:
 var radius=float(e.get("special_warning_radius",150))
 var remaining=float(e.get("special_warning",0))
 var total=float(e.get("special_warning_total",1.8))
 var source: Vector2=e.pos
 var shape=str(e.get("special_warning_shape","circle"))
 for value in e.get("special_warning_positions",[]):
  var p: Vector2=value
  match shape:
   "line","multi_line","rectangle":
    var width=34.0 if shape=="line" else 52.0
    var angle=(p-source).angle()
    var points: Array=[]
    for i in 17:points.append(p+Vector2.from_angle(angle-PI/2+i*PI/16)*width)
    for i in 17:points.append(source+Vector2.from_angle(angle+PI/2+i*PI/16)*width)
    polygon_world(v,points,remaining,total)
   "cross":
    polygon_world(v,[p+Vector2(-radius,-34),p+Vector2(radius,-34),p+Vector2(radius,34),p+Vector2(-radius,34)],remaining,total)
    polygon_world(v,[p+Vector2(-34,-radius),p+Vector2(34,-radius),p+Vector2(34,radius),p+Vector2(-34,radius)],remaining,total)
   "fan","cone":
    var points: Array=[source]
    var angle=(p-source).angle()
    for i in 33:points.append(source+Vector2.from_angle(angle-acos(0.62)+i*2*acos(0.62)/32)*radius*1.45)
    polygon_world(v,points,remaining,total)
   "donut":
    # Fill separate wedges to retain the genuinely safe inner area.
    for i in 48:
     var a=Vector2.from_angle(i*TAU/48);var b=Vector2.from_angle((i+1)*TAU/48)
     var q=PackedVector2Array([v.world_to_screen(p+a*radius),v.world_to_screen(p+b*radius),v.world_to_screen(p+b*radius*0.38),v.world_to_screen(p+a*radius*0.38)])
     v.draw_colored_polygon(q,Color(RED,0.10))
    outline(v,circle_points(v,p,radius),remaining,total,false)
    var inner=circle_points(v,p,radius*0.38);inner.append(inner[0]);v.draw_polyline(inner,RED,1.8,true)
   "checker":
    for x in range(-ceili(radius/48),ceili(radius/48)):
     for y in range(-ceili(radius/36),ceili(radius/36)):
      var dx=clampf((x+0.5)*48,-radius,radius)
      var dy=clampf((y+0.5)*36,-radius,radius)
      if (floori(absf(dx)/48)+floori(absf(dy)/36))%2!=0:continue
      polygon_world(v,[p+Vector2(maxf(-radius,x*48),maxf(-radius,y*36)),p+Vector2(minf(radius,(x+1)*48),maxf(-radius,y*36)),p+Vector2(minf(radius,(x+1)*48),minf(radius,(y+1)*36)),p+Vector2(maxf(-radius,x*48),minf(radius,(y+1)*36))],remaining,total)
   _:outline(v,circle_points(v,p,radius),remaining,total)
