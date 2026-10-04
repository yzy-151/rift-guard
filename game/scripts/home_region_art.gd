extends RefCounted
## Flat-color scenery for the two explorable districts; no combat tile reuse.
const INK := Color("#101322")
static func draw(view: Node2D, region: String, time: float, font: Font) -> void:
	if region == "harbor": _harbor(view, time, font)
	else: _garden(view, time, font)
static func _rect(view: Node2D, box: Rect2, fill: Color, width: float = 3.0) -> void:
	view.draw_rect(box, fill)
	view.draw_rect(box, INK, false, width)
static func _poly(view: Node2D, points: PackedVector2Array, fill: Color, width: float = 3.0) -> void:
	view.draw_colored_polygon(points, fill)
	var outline := points.duplicate()
	outline.append(points[0])
	view.draw_polyline(outline, INK, width, true)
static func _text(view: Node2D, font: Font, pos: Vector2, text: String, width: float, size: int, color: Color) -> void:
	if font != null: view.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)
static func _stars(view: Node2D, time: float, tint: Color) -> void:
	for i in range(65):
		var p := Vector2(31 + posmod(i * 167, 2490), 95 + posmod(i * 83, 250))
		view.draw_circle(p, 1.2 + sin(time * 0.6 + i) * 0.5, tint)
		if i % 7 == 0:
			view.draw_line(p - Vector2(4,0), p + Vector2(4,0), tint, 1.0)
			view.draw_line(p - Vector2(0,4), p + Vector2(0,4), tint, 1.0)
