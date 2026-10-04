extends Control
## Small vector emblems share the same stroke language, with distinct silhouettes.
var icon := "star"
var color := Color("efcf88")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_set_transform(size/2.0,0,Vector2.ONE*0.94)
	match icon:
		"heart":
			var pts := PackedVector2Array()
			for i in range(81):
				var t := TAU*i/80.0
				pts.append(Vector2(16*pow(sin(t),3),-(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t)))*1.7)
			draw_colored_polygon(pts,Color(color,0.15))
			draw_polyline(pts,color,2.8,true)
			draw_line(Vector2(-8,-4),Vector2(8,-4),color,3,true)
			draw_line(Vector2(0,-12),Vector2(0,4),color,3,true)
		"drop","water","potion":
			var pts := PackedVector2Array([Vector2(0,-31),Vector2(-15,-8),Vector2(-21,8),Vector2(-17,23),Vector2(0,29),Vector2(17,23),Vector2(21,8),Vector2(15,-8),Vector2(0,-31)])
			draw_colored_polygon(pts,Color(color,0.15))
			draw_polyline(pts,color,2.5,true)
			draw_arc(Vector2(2,8),11,0.3,1.6,16,Color(color,0.7),2.4,true)
		"clock":
			draw_arc(Vector2.ZERO,26,0,TAU,64,color,2.6,true)
			draw_polyline(PackedVector2Array([Vector2(0,-18),Vector2.ZERO,Vector2(13,8)]),color,3,true)
			for i in range(4):
				var d := Vector2.from_angle(i*PI/2)
				draw_line(d*20,d*24,color,2,true)
		"shield":
			var pts := PackedVector2Array([Vector2(-24,-23),Vector2(0,-29),Vector2(24,-23),Vector2(22,8),Vector2(13,22),Vector2(0,32),Vector2(-13,22),Vector2(-22,8),Vector2(-24,-23)])
			draw_colored_polygon(pts,Color(color,0.15))
			draw_polyline(pts,color,2.5,true)
			_star(Vector2.ZERO,14)
		"frost":
			for i in range(6):
				var d := Vector2.from_angle(i*PI/3)
				draw_line(Vector2.ZERO,d*30,color,2.5,true)
				for j in [-1,1]: draw_line(d*17,d*23+d.orthogonal()*8*j,color,2.2,true)
		"bolt":
			var pts := PackedVector2Array([Vector2(4,-31),Vector2(-22,6),Vector2(-4,6),Vector2(-10,32),Vector2(22,-7),Vector2(3,-7),Vector2(4,-31)])
			draw_colored_polygon(pts,Color(color,0.24))
			draw_polyline(pts,color,2.6,true)
		"moon":
			draw_arc(Vector2.ZERO,27,0.45,5.1,56,color,3,true)
			draw_arc(Vector2(14,-10),24,1.16,4.24,42,color,2.5,true)
			_star(Vector2(20,-21),7)
		"leaf","wing","wind","speed":
			for i in range(3):
				var y := -16.0+i*16
				draw_line(Vector2(-26+i*6,y),Vector2(15-i*4,y),color,2.7,true)
				draw_arc(Vector2(15-i*4,y-6),6,-PI/2,PI/2,20,color,2.7,true)
			_star(Vector2(-23,23),6)
		"blade","arrow":
			var pts := PackedVector2Array([Vector2(21,-28),Vector2(13,-5),Vector2(-11,17),Vector2(-19,9),Vector2(4,-15),Vector2(21,-28)])
			draw_colored_polygon(pts,Color(color,0.22))
			draw_polyline(pts,color,2.5,true)
			draw_line(Vector2(-22,5),Vector2(-4,24),color,3.3,true)
			draw_line(Vector2(-14,15),Vector2(-26,27),color,5,true)
		"coin":
			draw_arc(Vector2.ZERO,26,0,TAU,56,color,2.6,true)
			draw_arc(Vector2.ZERO,19,0,TAU,56,Color(color,0.45),1.5,true)
			_star(Vector2.ZERO,13)
		"orbit":
			draw_arc(Vector2.ZERO,24,0,TAU,64,Color(color,0.6),2,true)
			_star(Vector2.ZERO,16)
			draw_circle(Vector2(22,-10),5,color)
			draw_circle(Vector2(-19,14),3,color)
		"well":
			draw_arc(Vector2(0,11),27,0,PI,40,color,2.5,true)
			draw_line(Vector2(-27,10),Vector2(27,10),color,2.5,true)
			draw_line(Vector2(-16,30),Vector2(16,30),color,2.5,true)
			_star(Vector2(0,-12),20)
		"fire":
			var pts := PackedVector2Array([Vector2(0,-31),Vector2(10,-9),Vector2(21,-16),Vector2(25,11),Vector2(13,28),Vector2(-6,29),Vector2(-24,15),Vector2(-20,-6),Vector2(-10,3),Vector2(0,-31)])
			draw_colored_polygon(pts,Color(color,0.18))
			draw_polyline(pts,color,2.6,true)
			_star(Vector2(0,13),12)
		"stars":
			_star(Vector2(-12,7),21)
			_star(Vector2(17,-17),14)
		_:
			_star(Vector2.ZERO,28)
			draw_arc(Vector2.ZERO,32,0.2,1.1,16,Color(color,0.4),1.5,true)
			draw_arc(Vector2.ZERO,32,PI+0.2,PI+1.1,16,Color(color,0.4),1.5,true)

func _star(p: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in range(8): pts.append(p+Vector2.from_angle(-PI/2+i*PI/4)*r*(1.0 if i%2==0 else 0.28))
	draw_colored_polygon(pts,Color(color,0.2))
	pts.append(pts[0])
	draw_polyline(pts,color,2.4,true)
