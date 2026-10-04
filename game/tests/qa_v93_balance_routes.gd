extends SceneTree
const Sim = preload("res://scripts/combat_simulation.gd")
const Runtime = preload("res://scripts/stages/stage_runtime.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func arena(id: String = "traveler"):
	var s = Sim.new(9304, true)
	var squad: Array[String] = ["traveler"]
	if id != "traveler": squad.append(id)
	s.reset_stage("stage_01", squad, 9304)
	s.enemies.clear(); s.enemy_lookup.clear(); s.terrain_features.clear(); s.events.clear()
	for h: Dictionary in s.heroes:
		h.deployed = str(h.character_id) == id; h.pos = Vector2(500,360); h.target = h.pos
		h.hp = 100000; h.max_hp = h.hp; h.crit_chance = 0; h.element = ""; h.secondary_element = ""
		h.attack_timer = 0; h.heal_timer = 999
	return s
func owner(s) -> Dictionary:
	for h: Dictionary in s.heroes:
		if h.deployed: return h
	return {}
func enemy(s, point: Vector2, kind: String = "grunt") -> Dictionary:
	var e: Dictionary = s.spawn_enemy(point, kind)
	e.pos = point; e.hp = 100000; e.max_hp = e.hp; e.armor = 0; e.shield = 0
	e.special_timer = 999; e.tactic_cooldown = 999; e.burrow_new = false
	e.route_points = [Vector2(1180,360),Vector2(100,360)]; e.route_index = 1
	return e
func projectiles(s, duration: float = 2.0) -> void:
	for i in ceili(duration / 0.02):
		s.elapsed += 0.02; s._pending_impact_tick(0.02); s._projectile_tick(0.02)
func move_enemies(s, duration: float) -> void:
	for i in ceili(duration / 0.05):
		for h: Dictionary in s.heroes: h.blocked = 0
		s._enemy_tick(0.05)
func card(s, id: String) -> Dictionary:
	for c: Dictionary in s.database.cards:
		if str(c.id)==id:return c
	return {}
func run() -> void:
	var source = Sim.new(9304,true)
	for id: String in source.database.characters:
		var s = arena(id); var h := owner(s)
		var melee := id in ["traveler","hero_13"]
		check(float(h.range) >= (110 if melee else 210) and float(h.range) <= (120 if melee else 280), id + " reduced world range %.0f" % h.range)
		for p: Vector2 in [Vector2(565,360),Vector2(590,360),Vector2(575,373)]: enemy(s,p)
		s._hero_tick(); projectiles(s)
		check(s.enemies.filter(func(e: Dictionary)->bool:return e.hp < 100000).size() == 1, id + " unupgraded attack damages exactly one enemy")
		check(int(h.projectile_count)==1 and int(h.pierce)==0 and int(h.chain_count)==0 and not h.splash and not h.cleave and float(h.blast_radius)==0, id + " multi-target growth starts locked")
	var s = arena("hero_01"); var h := owner(s)
	for p: Vector2 in [Vector2(580,360),Vector2(635,360),Vector2(690,360),Vector2(740,360)]: enemy(s,p)
	s.apply_v2_card_effect(card(s,"v75_armor_piercing_round"), int(h.id))
	s._hero_tick(); projectiles(s,0.04)
	check(s.enemies.all(func(e: Dictionary)->bool:return e.hp==100000), "piercing waits for real projectile travel")
	projectiles(s)
	check(s.enemies.filter(func(e:Dictionary)->bool:return e.hp<100000).size()==2,"one pierce card unlocks exactly one extra hit")
	check((100000.0-s.enemies[1].hp)<(100000.0-s.enemies[0].hp),"pierced hit has damage falloff")
	s=arena("hero_01"); h=owner(s)
	for p: Vector2 in [Vector2(580,360),Vector2(615,395),Vector2(660,410)]: enemy(s,p)
	s.apply_v2_card_effect(card(s,"v75_arc_enchantment"),int(h.id));s._hero_tick();projectiles(s,0.15)
	check(s.enemies[1].hp==100000,"bounce transfer travels rather than instantly damaging neighbors")
	projectiles(s)
	check(s.enemies[1].hp<100000 and s.enemies[2].hp==100000,"first bounce card adds one transfer")
	check((100000.0-s.enemies[1].hp)<(100000.0-s.enemies[0].hp),"bounce transfer loses damage")
	s=arena("hero_01");h=owner(s);h.pierce=1;h.chain_count=1
	enemy(s,Vector2(580,360));enemy(s,Vector2(615,395));s._hero_tick();projectiles(s)
	check(is_equal_approx((100000.0-s.enemies[1].hp)/(100000.0-s.enemies[0].hp),0.65),"unused pierce budget does not reduce an actual bounce hit")
	s=arena("hero_01");h=owner(s)
	for i in 20:
		s.apply_v2_card_effect(card(s,"v75_multishot_training"),int(h.id));s.apply_v2_card_effect(card(s,"v75_armor_piercing_round"),int(h.id));s.apply_v2_card_effect(card(s,"v75_arc_enchantment"),int(h.id));s.apply_v2_card_effect(card(s,"single_range_legendary"),int(h.id))
	check(int(h.projectile_count)<=4 and int(h.pierce)<=3 and int(h.chain_count)<=3,"mixed upgrade caps: 4 projectiles / 3 pierces / 3 bounces")
	check(float(h.range)<=float(source.database.characters["hero_01"].attack_range)*1.6,"range card growth capped at 160 percent base")
	s=arena("hero_01");h=owner(s)
	for p:Vector2 in [Vector2(570,360),Vector2(585,400),Vector2(615,410)]:enemy(s,p)
	s.apply_v2_card_effect(card(s,"v75_multishot_training"),int(h.id));s._hero_tick();projectiles(s)
	check(s.enemies.filter(func(e:Dictionary)->bool:return e.hp<100000).size()==2,"one multishot card actually damages two targets")
	check(is_equal_approx((100000.0-s.enemies[1].hp)/(100000.0-s.enemies[0].hp),0.60),"additional projectile deals exactly 60 percent damage")
	s=arena();h=owner(s)
	for p:Vector2 in [Vector2(570,360),Vector2(585,370),Vector2(600,380)]:enemy(s,p)
	s.apply_v2_card_effect(card(s,"v75_armor_piercing_round"),int(h.id));s._hero_tick();projectiles(s)
	check(s.enemies.filter(func(e:Dictionary)->bool:return e.hp<100000).size()==2,"pierce card unlocks one extra melee target")
	check(is_equal_approx((100000.0-s.enemies[1].hp)/(100000.0-s.enemies[0].hp),0.75),"melee cleave uses the same 75 percent transfer")
	s=arena();h=owner(s);h.pierce=1;h.chain_count=1
	enemy(s,Vector2(570,360));var air:=enemy(s,Vector2(590,365),"flyer");s._hero_tick();projectiles(s)
	check(air.hp==100000,"neutral melee cannot hit flying targets through pierce or bounce upgrades")
	for id:String in ["hero_04","traveler"]:
		s=arena(id);h=owner(s)
		s.terrain_features.append({"type":"high_ground","area":Rect2(470,330,60,60),"range_bonus":1.0})
		var far:=enemy(s,Vector2(h.pos)+Vector2(float(h.range)*1.5,0))
		s._hero_tick();projectiles(s)
		check(far.hp<100000,id+" high-ground basic reaches its displayed effective range")
	s=arena();h=owner(s);h.chain_count=1
	var first:=enemy(s,Vector2(570,360));enemy(s,Vector2(585,375))
	for i in s.performance_budget.MAX_PROJECTILES:s.projectiles.append({"marker":i,"hit_ids":[],"chain_count":0})
	var budget_size:int=s.projectiles.size()
	s.BasicAttacks.resolve_melee(s,{"target_id":first.id,"damage":100.0,"element":"","critical":false},h)
	check(s.projectiles.size()==budget_size and not s.projectiles[-1].has("extras_used"),"full projectile budget cannot mutate another shot during melee bounce")
	for id: String in ["traveler","hero_13"]:
		s=arena(id);h=owner(s);var e:=enemy(s,h.pos+Vector2(96,0),"hilichurl_brute")
		s._hero_tick();projectiles(s)
		check(e.hp<100000,id+" short melee reaches brute body spacing")
	s=arena("hero_13");s.endless_mode=true;h=owner(s);h.pos=Vector2(900,700);h.target=h.pos
	for direction:Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		check(s.is_in_attack_range(h,h.pos+direction*96),"endless short melee covers body spacing direction %s"%direction)
		check(not s.is_in_attack_range(h,h.pos+direction*125),"endless short melee excludes distant direction %s"%direction)
	s=arena();h=owner(s);h.pos=Vector2(700,455);h.target=h.pos
	var e:=enemy(s,Vector2(900,360));e.speed=70
	move_enemies(s,5.0)
	check(absf(float(e.pos.y)-360)<1 and e.pos.x<650,"campaign ignores off-road hero while marching")
	s=arena();h=owner(s);h.pos=Vector2(600,360);h.target=h.pos;e=enemy(s,Vector2(850,450));e.speed=70
	move_enemies(s,1)
	check(absf(float(e.pos.x)-850)<1 and absf(float(e.pos.y)-380)<1,"displaced enemy rejoins its interrupted segment before approaching a lane blocker")
	s=arena();h=owner(s);h.pos=Vector2(600,360);h.target=h.pos
	var crowd:Array[Dictionary]=[]
	for i in 8: crowd.append(enemy(s,Vector2(830+i*52,360)))
	move_enemies(s,14.0)
	var min_gap:=INF
	for a in crowd.size():
		check(absf(float(crowd[a].pos.y)-360)<1,"campaign queue %d stays on road"%a)
		for b in range(a+1,crowd.size()):min_gap=minf(min_gap,Vector2(crowd[a].pos).distance_to(crowd[b].pos))
	print("QUEUE ",crowd.map(func(c:Dictionary)->Vector2:return c.pos))
	check(min_gap>=38,"campaign waiting crowd preserves body spacing: %.2f"%min_gap)
	check(h.hp<100000,"actual lane blocker takes front-rank melee damage")
	h.pos+=Vector2(0,150);h.target=h.pos;move_enemies(s,4)
	check(crowd[0].pos.x<600 and absf(float(crowd[0].pos.y)-360)<1,"moving blocker away resumes interrupted route")
	s=arena();h=owner(s);h.pos=Vector2(600,360);h.target=h.pos;crowd=[]
	var bend:Array[Vector2]=[Vector2(1180,260),Vector2(720,260),Vector2(720,360),Vector2(100,360)]
	for i in 8:
		var queued:=enemy(s,Vector2(1100-i*48,260));queued.route_points=bend.duplicate();queued.speed=80;crowd.append(queued)
	move_enemies(s,14)
	var worst:=0.0;min_gap=INF
	for a in crowd.size():
		var distance:=INF
		for j in range(1,bend.size()):distance=minf(distance,Vector2(crowd[a].pos).distance_to(Geometry2D.get_closest_point_to_segment(crowd[a].pos,bend[j-1],bend[j])))
		worst=maxf(worst,distance)
		for b in range(a+1,crowd.size()):min_gap=minf(min_gap,Vector2(crowd[a].pos).distance_to(crowd[b].pos))
	check(worst<=1 and min_gap>=38,"campaign queue follows corners without road extrapolation or overlap (%.1f / %.1f)"%[worst,min_gap])
	s=arena();h=owner(s);h.pos=Vector2(700,500);h.target=h.pos;e=enemy(s,Vector2(850,360),"charger");e.tactic_cooldown=0
	move_enemies(s,0.1)
	check(float(e.get("dash_windup",0))==0,"campaign charger does not charge an off-road hero")
	s=arena();h=owner(s);h.pos=Vector2(700,500);h.target=h.pos;e=enemy(s,Vector2(850,360),"hilichurl_brute")
	var speed:float=e.speed;move_enemies(s,0.05)
	check(e.speed==speed and speed<40,"brute stays heavy and slow near heroes")
	var bucket:Dictionary=s.spawn_enemy(Vector2(950,360),"armored");move_enemies(s,0.1)
	check(not bool(bucket.get("burrow_new",false)) and float(bucket.get("burrow_timer",0))==0 and bucket.speed<40 and bucket.armor>=90,"bucket zombie uses slow armored walking")
	for stage in range(1,9):
		s=Sim.new(9304,true);s.reset_stage("stage_%02d"%stage,["traveler"],9304)
		var added:=0;var clear:=true
		for f:Dictionary in s.terrain_features:
			if not str(f.get("id","")).begins_with("v93_obstacle_"):continue
			added+=1
			for route:Array in s.stage_routes().values():
				for j in range(1,route.size()):
					if s._segment_hits_rect(route[j-1],route[j],Rect2(f.area).grow(48)):clear=false
			for device:Dictionary in s.terrain_features:
				if str(device.get("type","")) in ["relay","spring","wind_lane","hazard_lane","mechanism"]:
					if Rect2(f.area).grow(16).intersects(device.area) or (device.has("effect_area") and Rect2(f.area).grow(16).intersects(device.effect_area)):clear=false
			check(s._terrain_blocks(Rect2(f.area).get_center(),16),"stage %d added obstacle has real collision"%stage)
		check(added>=2 and clear,"stage %d meaningful added obstacles clear all roads and devices"%stage)
	var runtime=Runtime.new({"waves":[{"at":5,"count":3,"interval":0.5,"route_ids":["upper","lower"],"enemy_id":"grunt"}],"boss_at_seconds":999})
	var warnings:Array=runtime.tick(2).filter(func(v:Dictionary)->bool:return v.kind=="route_warning")
	check(warnings.size()==2 and int(warnings[0].count)==2 and int(warnings[1].count)==1,"alternating wave preview gives exact per-route counts")
	check(warnings.size()==2 and int(warnings[0].get("wave",0))==1,"route preview identifies the actual wave")
	runtime=Runtime.new({"waves":[{"at":9,"count":1,"route_id":"main","enemy_id":"grunt"}],"breather_windows":[[0,10]],"boss_at_seconds":999})
	warnings=runtime.tick(7).filter(func(v:Dictionary)->bool:return v.kind=="route_warning")
	check(warnings.size()==1 and float(warnings[0].lead_time)>=3,"breather-delayed wave preview remains until its actual spawn time")
	s=Sim.new(9304,true);s.reset_stage("stage_01",["traveler"],9304);s.events.clear();s._stage_spawn_tick(2.0)
	var painted:Array=s.events.filter(func(v:Dictionary)->bool:return v.kind=="route_warning")
	check(not painted.is_empty() and painted.all(func(v:Dictionary)->bool:return v.get("points",[])==s.stage_route(str(v.route_id)) and v.get("pos",Vector2.ZERO)==s.stage_route(str(v.route_id))[0]),"preview contains the exact normalized spawn entrance and route")
	for kind:String in ["rift_bat","troop_cannon"]:
		s=arena();var definition:Dictionary=s.stage_runtime.definition.duplicate(true)
		definition.waves=[{"at":3.0,"interval":0.2,"count":1,"route_id":"main","enemy_id":kind}];definition.boss_at_seconds=999
		s.stage_runtime=Runtime.new(definition);s.events.clear();s._stage_spawn_tick(0.1)
		painted=s.events.filter(func(v:Dictionary)->bool:return v.kind=="route_warning")
		s._stage_spawn_tick(3.0);s._troop_spawn_tick(10.0)
		check(painted.size()==1 and int(painted[0].unit_count)==s.enemies.size(),kind+" warning group count matches actual spawned units")
	s=arena()
	for i in 4:s.spawn_on_route("shielded","main",i)
	check(s.enemies.all(func(v:Dictionary)->bool:return v.kind=="shielded"),"campaign authored enemy kind cannot be silently replaced by endless quotas")
	print("V93 balance/routes: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
