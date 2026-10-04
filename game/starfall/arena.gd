extends Node2D
## Rendering only. Damage, movement and all warning shapes belong to the simulation.
const CharacterLibrary = preload("res://scripts/character_sequence_library.gd")
const EnemyLibrary = preload("res://scripts/enemy_sequence_library.gd")
const Catalog = preload("res://starfall/catalog.gd")
const MAP = preload("res://starfall/assets/moonwell-garden.png")
const FONT = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
const GOLD = Color("efcf88")
const MINT = Color("81e0c5")
const CORAL = Color("ff849b")
const WHITE = Color("f6f5e8")
@export_range(0.6,1.2) var battle_zoom: float = 0.84
@export var particle_limit: int = 480
var sim
var characters = CharacterLibrary.new()
var monsters = EnemyLibrary.new()
var clock := 0.0
var camera := Vector2(960,640)
var zoom := 0.69
var menu := true
var reduced_fx := false
var shake_enabled := true
var shake := 0.0
var flash := 0.0
var shake_offset := Vector2.ZERO
var particles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var fallen: Array[Dictionary] = []
var trails: Dictionary = {}
var motes: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var menu_squad: Array = ["traveler","hero_03","hero_08"]
var hero_definitions: Dictionary = {}

func _ready() -> void:
	rng.seed = 6847
	for h in Catalog.heroes(): hero_definitions[h.id] = h
	for i in range(68):
		motes.append({"pos":Vector2(rng.randf_range(90,1830),rng.randf_range(170,1160)),"phase":rng.randf()*TAU,"speed":rng.randf_range(0.3,1.0),"size":rng.randf_range(1.1,2.7)})

func reset() -> void:
	particles.clear()
	effects.clear()
	numbers.clear()
	fallen.clear()
	trails.clear()
	shake = 0
	flash = 0

func warm_up(squad: Array) -> void:
	# Loading happens on the preparation screen, never on an enemy's first attack.
	for id in squad:
		for state in ["idle","run","attack","down"]:
			characters.texture(str(id),state)
			await get_tree().process_frame
	for id in ["grunt","runner","ranged","buffer","armored","splitter","boss_01"]:
		for state in ["idle","run","attack","down"]:
			monsters.texture(id,state)
			await get_tree().process_frame

func screen_to_world(p: Vector2) -> Vector2:
	return (p-Vector2(640,360)-shake_offset)/zoom+camera

func _world() -> void:
	draw_set_transform(Vector2(640,360)-camera*zoom+shake_offset,0,Vector2.ONE*zoom)

func _process(dt: float) -> void:
	clock += dt
	var target := Vector2(960,625)
	if not menu and sim!=null and not sim.heroes.is_empty():
		target = sim.heroes[sim.selected].pos.lerp(Vector2(960,640),0.36)
		var half := Vector2(640,360)/battle_zoom
		target = target.clamp(half,Vector2(1920,1280)-half)
		zoom = lerpf(zoom,battle_zoom,1.0-exp(-dt*4.0))
	else:
		zoom = lerpf(zoom,0.69,1.0-exp(-dt*4.0))
	camera = camera.lerp(target,1.0-exp(-dt*4.5))
	shake = maxf(0,shake-dt*23.0)
	flash = maxf(0,flash-dt*2.6)
	shake_offset = Vector2(rng.randf_range(-shake,shake),rng.randf_range(-shake,shake)) if shake_enabled and not reduced_fx else Vector2.ZERO
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary = particles[i]
		p.life -= dt
		if p.life<=0:
			particles.remove_at(i)
			continue
		p.pos += p.vel*dt
		p.vel *= pow(0.13,dt)
	for i in range(effects.size()-1,-1,-1):
		effects[i].life -= dt
		if effects[i].life<=0: effects.remove_at(i)
	for i in range(numbers.size()-1,-1,-1):
		numbers[i].life -= dt
		numbers[i].pos.y -= dt*31.0
		if numbers[i].life<=0: numbers.remove_at(i)
	for i in range(fallen.size()-1,-1,-1):
		fallen[i].life -= dt
		if fallen[i].life<=0: fallen.remove_at(i)
	queue_redraw()

