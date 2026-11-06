extends RefCounted
const StageProjection = preload("res://scripts/stage_projection.gd")
const RED=Color("#ff405c")
static func outline(v,points: PackedVector2Array,remaining: float,total: float,fill: bool=true) -> void:
 if points.size()<3:return
 if fill and Geometry2D.triangulate_polygon(points).size()>0:v.draw_colored_polygon(points,Color(RED,0.09))
 var closed=points.duplicate();closed.append(points[0])
 v.draw_polyline(closed,Color(RED,0.9),2.0,true)
 var center=Vector2.ZERO
 for point in points:center+=point
 center/=points.size()
 var ratio=clampf(remaining/maxf(total,0.01),0,1)
 var inner=PackedVector2Array()
 for point in closed:inner.append(center+(point-center)*ratio)
 v.draw_polyline(inner,Color(RED,0.45),1.5,true)
static func circle_points(v,point: Vector2,radius: float) -> PackedVector2Array:
 var points=PackedVector2Array()
 for i in 48:points.append(v.world_to_screen(point+Vector2.from_angle(i*TAU/48)*radius))
 return points
static func area(v,point: Vector2,radius: float,remaining: float,total: float) -> void:
 var center: Vector2=v.world_to_screen(point)+Vector2(0,8)
 var radii: Vector2=v.sim.ability_area_screen_radii(point,radius)
 if not v.sim.endless_mode:
  outline(v,StageProjection.ground_outline(point,radii,48),remaining,total)
  return
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
   _:
    var footprint=StageProjection.ground_outline(p,v.sim.ability_area_screen_radii(p,radius),48) if not v.sim.endless_mode else circle_points(v,p,radius)
    outline(v,footprint,remaining,total)

static func attack_line(v,e: Dictionary) -> void:
 var source: Vector2=e.get("warning_origin",Vector2(e.pos)+Vector2(0,-12))
 var direction: Vector2=e.get("warning_direction",Vector2(-1,0))
 if direction.is_zero_approx():direction=Vector2(-1,0)
 var end:=source
 var arena: Rect2=v.sim.ENDLESS_ARENA if v.sim.endless_mode else v.sim.MOVE_AREA
 if v.has_method("cached_attack_warning_end"):
  end=v.cached_attack_warning_end(e)
 else:
  for index in 90:
   var next:=source+direction*(float(index+1)*18.0)
   if not arena.grow(8.0).has_point(next) or v.sim.terrain_line_blocked(source,next):break
   end=next
 var a: Vector2=v.world_to_screen(source)
 var b: Vector2=v.world_to_screen(end)
 if a.distance_squared_to(b)<9.0:return
 var side: Vector2=(b-a).normalized().orthogonal()
 var width:=3.0 if str(e.get("kind",""))=="ranged" else 5.0
 var progress:=1.0-clampf(float(e.get("warning_timer",0))/maxf(.01,float(e.get("warning_total",1.05))),0,1)
 v.draw_colored_polygon(PackedVector2Array([a+side*width,b+side*width,b-side*width,a-side*width]),Color(RED,.07+progress*.08))
 v.draw_dashed_line(a,b,Color(RED,.35+progress*.5),1.1,9.0,true)
 v.draw_line(a,a.lerp(b,progress),Color(RED,.65),1.7,true)
 for fraction in [.28,.58,.86]:
  var p: Vector2=a.lerp(b,float(fraction))
  var forward: Vector2=(b-a).normalized()
  v.draw_polyline(PackedVector2Array([p-forward*4+side*3,p,p-forward*4-side*3]),Color(RED,.6),1.2,true)
