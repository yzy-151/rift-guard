extends RefCounted
## Low-contrast cut stone and tall, solid basalt barricades.
static func draw(v) -> void:
 v.draw_rect(Rect2(0,0,1280,720),Color("16151e"))
 var bounds:Rect2=v.visible_world_rect().grow(180)
 for row in range(floori(bounds.position.y/72),ceili(bounds.end.y/72)):
  var shift:=64 if posmod(row,2)==1 else 0
  for col in range(floori(bounds.position.x/128)-1,ceili(bounds.end.x/128)+1):
   var p:Vector2=v.world_to_screen(Vector2(col*128+shift,row*72))
   var k:=posmod(col*17+row*31,9)
   var c:Color=[Color("292832"),Color("2d2b35"),Color("302d38"),Color("282731")][k%4]
   var outline:=PackedVector2Array([p+Vector2(7,2),p+Vector2(119,2),p+Vector2(126,9),p+Vector2(126,61),p+Vector2(118,70),p+Vector2(8,70),p+Vector2(2,64),p+Vector2(2,9)])
   v.draw_colored_polygon(outline,c)
   v.draw_line(p+Vector2(9,3),p+Vector2(118,3),Color("393540"),1)
   if k==3:
    v.draw_polyline(PackedVector2Array([p+Vector2(92,70),p+Vector2(80,53),p+Vector2(92,38)]),Color("211f29"),1.5)
   if k==7:
    v.draw_colored_polygon(PackedVector2Array([p+Vector2(15,51),p+Vector2(32,48),p+Vector2(43,59),p+Vector2(24,61)]),Color("24222c"))
static func wall(v,r:Rect2) -> void:
 if not Rect2(-140,-140,1560,1000).intersects(r):return
 # The dark plinth exactly covers the impassable footprint; height rises above it.
 v.draw_rect(Rect2(r.position+Vector2(12,18),r.size+Vector2(14,6)),Color(0,0,0,0.35))
 v.draw_rect(r.grow(3),Color("0c0b12"))
 var horizontal:=r.size.x>=r.size.y
 var length:float=r.size.x if horizontal else r.size.y
 var count:=maxi(1,ceili(length/80.0))
 for i in count:
  var a:Rect2=Rect2(r.position+Vector2(i*length/count,0),Vector2(length/count,r.size.y)) if horizontal else Rect2(r.position+Vector2(0,i*length/count),Vector2(r.size.x,length/count))
  var h:=48.0+float(i%3)*9.0
  var tl:=a.position+Vector2(5,-h)
  var tr:=Vector2(a.end.x-5,a.position.y-h+8)
  var bl:=Vector2(a.position.x+3,a.end.y-10-h)
  var br:=Vector2(a.end.x-3,a.end.y-7-h)
  var front:=PackedVector2Array([bl,br,a.end-Vector2(2,0),Vector2(a.position.x+2,a.end.y)])
  v.draw_colored_polygon(front,Color("463541"))
  v.draw_polyline(PackedVector2Array([bl,br,a.end-Vector2(2,0),Vector2(a.position.x+2,a.end.y),bl]),Color("100d17"),4,true)
  v.draw_colored_polygon(PackedVector2Array([tr,Vector2(a.end.x,a.position.y+3),a.end-Vector2(2,0),br]),Color("271e2c"))
  var top:=PackedVector2Array([tl+Vector2(7,-6),tr,br,bl,tl])
  v.draw_colored_polygon(top,Color("74606a"))
  v.draw_polyline(PackedVector2Array([tl+Vector2(7,-6),tr,br,bl,tl,tl+Vector2(7,-6)]),Color("17111d"),4,true)
  v.draw_line(bl+Vector2(5,0),br-Vector2(4,0),Color("a18386"),2)
  var mid:Vector2=(bl+br)/2
  v.draw_polyline(PackedVector2Array([mid,mid+Vector2(-7,16),mid+Vector2(4,27),mid+Vector2(-2,h-5)]),Color("1d1521"),3)
  if i%2==0:
   var shard:=PackedVector2Array([mid+Vector2(-9,20),mid+Vector2(1,12),mid+Vector2(11,24),mid+Vector2(0,38)])
   v.draw_colored_polygon(shard,Color("883847"))