func accept(events: Array) -> void:
	for event in events:
		var e: Dictionary = event
		var pos: Vector2 = e.get("pos",Vector2(960,640))
		var color: Color = e.get("color",GOLD)
		match str(e.get("type","")):
			"shot":
				burst(pos,color,4,65)
				if str(e.get("style",""))=="chain":
					add_effect("chain",e.get("to",pos),color,0.32,60,{"from":e.get("from",pos)})
				if str(e.get("style","")) in ["slash","blade","melee"]:
					add_effect("slash",pos,color,0.3,80,{"dir":pos.direction_to(e.get("target",e.get("to",pos+Vector2.RIGHT)))})
			"hit":
				burst(pos,color,8 if not e.get("crit",false) else 14,150)
				add_effect("impact",pos,WHITE,0.19,22)
				if numbers.size()<55:
					numbers.append({"pos":pos+Vector2(rng.randf_range(-18,18),-51),"text":str(roundi(float(e.get("amount",0)))),"color":GOLD if e.get("crit",false) else WHITE,"life":0.72,"crit":e.get("crit",false)})
			"death":
				burst(pos,color,18,205)
				add_effect("ring",pos,color,0.4,50)
				if str(e.get("owner","enemy"))=="enemy" and fallen.size()<18:
					fallen.append({"pos":pos,"kind":e.get("kind","grunt"),"life":0.72,"color":color})
			"cast":
				var target: Vector2 = e.get("target",pos)
				var effect_style: String = str(e.get("style","nova"))
				var radius: float = float(e.get("radius",145))
				if effect_style.begins_with("enemy_"):
					# Enemy tells are drawn from the live windup, including freeze and interruption.
					continue
				if effect_style=="impact":
					add_effect("ring",pos,color,0.42,radius)
					burst(pos,color,12,160)
					continue
				if effect_style in ["water_ring","wind_heal"]: target = pos
				if effect_style in ["star_blades","needles"]: target = pos+pos.direction_to(target)*45
				add_effect(effect_style,target,color,0.85,radius,{"from":pos,"dir":pos.direction_to(target)})
				add_effect("rune",pos,color,0.7,84)
				burst(target,color,38,280)
				shake = maxf(shake,4.0)
				if bool(e.get("ultimate",false)):
					flash = 0.16
					shake = 9.0
			"dash":
				burst(pos,MINT,12,120)
				add_effect("dash",pos,MINT,0.33,56,{"dir":e.get("dir",Vector2.RIGHT)})
			"heal":
				burst(pos,MINT,8,90)
				add_effect("heal",pos,MINT,0.65,40)
			"pickup": burst(pos,GOLD,4,70)
			"hurt","core_hit":
				shake = maxf(shake,4.0)
				burst(pos,CORAL,9,140)
			"boss":
				add_effect("rune",pos,CORAL,1.5,160)
				shake = 7
			"wave","level","win":
				add_effect("ring",pos,GOLD,1.0,220)
				burst(pos,GOLD,30,200)

func add_effect(kind: String, pos: Vector2, color: Color, duration: float, radius: float, data: Dictionary = {}) -> void:
	if effects.size()>=80: effects.pop_front()
	var e := {"kind":kind,"pos":pos,"color":color,"life":duration,"total":duration,"radius":radius}
	e.merge(data,true)
	effects.append(e)

func burst(pos: Vector2, color: Color, count: int, speed: float) -> void:
	if reduced_fx: count = ceili(count*0.25)
	for i in range(mini(count,particle_limit-particles.size())):
		var direction := Vector2.from_angle(rng.randf()*TAU)
		var life := rng.randf_range(0.22,0.65)
		particles.append({"pos":pos,"vel":direction*rng.randf_range(speed*0.22,speed),"life":life,"total":life,"color":color,"size":rng.randf_range(1.2,4.0),"star":i%4==0})

