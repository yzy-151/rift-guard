extends RefCounted
## Filled animation clouds and real fragment faces replace outlined rings / rays.
## event() / draw() take world coordinates; impact() supports an existing draw transform.
const SHEET = preload("res://assets/vfx/explosions_20261005/cartoon_blast_fire_ice_v1.png")
const GLOW = preload("res://assets/vfx/combat_20261005/orb_glow.png")
const LIFETIME := .48
const MAX_DRAW_CALLS := 26
const MAX_LEAN_DRAW_CALLS := 6
const COLORS := {"pyro":Color("#ff8252"),"cryo":Color("#72deff"),"hydro":Color("#76e1ff"),"electro":Color("#b594ff"),"anemo":Color("#88f0ce"),"geo":Color("#ffd169"),"none":Color("#ffd095")}
const KINDS := ["device_explosion", "death_burst", "enemy_volatile", "splash", "overloaded", "superconduct", "shatter", "shield_break", "shield_hit"]

static func _color(element: String) -> Color:
	return COLORS.get(element, COLORS.pyro)

static func _alpha(age: float, duration: float) -> float:
	if not is_finite(age) or not is_finite(duration) or duration <= .001 or age < 0.0 or age >= duration: return 0.0
	return 1.0 - smoothstep(.54, 1.0, age / duration)

static func _lean(v) -> bool:
	if bool(v.reduced_effects): return true
	return v.sim.enemies.size() > 100 if v.get("sim") != null else false

static func _ellipse(v, center: Vector2, radii: Vector2, color: Color) -> void:
	if color.a <= .005 or minf(radii.x, radii.y) < .2: return
	var points := PackedVector2Array()
	for index in 16:
		var angle := float(index) * TAU / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	v.draw_colored_polygon(points, color)

static func _fragment(v, center: Vector2, direction: Vector2, size: float, color: Color, alpha: float, faceted: bool = true) -> void:
	if size < .2 or alpha <= .005: return
	var axis := direction.normalized() * size
	var side := axis.orthogonal() * .55
	var tip := center + axis
	var tail := center - axis * .75
	var left := center + side - axis * .12
	var right := center - side - axis * .12
	v.draw_colored_polygon(PackedVector2Array([tip,left,tail,right]), Color(color,alpha))
	if faceted:
		v.draw_colored_polygon(PackedVector2Array([tip,left,center]), Color(color.lightened(.66),alpha))

static func _light(v, local_center: Vector2, size: Vector2, color: Color, alpha: float, glow_screen: Vector2) -> void:
	if alpha <= .005: return
	# Additive child commands need screen coordinates, not the temporary parent draw transform.
	if glow_screen.is_finite() and v.has_method("emit_glow"):
		v.emit_glow(GLOW, glow_screen, size, color, alpha)
	else:
		v.draw_texture_rect(GLOW, Rect2(local_center-size*.5,size),false,Color(color,alpha*.45))

static func _sheet_region(row: int, frame: int) -> Rect2:
	var cell := Vector2(SHEET.get_width()/4.0,SHEET.get_height()/2.0)
	return Rect2(Vector2(clampi(frame,0,3)*cell.x,clampi(row,0,1)*cell.y),cell)

static func _frame(progress: float) -> int:
	if progress < .18: return 0
	if progress < .43: return 1
	if progress < .74: return 2
	return 3

static func _sheet(v, rect: Rect2, row: int, progress: float, tint: Color, alpha: float, lean: bool) -> void:
	var frame := _frame(progress)
	var blend := 0.0
	if not lean and frame < 3:
		var next_at: float = [.18,.43,.74][frame]
		blend = smoothstep(next_at-.075,next_at,progress)
	if blend < .995:
		v.draw_texture_rect_region(SHEET,rect,_sheet_region(row,frame),Color(tint,alpha*(1.0-blend)))
	if blend > .005:
		v.draw_texture_rect_region(SHEET,rect,_sheet_region(row,frame+1),Color(tint,alpha*blend))