static func _harbor(view: Node2D, time: float, font: Font) -> void:
	view.draw_rect(Rect2(0,0,2560,720), Color("#101523"))
	view.draw_rect(Rect2(0,150,2560,240), Color("#24364d"))
	view.draw_rect(Rect2(0,260,2560,150), Color("#345265"))
	_stars(view, time, Color("#a9cfd0"))
	view.draw_circle(Vector2(1050,169), 54, Color("#f8dec0"))
	view.draw_circle(Vector2(1069,154), 49, Color("#24364d"))
	# Distant rooftops and windows form a continuous waterfront panorama.
	for i in range(24):
		var x := float(i * 116 - 40)
		var height := float(60 + posmod(i * 47, 95))
		_rect(view, Rect2(x,350-height,98,height), Color("#202c42"), 2)
		for w in range(3):
			for row in range(3):
				if (i + w + row) % 3 != 0: view.draw_rect(Rect2(x+13+w*25,365-height+row*27,9,15), Color("#789a9b"))
	view.draw_rect(Rect2(0,347,2560,90), Color("#172c45"))
	for i in range(90):
		var x := float(posmod(i * 131, 2560)) + sin(time * 0.8 + i) * 8.0
		var y := float(354 + posmod(i * 19, 70))
		view.draw_line(Vector2(x,y), Vector2(x+14+posmod(i*7,35),y), Color("#446578"), 2)
	for boat in range(5):
		var x := 250.0 + boat*480.0
		var y := 377.0 + sin(time*0.8+boat)*3.0
		_poly(view,PackedVector2Array([Vector2(x-70,y),Vector2(x+68,y),Vector2(x+40,y+24),Vector2(x-45,y+24)]),Color("#687b89"))
		view.draw_line(Vector2(x,y),Vector2(x,y-64),INK,4)
		_poly(view,PackedVector2Array([Vector2(x+3,y-61),Vector2(x+3,y-4),Vector2(x+53,y-4)]),Color("#c4b79b"))
	# Promenade: generous clear walking lane in front of shops.
	_rect(view,Rect2(0,418,2560,302),Color("#343d51"),4)
	for row in range(6):
		var y := 432.0 + row*51.0
		view.draw_line(Vector2(0,y),Vector2(2560,y),Color("#546078"),2)
		for col in range(24):
			var x := col*116.0+(58.0 if row%2==0 else 0.0)
			view.draw_line(Vector2(x,y),Vector2(x,y+51),Color("#202b3c"),2)
	view.draw_line(Vector2(0,650),Vector2(2560,650),Color("#7c6275"),4)
	# Tea kiosk with a scalloped striped awning.
	_rect(view,Rect2(340,260,270,162),Color("#354d5b"),5)
	_rect(view,Rect2(367,289,216,96),Color("#edc48e"))
	for i in range(7):
		_rect(view,Rect2(326+i*44,245,44,45),Color("#d16978") if i%2==0 else Color("#efd4b2"),2)
		view.draw_circle(Vector2(348+i*44,288),21,Color("#d16978") if i%2==0 else Color("#efd4b2"))
	_rect(view,Rect2(350,204,244,39),Color("#132c37"))
	_text(view,font,Vector2(359,232),"雾灯茶屋  /  OPEN",226,19,Color("#a6efdf"))
	for x in [390.0,470.0,548.0]:
		_rect(view,Rect2(x,350,28,32),Color("#926375"),2)
		view.draw_arc(Vector2(x+14,336),9,0,PI,12,Color("#fcdfb4"),2,true)
	# Little theater; its lights sway instead of flooding the foreground.
	_rect(view,Rect2(845,208,330,214),Color("#252239"),5)
	_poly(view,PackedVector2Array([Vector2(826,208),Vector2(1010,137),Vector2(1194,208)]),Color("#713b59"),5)
	_rect(view,Rect2(877,242,266,165),Color("#111b2b"))
	for x in [882.0,1100.0]: _rect(view,Rect2(x,246,41,153),Color("#a74f6d"),2)
	_text(view,font,Vector2(867,233),"今 夜 只 演 一 场",290,20,Color("#f6d4b0"))
	view.draw_circle(Vector2(1010,331),28,Color("#446276"))
	# Clock and a covered public piano.
	_rect(view,Rect2(1408,203,18,218),Color("#5e687d"))
	view.draw_circle(Vector2(1417,199),40,INK)
	view.draw_circle(Vector2(1417,199),33,Color("#f0d8b5"))
	view.draw_line(Vector2(1417,199),Vector2(1417,177),INK,4)
	view.draw_line(Vector2(1417,199),Vector2(1436,211),INK,3)
	_rect(view,Rect2(1760,302,212,114),Color("#272536"),5)
	_poly(view,PackedVector2Array([Vector2(1742,301),Vector2(1850,231),Vector2(1988,301)]),Color("#4a5269"),5)
	_rect(view,Rect2(1790,347,151,35),Color("#e4d4c4"),3)
	for i in range(14):
		view.draw_line(Vector2(1792+i*10,349),Vector2(1792+i*10,380),INK,1)
		if i%7 not in [2,6]: view.draw_rect(Rect2(1798+i*10,348,5,19),INK)
	_text(view,font,Vector2(1755,329),"请别替沉默鼓掌",224,15,Color("#b5bed6"))
	for x in [240.0,725.0,1310.0,1650.0,2195.0]:
		view.draw_line(Vector2(x,180),Vector2(x,427),INK,8)
		view.draw_line(Vector2(x,180),Vector2(x+32,180),INK,6)
		var lamp := Vector2(x+32,197+sin(time+x)*2)
		_rect(view,Rect2(lamp-Vector2(13,16),Vector2(26,36)),Color("#eebfa0"),4)
	for i in range(12):
		var p := Vector2(fposmod(i*219.0+time*20,2560), 175.0+fposmod(i*83.0+time*35,330))
		view.draw_line(p,p+Vector2(-5,11),Color(0.7,0.85,0.9,0.20),1)
	_text(view,font,Vector2(775,697),"雾灯港 / 有些故事，比船期更值得等。",1000,18,Color("#93b8c5"))