func _draw() -> void:
	_world()
	draw_texture_rect(MAP,Rect2(0,0,1920,1280),false)
	# The courtyard has quiet animated accents; bright effects belong to combat.
	draw_rect(Rect2(0,0,1920,1280),Color(0.018,0.04,0.09,0.11))
	_draw_well()
	for m in motes:
		var p: Vector2 = m.pos + Vector2(sin(clock*m.speed+m.phase)*16,cos(clock*m.speed*0.7+m.phase)*11)
		var col := Color(MINT,0.2+0.4*(0.5+0.5*sin(clock*1.2+m.phase)))
		_glow(p,m.size*3.0,col)
		draw_circle(p,m.size,col)
	if menu:
		_draw_menu_party()
	else:
		_draw_battle()
	_world()
	for p in particles:
		var alpha: float = clampf(p.life/p.total,0,1)
		var col: Color = p.color
		col.a = alpha
		if p.star: _star(p.pos,p.size*1.8,col,clock*2)
		else: draw_line(p.pos,p.pos-p.vel*0.04,col,p.size*alpha,true)
	for n in numbers:
		var color: Color = n.color
		color.a = minf(1.0,n.life*3)
		var fs: int = 27 if n.crit else 21
		draw_string_outline(FONT,n.pos,str(n.text),HORIZONTAL_ALIGNMENT_CENTER,60,fs,5,Color(0.035,0.05,0.10,color.a))
		draw_string(FONT,n.pos,str(n.text),HORIZONTAL_ALIGNMENT_CENTER,60,fs,color)
	draw_set_transform(Vector2.ZERO)
	if flash>0 and not reduced_fx:
		draw_rect(Rect2(0,0,1280,720),Color(0.72,0.91,1.0,flash))

func _draw_well() -> void:
	var p: Vector2 = Catalog.CORE
	var pulse := 0.65+0.2*sin(clock*2)
	draw_set_transform(Vector2(640,360)-camera*zoom+shake_offset,0,Vector2(zoom,zoom))
	draw_arc(p,70,0,TAU,64,Color(MINT,0.22),2,true)
	for i in range(3):
		draw_arc(p,81+i*7,clock*0.24+i*TAU/3,clock*0.24+i*TAU/3+0.85,24,Color(GOLD,0.26),1.4,true)
	_glow(p+Vector2(0,-18),57,Color(MINT,0.13))
	var crystal := p+Vector2(0,-37+sin(clock*1.4)*7)
	draw_colored_polygon(PackedVector2Array([crystal+Vector2(0,-27),crystal+Vector2(14,0),crystal+Vector2(0,27),crystal+Vector2(-14,0)]),Color("b5f5e0"))
	draw_colored_polygon(PackedVector2Array([crystal+Vector2(0,-27),crystal+Vector2(14,0),crystal+Vector2(0,27)]),Color("47aca9"))
	draw_line(crystal+Vector2(0,-27),crystal+Vector2(0,26),Color(WHITE,pulse),1.5,true)
	_star(crystal+Vector2(-9,-13),5,WHITE,0)

func _draw_menu_party() -> void:
	for i in range(menu_squad.size()):
		var pos := Vector2(1300+i*143,710+(60 if i==1 else 0))
		var id: String = menu_squad[i]
		var col: Color = hero_definitions[id].color
		_world()
		_glow(pos+Vector2(0,-45),125,Color(col,0.12))
		draw_arc(pos,61,0,TAU,48,Color(col,0.5),2,true)
		_actor(id,true,pos,"idle",clock+i,1.0,1.6,col,0,0)

func _draw_battle() -> void:
	if sim==null: return
	for p in sim.pickups:
		var pos: Vector2 = p.pos
		var col: Color = MINT if str(p.get("kind","xp"))=="heal" else GOLD
		var offset := Vector2(0,sin(clock*3+pos.x)*3)
		_glow(pos,11,Color(col,0.16))
		_star(pos+offset,4.5,col,clock*0.7)
	for hazard in sim.hazards: _telegraph(hazard)
	for enemy in sim.enemies:
		var cue := windup_cue(enemy)
		if not cue.is_empty(): _effect(cue)
	for e in effects: _effect(e)
	for projectile in sim.projectiles: _projectile(projectile)
	for ghost in fallen:
		_actor(str(ghost.kind),false,ghost.pos,"down",0.72-ghost.life,1.0,1.5 if ghost.kind=="boss_01" else 0.74,ghost.color,0,0)
	var actors: Array = []
	for e in sim.enemies:
		if e.hp>0: actors.append({"data":e,"hero":false})
	for h in sim.heroes: actors.append({"data":h,"hero":true})
	actors.sort_custom(func(a,b):return a.data.pos.y<b.data.pos.y)
	for entry in actors:
		var a: Dictionary = entry.data
		var hero: bool = entry.hero
		var id: String = str(a.character_id) if hero else str(a.kind)
		var col: Color = hero_definitions[id].color if hero else Color("f091a5")
		var p: Vector2 = a.pos
		if hero and sim.heroes[sim.selected].id==a.id and a.hp>0:
			_world()
			draw_arc(p,28,0,TAU,40,Color(col,0.7),2,true)
			for j in range(3):
				var pt := p+Vector2.from_angle(clock*1.8+j*TAU/3)*29
				_star(pt,3.2,Color(col,0.85),clock)
		var scale_factor := 0.85 if hero else (1.5 if id=="boss_01" else 0.74)
		_actor(id,hero,p,str(a.get("anim","idle")),float(a.get("anim_time",clock)),float(a.get("face",1.0)),scale_factor,col,float(a.get("hit_flash",0.0)),float(a.get("dash_time",0.0)))
		_world()
		if not hero and a.hp<a.max_hp:
			var w := 65.0 if id=="boss_01" else 34.0
			var y := 119.0 if id=="boss_01" else 65.0
			draw_line(p+Vector2(-w/2,-y),p+Vector2(w/2,-y),Color("0b1425"),5,true)
			draw_line(p+Vector2(-w/2,-y),p+Vector2(-w/2+w*a.hp/a.max_hp,-y),CORAL,3,true)
		if hero and a.hp<=0:
			draw_string(FONT,p+Vector2(-24,13),"倒下",HORIZONTAL_ALIGNMENT_CENTER,48,16,CORAL)
	_world()

