extends RefCounted
const LAYOUT = preload("res://data/ui_layout_profile.tres")
const COLORS := [Color("6bddcd"),Color("ec8791"),Color("dfc183")]
static func ground(v) -> void:
	var ex = v.sim.expedition
	var landmarks := [Vector2(700,500),Vector2(2340,500),Vector2(700,1660),Vector2(2340,1660)]
	var names := ["北境观测站","赤铜兵工厂","暮色补给营","旧城档案馆"]
	for i in landmarks.size():
		var p: Vector2=v.world_to_screen(landmarks[i])
		var color: Color=[Color("698e9e"),Color("b47b68"),Color("8686a7"),Color("739789")][i]
		v.caption(p+Vector2(-80,190),names[i],Color(color,0.65),22)
	for task: Dictionary in ex.tasks:
		if task.done:continue
		var p: Vector2=v.world_to_screen(task.pos)
		var c: Color=COLORS[int(task.type)]
		v.draw_set_transform(p,0,Vector2(1,0.4))
		v.draw_circle(Vector2.ZERO,180,Color(c,0.06))
		v.draw_arc(Vector2.ZERO,180,0,TAU,48,Color(c,0.45),2,true)
		v.draw_arc(Vector2.ZERO,184,-PI/2,-PI/2+TAU*clampf(float(task.progress)/float(task.target),0.001,1),48,c,4,true)
		v.draw_set_transform(Vector2.ZERO)
		v.draw_circle(p,22,Color("171b2b"));v.draw_arc(p,22,0,TAU,16,c,3,true)
		v.caption(p+Vector2(-6,6),str(int(task.type)+1),c,18)
		v.caption(p+Vector2(-45,-35),str(task.name),c,15)
		if int(task.type)==2:
			for shard: Dictionary in task.shards:
				if shard.taken:continue
				var q: Vector2=v.world_to_screen(shard.pos)
				v.draw_colored_polygon(PackedVector2Array([q+Vector2(0,-14),q+Vector2(12,0),q+Vector2(0,14),q+Vector2(-12,0)]),c)
	for i in 128:
		var a: Vector2=ex.safe_center+Vector2.from_angle(i*TAU/128)*Vector2(ex.safe_radius,ex.safe_radius*0.4)
		var b: Vector2=ex.safe_center+Vector2.from_angle((i+1)*TAU/128)*Vector2(ex.safe_radius,ex.safe_radius*0.4)
		if v.visible_world_rect().grow(100).has_point(a):v.draw_line(v.world_to_screen(a),v.world_to_screen(b),Color("ee6c84"),5,true)
static func overlay(v) -> void:
	var ex = v.sim.expedition
	var player: Dictionary=ex.leader(v.sim)
	if not player.is_empty() and ex.ground_distance(Vector2(player.pos),ex.safe_center)>ex.safe_radius:
		v.caption(Vector2(448,132),"风暴侵蚀 · 向安全区移动",Color("ff8594"),22)
	var r: Rect2=LAYOUT.battle_expedition_tasks_rect
	v.draw_rect(r,Color(0.035,0.045,0.075,0.9))
	v.draw_line(r.position,r.position+Vector2(0,r.size.y),Color("b56578"),3)
	v.caption(r.position+Vector2(12,23),"猩红远征  /  %s %ds" % [ex.phase_name,ceili(ex.phase_remaining)],Color("f1ccd0"),14)
	for i in ex.tasks.size():
		var t: Dictionary=ex.tasks[i]
		var text := "%d  %s  %d/%d" % [int(t.type)+1,t.name,ceili(t.progress),int(t.target)]
		if not t.done and not player.is_empty(): text += "  %dm" % int(Vector2(player.pos).distance_to(t.pos)/10)
		if t.done:text="已完成 · 新任务 %ds" % ceili(t.cooldown)
		v.caption(r.position+Vector2(12,49+i*24),text,COLORS[int(t.type)],13)
		if not t.done:
			var p: Vector2=v.world_to_screen(t.pos)
			var q := p.clamp(Vector2(325,110),Vector2(1010,546))
			if p.distance_to(q)>15:
				var direction:Vector2=(p-q).normalized()
				v.draw_colored_polygon(PackedVector2Array([q+direction*24,q+direction*12+direction.orthogonal()*7,q+direction*12-direction.orthogonal()*7]),COLORS[int(t.type)])
				v.draw_circle(q,12,Color("202637"));v.caption(q+Vector2(-4,5),str(int(t.type)+1),COLORS[int(t.type)],13)
	v.caption(r.position+Vector2(12,132),"靠近接取 · 完成连选三张 · 累计 %d" % ex.completed,Color("aaa9b8"),11)
	var m: Rect2=LAYOUT.battle_expedition_minimap_rect
	v.draw_rect(m.grow(5),Color("111626"));v.draw_rect(m,Color("242536"))
	var arena: Rect2=v.sim.ENDLESS_ARENA
	var scale: Vector2=m.size/arena.size
	for wall: Dictionary in v.sim.terrain_features:
		var a: Rect2=wall.area
		v.draw_rect(Rect2(m.position+(a.position-arena.position)*scale,a.size*scale),Color("646171"))
	for i in 64:
		var a: Vector2=m.position+(ex.safe_center+Vector2.from_angle(i*TAU/64)*Vector2(ex.safe_radius,ex.safe_radius*0.4)-arena.position)*scale
		var b: Vector2=m.position+(ex.safe_center+Vector2.from_angle((i+1)*TAU/64)*Vector2(ex.safe_radius,ex.safe_radius*0.4)-arena.position)*scale
		if m.has_point(a) and m.has_point(b):v.draw_line(a,b,Color("f17c90"),1.5)
	var n: Vector2=m.position+(ex.next_center-arena.position)*scale
	v.draw_circle(n,3,Color("a18faa"))
	for task: Dictionary in ex.tasks:
		if not task.done:v.draw_circle(m.position+(Vector2(task.pos)-arena.position)*scale,3.5,COLORS[int(task.type)])
	for enemy: Dictionary in v.sim.enemies:
		v.draw_circle(m.position+(Vector2(enemy.pos)-arena.position)*scale,1,Color("bf526c"))
	for hero: Dictionary in v.sim.heroes:
		if hero.hp>0:v.draw_circle(m.position+(Vector2(hero.pos)-arena.position)*scale,3,Color("ffffff"))
	v.caption(m.position+Vector2(0,-12),"远征地图 / 白点：队伍",Color("bcb7ca"),11)

	var warning:float=v.sim.endless_next_boss_at-v.sim.elapsed
	if warning<=10.0 and warning>0:
		preload("res://scripts/endless_boss_warning.gd").draw(v,warning)
	elif ex.completion_notice>0:
		var banner:Rect2=LAYOUT.battle_expedition_completion_rect
		v.draw_rect(banner,Color(0.04,0.12,0.15,0.94))
		v.draw_line(banner.position,banner.position+Vector2(banner.size.x,0),Color("79dfcd"),3)
		v.caption(banner.position+Vector2(20,30),"任务完成 / "+ex.completion_name,Color("a2eee0"),21)
		v.caption(banner.position+Vector2(20,57),"获得三次选卡 · 全员恢复18%生命",Color("d3e6de"),15)