static func draw(v, world: Vector2, age: float, radius: float, element: String = "pyro", duration: float = LIFETIME, seed: float = 0.0) -> void:
	var alpha := _alpha(age,duration)
	if alpha <= .005 or not world.is_finite() or not is_finite(radius): return
	var progress := age / duration
	var lean := _lean(v)
	var point: Vector2 = v.world_to_screen(world)
	var depth: float = clampf(v.world_depth_scale(world),.35,2.0)
	var ground_radii: Vector2 = v.sim.ability_area_screen_radii(world,maxf(1.0,radius))
	var width := clampf(ground_radii.x*.98,72.0*depth,174.0*depth)
	var size := Vector2(width,width*.97)
	var cool := element in ["cryo","hydro","electro","anemo"]
	var color := _color(element)
	var row := 1 if cool else 0
	var growth := .84 + .16*smoothstep(0.0,.38,progress)
	var lift := smoothstep(.42,1.0,progress)*15.0*depth
	# Grounded shadow and vertical cloud body; the hurt area remains the simulation's ellipse.
	_ellipse(v,point+Vector2(0,5)*depth,Vector2(width*.27,width*.075),Color(.045,.03,.065,alpha*.23))
	var rect := Rect2(point-Vector2(size.x*.5,size.y*.88+lift)*growth+Vector2(0,9)*depth,size*growth)
	var tint := Color.WHITE
	if element == "electro": tint=Color("#d5bbff")
	elif element == "anemo": tint=Color("#beffdb")
	elif element == "geo": tint=Color("#fff0bf")
	_sheet(v,rect,row,progress,tint,alpha,lean)
	if lean: return
	var core := point+Vector2(0,-width*.33-lift*.3)
	var glow_alpha := alpha*(1.0-smoothstep(.18,.67,progress))
	_light(v,core,Vector2(width*.95,width*.82),color,glow_alpha*.76,core)
	if progress < .20:
		_ellipse(v,core,Vector2(width*.09,width*.07)*(1.0-progress*3.0),Color(1,.98,.90,glow_alpha*.95))
	for index in 5:
		var angle := seed*TAU + float(index)*2.39996
		var direction := Vector2(cos(angle),sin(angle)*.62)
		var distance := width*(.09+.34*(1.0-pow(1.0-progress,2.0)))
		var center := core+direction*distance-Vector2(0,sin(progress*PI)*(10.0+index%2*5.0))*depth
		_fragment(v,center,direction,depth*(2.3+index%3)*(1.0-progress*.5),color.lightened(.35),alpha*.85,true)

static func impact(v, point: Vector2, color: Color, progress: float, strength: float = 1.0, lean: bool = false, seed: float = 0.0, glow_screen: Vector2 = Vector2(INF,INF), style: String = "compact") -> void:
	if not is_finite(progress) or progress < 0.0 or progress >= 1.0 or not point.is_finite() or not is_finite(strength): return
	var alpha := 1.0-smoothstep(.35,1.0,progress)
	var scale := clampf(strength,.25,2.5)
	var diameter := 44.0*scale
	if style == "ice":
		var size := Vector2.ONE*diameter*(.78+.22*smoothstep(0.0,.4,progress))
		_sheet(v,Rect2(point-size*.5-Vector2(0,progress*6.0),size),1,progress,color.lightened(.65),alpha,lean)
	else:
		# Three broad filled petal fragments and a compact cloud core, never an outline arc.
		for index in (2 if lean else 3):
			var angle := seed*TAU+float(index)*TAU/3.0
			var direction := Vector2.from_angle(angle)
			var center := point+direction*(diameter*(.10+.20*progress))
			_fragment(v,center,direction,diameter*(.11-.075*progress),color,alpha,true)
		_ellipse(v,point,Vector2(diameter*.16,diameter*.125)*(1.0-progress*.62),Color(color.lightened(.50),alpha*.95))
	if lean: return
	_light(v,point,Vector2.ONE*diameter*.95,color,alpha*.48,glow_screen)
	if progress < .42:
		_ellipse(v,point,Vector2(diameter*.065,diameter*.060)*(1.0-progress*1.7),Color(1,1,1,alpha*.96))
	for index in 3:
		var direction := Vector2.from_angle(seed*TAU+float(index)*2.39996+1.13)
		var center := point+direction*diameter*(.18+.38*progress)-Vector2(0,sin(progress*PI)*5.0*scale)
		_fragment(v,center,direction,diameter*(.044-.026*progress),color.lightened(.55),alpha*.78,false)

static func event(v, e: Dictionary) -> bool:
	var kind := str(e.get("kind",""))
	if kind not in KINDS: return false
	var total := maxf(.01,float(e.get("total",LIFETIME)))
	var age := total-float(e.get("life",total))
	if age < 0 or age >= total: return true
	var world := Vector2(e.get("pos",Vector2.ZERO))
	var element := str(e.get("element","pyro"))
	if kind in ["shield_hit","shield_break","superconduct","shatter"]: element="cryo"
	elif kind == "overloaded": element="pyro"
	if kind in ["shield_hit","shield_break"]:
		var point: Vector2 = v.world_to_screen(world)+Vector2(0,-18)
		impact(v,point,_color(element),age/total,1.55 if kind=="shield_break" else 1.0,_lean(v),float(e.get("enemy_id",0))*.13,point,"ice")
	else:
		draw(v,world,age,float(e.get("radius",100 if kind in ["device_explosion","enemy_volatile"] else 60)),element,total,float(e.get("enemy_id",0))*.13)
	return true