func _actor(id: String, hero: bool, pos: Vector2, state: String, elapsed: float, face: float, factor: float, color: Color, hit: float, dash_time: float) -> void:
	var library = characters if hero else monsters
	var texture: Texture2D = library.texture(id,state)
	if texture==null: return
	var frame: int = library.frame_at_time(id,state,elapsed)
	var source: Rect2 = library.source_rect(id,state,frame)
	var cell: Vector2 = library.cell(id)
	var pivot: Vector2 = library.pivot(id)
	var size: float = library.display_size(id)*factor
	var native: float = float(library.definition(id).get("native_facing",1))
	var flip := -1.0 if face*native<0 else 1.0
	var bounce := 1.0+sin(elapsed*19)*0.025 if state=="run" else 1.0
	var squash := Vector2(1.0/bounce,bounce)
	if hit>0: squash *= Vector2(1.09,0.91)
	_world()
	draw_set_transform(Vector2(640,360)+(pos-camera)*zoom+shake_offset,0,Vector2(zoom,zoom*0.33))
	draw_circle(Vector2.ZERO,size*0.29,Color(0.02,0.025,0.055,0.38))
	var screen := Vector2(640,360)+(pos-camera)*zoom+shake_offset
	draw_set_transform(screen,0,Vector2(flip,1)*zoom*squash)
	var rect := Rect2(-pivot/cell*size,Vector2.ONE*size)
	if dash_time>0:
		for j in range(3):
			draw_texture_rect_region(texture,Rect2(rect.position+Vector2(-j*17*flip,0),rect.size),source,Color(color,0.15*(3-j)))
	draw_texture_rect_region(texture,rect,source,Color(1.0,1.0,1.0,0.55 if state=="down" else 1.0))
	if hit>0:
		# A small bright rim highlights impact without painting an opaque rectangle.
		draw_texture_rect_region(texture,rect,source,Color(1.4,1.4,1.4,minf(0.6,hit*4)))
	_world()

func _telegraph(h: Dictionary) -> void:
	var p: Vector2 = h.pos
	var total: float = maxf(0.01,float(h.get("total",1.0)))
	var remaining: float = float(h.get("remaining",total))
	var t := clampf(1.0-remaining/total,0,1)
	var r: float = float(h.get("radius",65))
	var enemy: bool = str(h.get("owner","enemy"))=="enemy"
	var col: Color = CORAL if enemy else h.get("color",MINT)
	if str(h.get("style",""))=="heal": col = MINT
	if str(h.get("style",""))=="tornado":
		_effect({"pos":p,"color":col,"life":remaining,"total":total,"radius":r,"kind":"tornado"})
		return
	var kind: String = str(h.get("kind","circle"))
	var pulse := 0.11 + pow(t,2)*0.14
	if kind=="line":
		var dir: Vector2 = h.get("dir",Vector2.RIGHT)
		var length: float = float(h.get("length",240))
		var width: float = float(h.get("width",32))
		var side := dir.orthogonal()*width*0.5
		var poly := PackedVector2Array([p-side,p+side,p+dir*length+side,p+dir*length-side])
		draw_colored_polygon(poly,Color(col,pulse))
		draw_polyline(PackedVector2Array([p-side,p+dir*length-side,p+dir*length+side,p+side]),Color(col,0.8),2,true)
		draw_line(p,p+dir*length*t,Color(col,0.5),2,true)
	elif kind=="cone":
		var dir: Vector2 = h.get("dir",Vector2.RIGHT)
		var angle := dir.angle()
		var points := PackedVector2Array([p])
		for i in range(19): points.append(p+Vector2.from_angle(angle-0.7+1.4*i/18.0)*r)
		points.append(p)
		draw_colored_polygon(points,Color(col,pulse))
		draw_polyline(points,Color(col,0.85),2,true)
	else:
		draw_circle(p,r,Color(col,pulse))
		draw_arc(p,r,0,TAU,56,Color(col,0.7),1.7,true)
		draw_arc(p,r*0.94,-PI/2,-PI/2+TAU*t,56,Color(col,0.98),3,true)
		for i in range(4):
			var dir := Vector2.from_angle(PI/4+i*PI/2)
			draw_line(p+dir*(r+5),p+dir*(r+13),Color(col,0.9),2,true)
		_star(p,5.0+t*4,col,0)

