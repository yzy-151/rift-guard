extends RefCounted
## Field objectives, grounded terminals and poster HUD share simulation geometry.
const LAYOUT = preload("res://data/ui_layout_profile.tres")
const PROFILE = preload("res://data/stage_profiles/endless_arena_profile.gd")
const FONT = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
const TERMINALS = preload("res://assets/world/endless_20261006/field_terminals.png")
const CHEST = preload("res://assets/world/endless/gate_chest_h.png")
const PAPER := Color("fff4df")
const INK := Color("111318")
const RED := Color("e51e49")
const COLORS := [Color("78cfdf"),Color("ef9b69"),Color("8ad8b1"),Color("e6c07e")]
const HELP := ["进入信标区，累计驻守30秒","在任务区域内击败30名敌人","靠近金色箱子，拾取3份补给","撑过75秒，保持队伍存活","击败6名重甲或大型敌人","击败1名首领，额外领取两次选卡","击败12名弓手、萨满或远程兵","按数字顺序到达3个据点"]
const TERMINAL_ANCHORS := [Vector2(.52,.65),Vector2(.485,.65),Vector2(.52,.50),Vector2(.485,.50)]

static func ink(v,p: Vector2,text: String,color: Color = PAPER,size: int = 14) -> void:
	v.draw_string(FONT,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

static func ellipse(v,p: Vector2,radius: float,color: Color,progress: float = -1.0) -> void:
	v.draw_set_transform(p,0,Vector2(1,.4))
	v.draw_circle(Vector2.ZERO,radius,Color(color,.035))
	v.draw_arc(Vector2.ZERO,radius,0,TAU,48,Color(color,.38),1.5,true)
	if progress >= 0:
		v.draw_arc(Vector2.ZERO,radius,-PI*.5,-PI*.5+TAU*clampf(progress,.001,1),48,color,3,true)
	v.draw_set_transform(Vector2.ZERO)

static func terminal(v,p: Vector2,index: int,extent: float = 182.0,opacity: float = 1.0) -> void:
	var half: Vector2 = TERMINALS.get_size()*.5
	var source := Rect2(Vector2(index%2,index/2)*half,half)
	var target := Rect2(p-TERMINAL_ANCHORS[index]*extent,Vector2.ONE*extent)
	v.draw_texture_rect_region(TERMINALS,target,source,Color(1,1,1,opacity))

static func destination(ex,task: Dictionary,player: Dictionary) -> Vector2:
	if int(task.type) not in [2,7]: return Vector2(task.pos)
	var result := Vector2(task.pos)
	var distance := INF
	for shard: Dictionary in task.shards:
		if shard.taken: continue
		if int(task.type)==7: return Vector2(shard.pos)
		var d: float = ex.ground_distance(Vector2(player.get("pos",task.pos)),Vector2(shard.pos))
		if d < distance: result=shard.pos; distance=d
	return result

static func ground(v) -> void:
	var ex = v.sim.expedition
	var player: Dictionary = ex.leader(v.sim)
	var visible: Rect2 = v.visible_world_rect().grow(190)
	for index in PROFILE.DISTRICTS.size():
		var district: Dictionary = PROFILE.DISTRICTS[index]
		if not visible.has_point(district.center): continue
		var p: Vector2 = v.world_to_screen(district.center)
		var dim := .45 if index==2 and (float(ex.field_station.get("cooldown",0))>0 or str(ex.field_station.get("status",""))=="风暴封锁") else 1.0
		terminal(v,p,index,182,dim)
		v.combat_caption(p+Vector2(-67,61),str(district.name),Color(COLORS[index],.85),15)
	var station: Dictionary = ex.field_station
	if not station.is_empty() and visible.has_point(station.pos):
		var p: Vector2 = v.world_to_screen(station.pos)
		var available: bool = float(station.cooldown)<=0 and str(station.status)!="风暴封锁"
		var progress := float(station.charge)/maxf(1,float(station.hold_seconds))
		ellipse(v,p,float(station.radius),COLORS[2] if available else Color("677874"),progress if progress>0 else -1)
		var text := "驻守5秒  /  恢复20%"
		if float(station.notice)>0: text="生命恢复20%% · 冷却%ds" % ceili(station.cooldown)
		elif float(station.cooldown)>0: text="医疗冷却 %ds" % ceili(station.cooldown)
		elif float(station.charge)>0: text="驻守 %.1f / 5秒" % float(station.charge)
		elif str(station.status)=="风暴封锁": text="风暴封锁 · 暂不可用"
		elif str(station.status)=="生命充足": text="医疗终端 · 生命充足"
		v.combat_caption(p+Vector2(-80,84),text,COLORS[2] if available else Color("b4bbb4"),13)
	for task: Dictionary in ex.tasks:
		if task.done or int(task.type) in [3,4,5,6]: continue
		var p: Vector2 = v.world_to_screen(task.pos)
		var color: Color = COLORS[int(task.type)%4]
		if int(task.type) in [0,1] and visible.has_point(task.pos):
			ellipse(v,p,180 if int(task.type)==0 else 400,color,float(task.progress)/float(task.target))
			v.combat_caption(p+Vector2(-42,-55),str(task.name),color,15)
		if int(task.type) in [2,7]:
			var target: Vector2 = destination(ex,task,player)
			for index in task.shards.size():
				var shard: Dictionary = task.shards[index]
				if shard.taken or not visible.has_point(shard.pos): continue
				var q: Vector2 = v.world_to_screen(shard.pos)
				if int(task.type)==2:
					v.draw_set_transform(q,0,Vector2(1,.4)); v.draw_circle(Vector2.ZERO,25,Color(0,0,0,.32)); v.draw_set_transform(Vector2.ZERO)
					v.draw_texture_rect(CHEST,Rect2(q-Vector2(18,47),Vector2(36,50)),false)
					v.combat_caption(q+Vector2(-29,-57),"补给 %d/3" % (index+1),COLORS[3],14)
				else:
					var current: bool = Vector2(shard.pos)==target
					v.draw_colored_polygon(PackedVector2Array([q+Vector2(-17,0),q+Vector2(0,-7),q+Vector2(17,0),q+Vector2(0,7)]),Color(COLORS[3],.55 if current else .15))
					v.draw_circle(q-Vector2(0,26),13,INK)
					ink(v,q+Vector2(-4,-21),str(index+1),COLORS[3] if current else Color("82877c"),15)
				if Vector2(shard.pos)==target: v.combat_caption(q+Vector2(-29,24),"走近拾取" if int(task.type)==2 else "下一站",PAPER,12)
	for index in 96:
		var a: Vector2 = ex.safe_center+Vector2.from_angle(index*TAU/96)*Vector2(ex.safe_radius,ex.safe_radius*.4)
		var b: Vector2 = ex.safe_center+Vector2.from_angle((index+1)*TAU/96)*Vector2(ex.safe_radius,ex.safe_radius*.4)
		if visible.has_point(a):
			v.draw_line(v.world_to_screen(a),v.world_to_screen(b),Color("7a233b",.38),16,true)
			v.draw_line(v.world_to_screen(a),v.world_to_screen(b),Color("f15578",.9),3,true)

static func panel(v,r: Rect2) -> void:
	v.draw_rect(Rect2(r.position+Vector2(4,5),r.size),Color(0,0,0,.4))
	v.draw_rect(r,Color(.035,.04,.055,.96))
	v.draw_rect(r,Color("51464b"),false,1)
	v.draw_rect(Rect2(r.position,Vector2(4,r.size.y)),RED)

static func overlay(v) -> void:
	var ex = v.sim.expedition
	var player: Dictionary = ex.leader(v.sim)
	var r: Rect2 = LAYOUT.battle_expedition_tasks_rect
	panel(v,r)
	v.draw_rect(Rect2(r.position,Vector2(r.size.x,29)),RED)
	ink(v,r.position+Vector2(12,20),"远征任务  /  OBJECTIVES",PAPER,16)
	for index in ex.tasks.size():
		var task: Dictionary = ex.tasks[index]
		var row := r.position+Vector2(12,45+index*64)
		var color: Color = COLORS[int(task.type)%4]
		ink(v,row,str(task.name)+"   %d/%d" % [mini(int(task.target),ceili(task.progress)),int(task.target)],Color("88998d") if task.done else PAPER,15)
		var helper: String = "已完成 · 等待下一批" if task.done else HELP[int(task.type)]
		ink(v,row+Vector2(0,18),helper,Color("d1c9ba"),11)
		var reward: String = ex.reward_text(task)
		ink(v,row+Vector2(0,36),reward,color,12)
		if not task.done and int(task.type) not in [3,4,5,6]:
			var target: Vector2 = destination(ex,task,player)
			ink(v,row+Vector2(188,35),"%dm" % int(ex.ground_distance(Vector2(player.get("pos",target)),target)/10),Color("b9b4a9"),11)
			arrow(v,target,index+1,color)
		if task.done: v.draw_rect(Rect2(row+Vector2(0,43),Vector2(r.size.x-24,2)),Color("7d9b85"))
	if ex.reward_waiting_level>0:
		ink(v,r.position+Vector2(12,165),"任务选卡已保留 · Lv.%d领取" % ex.reward_waiting_level,Color("ffd46f"),12)
	ink(v,r.position+Vector2(12,185),"下一批 %ds · 已完成 %d" % [maxi(0,ceili(ex.next_tasks_at-v.sim.elapsed)),ex.completed],Color("a59b92"),12)
	minimap(v,ex)
	if not player.is_empty() and ex.ground_distance(Vector2(player.pos),ex.safe_center)>ex.safe_radius:
		var warning := LAYOUT.battle_expedition_guide_rect
		panel(v,warning)
		ink(v,warning.position+Vector2(16,29),"风暴侵蚀 · 返回安全区",Color("ff889e"),21)
		ink(v,warning.position+Vector2(16,55),"沿小地图红色边界向内移动",PAPER,14)
	var boss_time: float = v.sim.endless_next_boss_at-v.sim.elapsed
	if boss_time>0 and boss_time<=10:
		preload("res://scripts/endless_boss_warning.gd").draw(v,boss_time)
	elif ex.completion_notice>0:
		var banner: Rect2 = LAYOUT.battle_expedition_completion_rect
		panel(v,banner); v.draw_rect(Rect2(banner.position,Vector2(6,banner.size.y)),Color("9bd6b3"))
		ink(v,banner.position+Vector2(18,30),"任务完成  /  "+str(ex.completion_name),PAPER,21)
		ink(v,banner.position+Vector2(18,58),str(ex.completion_reward),Color("9bd6b3"),15)
	elif v.sim.elapsed < 9:
		var guide: Rect2 = LAYOUT.battle_expedition_guide_rect
		panel(v,guide)
		ink(v,guide.position+Vector2(16,28),"移动探索 · 战斗中也能自动攻击",PAPER,20)
		ink(v,guide.position+Vector2(16,54),"WASD / 右键走位   1/2/3换领队   X同行 / C坚守",Color("ddc7b4"),13)

static func arrow(v,target: Vector2,number: int,color: Color) -> void:
	var p: Vector2 = v.world_to_screen(target)
	var q: Vector2 = p.clamp(Vector2(315,116),Vector2(1030,534))
	if p.distance_to(q)<16: return
	var direction := (p-q).normalized()
	v.draw_colored_polygon(PackedVector2Array([q+direction*23,q+direction*10+direction.orthogonal()*7,q+direction*10-direction.orthogonal()*7]),color)
	v.draw_circle(q,13,INK)
	ink(v,q+Vector2(-4,5),str(number),color,14)

static func minimap(v,ex) -> void:
	var m: Rect2 = LAYOUT.battle_expedition_minimap_rect
	panel(v,m.grow(4))
	v.draw_rect(m,Color("262a30"))
	var arena: Rect2 = PROFILE.ARENA
	var scale: Vector2 = m.size/arena.size
	for road: Rect2 in PROFILE.CORRIDORS:
		v.draw_rect(Rect2(m.position+(road.position-arena.position)*scale,road.size*scale),Color("3b3e42"))
	for index in PROFILE.DISTRICTS.size():
		var district: Dictionary = PROFILE.DISTRICTS[index]
		v.draw_rect(Rect2(m.position+(district.area.position-arena.position)*scale,district.area.size*scale),Color("43464c"))
		var q: Vector2 = m.position+(Vector2(district.center)-arena.position)*scale
		v.draw_circle(q,2,COLORS[index])
	for wall: Dictionary in v.sim.terrain_features:
		var a: Rect2 = wall.area
		v.draw_rect(Rect2(m.position+(a.position-arena.position)*scale,a.size*scale),Color("96989c"))
	for index in 64:
		var a: Vector2 = m.position+(ex.safe_center+Vector2.from_angle(index*TAU/64)*Vector2(ex.safe_radius,ex.safe_radius*.4)-arena.position)*scale
		var b: Vector2 = m.position+(ex.safe_center+Vector2.from_angle((index+1)*TAU/64)*Vector2(ex.safe_radius,ex.safe_radius*.4)-arena.position)*scale
		if m.has_point(a) and m.has_point(b): v.draw_line(a,b,Color("f4728f"),1.5,true)
	for task: Dictionary in ex.tasks:
		if task.done or int(task.type) in [3,4,5,6]: continue
		var target: Vector2 = destination(ex,task,ex.leader(v.sim))
		var p: Vector2 = m.position+(target-arena.position)*scale
		v.draw_circle(p,3.5,COLORS[int(task.type)%4])
	for enemy: Dictionary in v.sim.enemies:
		if enemy.hp<=0: continue
		var boss: bool = str(enemy.kind).begins_with("boss_")
		v.draw_circle(m.position+(Vector2(enemy.pos)-arena.position)*scale,2.8 if boss else 1,Color("ff3859") if boss else Color("b9636d"))
	var view: Rect2 = v.visible_world_rect().intersection(arena)
	v.draw_rect(Rect2(m.position+(view.position-arena.position)*scale,view.size*scale),Color("d7d2bd",.48),false,1)
	for hero: Dictionary in v.sim.heroes:
		if hero.hp>0:
			var p: Vector2 = m.position+(Vector2(hero.pos)-arena.position)*scale
			if int(hero.id)==v.sim._resolve_follow_leader_id(): v.draw_circle(p,4.5,INK); v.draw_circle(p,3.2,Color("ffda75"))
			else: v.draw_circle(p,2.3,PAPER)
	ink(v,m.position+Vector2(6,16),"猩红远征",PAPER,13)
	ink(v,m.position+Vector2(6,m.size.y-8),"%s  %ds" % [ex.phase_name,ceili(ex.phase_remaining)],Color("d1c5b7"),12)