static func _garden(view: Node2D, time: float, font: Font) -> void:
	view.draw_rect(Rect2(0,0,2560,720),Color("#191c34"))
	view.draw_rect(Rect2(0,225,2560,195),Color("#3c405d"))
	_stars(view,time,Color("#d7c7ed"))
	view.draw_circle(Vector2(1840,160),73,Color("#e5d7e8"))
	view.draw_circle(Vector2(1859,154),58,Color("#c0bdde"))
	# Glass roof and tall panes, outlined like a paper theater.
	for section in range(7):
		var x := section*390.0-78.0
		_poly(view,PackedVector2Array([Vector2(x,413),Vector2(x,210),Vector2(x+195,87),Vector2(x+390,210),Vector2(x+390,413)]),Color(0.28,0.40,0.49,0.28),5)
		view.draw_line(Vector2(x+195,87),Vector2(x+195,413),Color("#6a8190"),4)
		view.draw_line(Vector2(x,277),Vector2(x+390,277),Color("#627789"),4)
		view.draw_line(Vector2(x+18,209),Vector2(x+162,122),Color(0.75,0.87,0.9,0.15),8)
	_rect(view,Rect2(0,410,2560,310),Color("#444a63"),4)
	for row in range(5):
		var y := 422.0+row*61.0
		view.draw_line(Vector2(0,y),Vector2(2560,y),Color("#5d6881"),2)
		for col in range(20):
			var x := col*140.0+float(row%2)*70
			view.draw_line(Vector2(x,y),Vector2(x-20,y+61),Color("#343a54"),2)
	# Raised planters stay above the lane. The pool shimmers behind visitors.
	for x in [330.0,770.0,1260.0,1740.0,2200.0]:
		_rect(view,Rect2(x-102,366,205,67),Color("#7a637c"),5)
		_rect(view,Rect2(x-94,366,189,13),Color("#beb2a6"),3)
		for stem in range(6):
			var p := Vector2(x-75+stem*30,362)
			var top := p-Vector2(sin(time*0.8+stem)*4,40+posmod(stem*19,62))
			view.draw_line(p,top,Color("#829e8b"),4)
			for side in [-1.0,1.0]:
				_poly(view,PackedVector2Array([top+Vector2(0,20),top+Vector2(side*23,-3),top+Vector2(side*28,15),top+Vector2(0,27)]),Color("#75a798"),2)
			view.draw_circle(top-Vector2(0,4),8,Color("#d8bddb") if stem%2==0 else Color("#e5ca8d"))
	_rect(view,Rect2(868,395,272,63),Color("#9d9cba"),5)
	_rect(view,Rect2(880,403,248,43),Color("#526f90"),2)
	for i in range(8):
		var x := 892.0+i*27
		view.draw_line(Vector2(x,424+sin(time+i)*3),Vector2(x+17,424+sin(time+i)*3),Color("#a3ced3"),2)
	# Cloud-shaped seats and a sewing table make this an inhabited place.
	for x in [500.0,1500.0]:
		view.draw_circle(Vector2(x,342),32,INK)
		view.draw_circle(Vector2(x+40,326),44,INK)
		view.draw_circle(Vector2(x+88,343),31,INK)
		view.draw_circle(Vector2(x,342),27,Color("#d5d4df"))
		view.draw_circle(Vector2(x+40,326),39,Color("#d5d4df"))
		view.draw_circle(Vector2(x+88,343),26,Color("#d5d4df"))
		_rect(view,Rect2(x-18,356,126,29),Color("#a7a6c7"),3)
		for leg in [x-7,x+96]: view.draw_line(Vector2(leg,385),Vector2(leg,416),INK,6)
	_rect(view,Rect2(1960,330,220,26),Color("#a890a8"),4)
	for x in [1977.0,2160.0]: view.draw_line(Vector2(x,355),Vector2(x,424),INK,6)
	_poly(view,PackedVector2Array([Vector2(2010,332),Vector2(2140,332),Vector2(2120,404),Vector2(2040,396)]),Color("#94c0bf"),3)
	for x in [1990.0,2030.0,2090.0]:
		_rect(view,Rect2(x,302,18,28),Color("#d3a2bc"),2)
		view.draw_line(Vector2(x-3,302),Vector2(x+21,302),Color("#ded5c9"),3)
	# Tiny drifting motes, restrained below the character labels.
	for i in range(28):
		var p := Vector2(fposmod(i*137.0+time*9,2480)+40,210+fposmod(i*51.0,220)+sin(time*0.8+i)*10)
		view.draw_circle(p,2+float(i%3)*0.4,Color(0.79,0.91,0.75,0.45+0.25*sin(time+i)))
	_text(view,font,Vector2(400,170),"月 影 温 室",340,28,Color("#ecd8df"))
	_text(view,font,Vector2(860,697),"今日处方：休息。禁止给云朵安排加班。",950,18,Color("#c1bad6"))