func _projectile(p: Dictionary) -> void:
	var pos: Vector2 = p.pos
	var velocity: Vector2 = p.get("vel",Vector2.RIGHT)
	var dir := velocity.normalized()
	var color: Color = p.get("color",CORAL if p.get("owner","enemy")=="enemy" else MINT)
	var radius: float = float(p.get("radius",5))
	var tail := pos-dir*clampf(velocity.length()*0.055,12,38)
	var side := dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([pos+side*radius,tail-dir*10,pos-side*radius]),Color(color,0.2))
	draw_line(tail.lerp(pos,0.2),pos,Color(color,0.5),radius*0.8,true)
	draw_line(tail.lerp(pos,0.5),pos,color,radius*0.45,true)
	_glow(pos,radius*2.7,Color(color,0.24))
	if str(p.get("style","")) in ["needle","arrow","wind","blade"]:
		draw_colored_polygon(PackedVector2Array([pos+dir*12,pos-dir*8+dir.orthogonal()*4,pos-dir*5,pos-dir*8-dir.orthogonal()*4]),WHITE)
	else:
		draw_circle(pos,radius,color)
		draw_circle(pos-dir*1.6,radius*0.44,WHITE)

func windup_cue(enemy: Dictionary) -> Dictionary:
	if enemy.hp<=0 or enemy.state!="windup": return {}
	var cue := {"kind":"enemy_aim","pos":enemy.pos,"color":CORAL,"life":enemy.state_time,"total":enemy.get("windup_duration",0.65),"radius":60.0,"dir":enemy.locked_dir,"rays":0,"spacing":0.0,"radial":false}
	if enemy.kind=="ranged":
		cue.rays = 3
		cue.spacing = 0.17
	elif enemy.kind=="boss_01":
		if enemy.pattern==2:
			cue.rays = 5+enemy.boss_phase*2
			cue.spacing = 0.13
		elif enemy.pattern==0: cue.radial = true
	return cue

func _effect(e: Dictionary) -> void:
	var p: Vector2 = e.pos
	var color: Color = e.color
	var t := clampf(1.0-float(e.life)/float(e.total),0,1)
	var a := 1.0-t
	var radius: float = e.radius
	var kind: String = e.kind
	if kind=="enemy_aim":
		draw_arc(p+Vector2(0,-32),18,0,TAU,32,Color(color,0.7),2,true)
		_star(p+Vector2(0,-60),7+4*t,Color(color,0.9),0)
		for i in range(e.rays):
			var direction: Vector2 = e.dir.rotated((i-(e.rays-1)*0.5)*e.spacing)
			draw_dashed_line(p+direction*22,p+direction*330,Color(color,0.22+0.3*t),1.4,10,true,true)
		if e.radial:
			draw_arc(p,82,0,TAU,64,Color(color,0.28+0.25*t),2,true)
			for i in range(12):
				var direction := Vector2.from_angle(i*TAU/12.0)
				draw_line(p+direction*75,p+direction*100,Color(color,0.45+0.2*t),2,true)
	elif kind=="impact":
		_star(p,radius*(0.5+t),Color(color,a),PI/4)
		_star(p,radius*(0.9+t*0.8),Color(color,a),0)
	elif kind=="slash" or kind.contains("blade") or kind.contains("needle") or kind.contains("sword"):
		var dir: Vector2 = e.get("dir",Vector2.RIGHT)
		var angle := dir.angle()
		var poly := PackedVector2Array()
		for i in range(20):
			var theta := angle-1.4+2.8*i/19.0
			poly.append(p+Vector2.from_angle(theta)*radius*(0.7+t*0.5))
		for i in range(19,-1,-1):
			var theta := angle-1.4+2.8*i/19.0
			poly.append(p+Vector2.from_angle(theta)*radius*(0.52+t*0.5))
		draw_colored_polygon(poly,Color(color,a*0.65))
		draw_arc(p,radius*(0.72+t*0.5),angle-1.4,angle+1.4,40,Color(WHITE,a),2,true)
	elif kind.contains("lightning") or kind.contains("chain") or kind.contains("thunder"):
		var from: Vector2 = e.get("from",p+Vector2(0,-180))
		var points := PackedVector2Array()
		for i in range(9):
			var point := from.lerp(p,i/8.0)
			if i>0 and i<8: point += Vector2(sin(i*17.3+floor(clock*18))*24,cos(i*7.3)*15)
			points.append(point)
		draw_polyline(points,Color(color,a*0.3),12,true)
		draw_polyline(points,Color(color,a),5,true)
		draw_polyline(points,Color(WHITE,a),1.5,true)
	elif kind.contains("wind") or kind.contains("tornado"):
		for i in range(5):
			var center := p+Vector2(sin(clock*7+i)*8,-i*15)
			draw_arc(center,radius*(0.2+i*0.13)*(0.4+t),clock*10+i,clock*10+i+4.3,40,Color(color,a*(1-i*0.1)),3,true)
	elif kind.contains("ice") or kind.contains("frost") or kind.contains("cryo"):
		for i in range(8):
			var dir := Vector2.from_angle(i*TAU/8)
			var c := p+dir*radius*minf(1,t*2)
			draw_colored_polygon(PackedVector2Array([c+dir*22,c+dir.orthogonal()*9,c-dir*14,c-dir.orthogonal()*9]),Color(color,a*0.75))
			draw_line(c-dir*12,c+dir*21,Color(WHITE,a),1.5,true)
		draw_arc(p,radius*t,0,TAU,64,Color(color,a*0.6),2,true)
	elif kind=="dash":
		var dir: Vector2 = e.get("dir",Vector2.RIGHT)
		for i in range(4):
			var offset := dir.orthogonal()*(i-1.5)*9
			draw_line(p+offset-dir*radius*(1+t),p+offset+dir*radius*t,Color(color,a*0.7),2,true)
	elif kind=="heal":
		for i in range(5):
			var c := p+Vector2(sin(i*17.0)*35,-t*55-i*8)
			draw_line(c-Vector2(5,0),c+Vector2(5,0),Color(color,a),3,true)
			draw_line(c-Vector2(0,5),c+Vector2(0,5),Color(color,a),3,true)
	elif kind=="rune":
		draw_arc(p,radius*(0.8+t*0.2),0,TAU,64,Color(color,a*0.7),2,true)
		draw_arc(p,radius*0.75,0,TAU,64,Color(color,a*0.4),1,true)
		for i in range(8):
			var dir := Vector2.from_angle(i*TAU/8+t)
			_star(p+dir*radius,6,Color(color,a),t)
	else:
		var r := radius*(1.0-pow(1-t,3))
		draw_arc(p,r,0,TAU,80,Color(color,a*0.85),maxf(1.5,8*a),true)
		draw_arc(p,r*0.82,clock,clock+4.8,64,Color(WHITE,a*0.45),2,true)
		if not reduced_fx:
			for i in range(10):
				var c := p+Vector2.from_angle(i*TAU/10+0.2)*r
				_star(c,7*a,Color(color,a),clock)

func _glow(p: Vector2, radius: float, color: Color) -> void:
	if reduced_fx: return
	for i in range(3,0,-1):
		draw_circle(p,radius*i/3.0,Color(color,color.a/(i+1)))

func _star(p: Vector2, radius: float, color: Color, angle: float) -> void:
	if radius < 0.65 or color.a < 0.02: return
	var points := PackedVector2Array()
	for i in range(8):
		points.append(p+Vector2.from_angle(angle+i*PI/4)*radius*(1.0 if i%2==0 else 0.24))
	draw_colored_polygon(points,color)
