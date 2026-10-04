extends RefCounted
const Sim = preload("res://scripts/combat_simulation.gd")
const Workshop = preload("res://scripts/workshop_session.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	print("V95 SIMULATION %s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures.append(label)

func arena():
	var s = Sim.new(9501, true)
	s.enemies.clear(); s.enemy_lookup.clear(); s.terrain_features.clear()
	var h: Dictionary = s.heroes[0]
	h.deployed = true; h.pos = Vector2(600,360); h.target = h.pos
	h.hp = 100000; h.max_hp = h.hp; h.block = 3; h.armor = 0
	return s

func enemy(s, point: Vector2, kind: String = "grunt") -> Dictionary:
	var e: Dictionary = s.spawn_enemy(point, kind)
	e.pos = point; e.route_points = [Vector2(1180,360),Vector2(100,360)]; e.route_index = 1; e.route_id = "main"
	e.tactic_cooldown = 999; e.special_timer = 999; e.hp = 100000; e.max_hp = e.hp
	e.armor = 0; e.shield = 0; e.affixes = []; e.damage = 10
	return e

func move(s, seconds: float) -> void:
	for i in ceili(seconds*60):
		for h: Dictionary in s.heroes: h.blocked = 0
		s._enemy_tick(1.0/60.0)

func crowd_case(direction: Vector2, gap: float, kind: String) -> void:
	var s = arena(); var hero: Dictionary = s.heroes[0]
	hero.pos = Vector2(600,360) if direction == Vector2.LEFT else Vector2(700,450); hero.target = hero.pos
	var route: Array[Vector2] = [hero.pos-direction*maxf(420,120+5*gap), hero.pos+direction*200]
	var starts: Array[Vector2] = []
	for i in 6:
		var e := enemy(s,hero.pos-direction*(100+i*gap),kind)
		e.route_points = route.duplicate(); starts.append(e.pos)
	var worst_backstep := 0.0
	var before: Array[Vector2] = []
	for frame in 180:
		before.clear()
		for e: Dictionary in s.enemies: before.append(e.pos)
		move(s,1.0/60.0)
		for i in s.enemies.size(): worst_backstep = maxf(worst_backstep,-(Vector2(s.enemies[i].pos)-before[i]).dot(direction))
	var label := "%s %s crowd gap %.0f" % [kind,"horizontal" if direction==Vector2.LEFT else "vertical",gap]
	check(worst_backstep < 0.01,label+" never walks backward to resolve enemy compression")
	check(s.enemies.all(func(e: Dictionary) -> bool: return e.pos.distance_to(Geometry2D.get_closest_point_to_segment(e.pos,route[0],route[1]))<1),label+" stays on authored segment")
	check(s.enemies.all(func(e: Dictionary) -> bool: return e.pos.distance_to(hero.pos)>=Sim.EnemyMelee.distance(e)-1),label+" retains hero body standoff")
	check(hero.hp < 100000,label+" front rank still attacks")
	hero.deployed = false
	var front: Vector2 = s.enemies[0].pos
	move(s,2.0)
	check((Vector2(s.enemies[0].pos)-front).dot(direction)>25,label+" resumes forward travel when blocker leaves")

func workshop() -> RefCounted:
	var w = Workshop.new()
	w.sim.terrain_features.clear()
	return w

func tick_workshop(w, seconds: float) -> void:
	for i in ceili(seconds*60): w.tick(1.0/60.0)

func cache_cases() -> void:
	var s=arena();var h:Dictionary=s.heroes[0]
	var previous:Array[Vector2]=[]
	# Rear units are created first; lane ownership cannot depend on spawn order.
	for i in range(5,-1,-1):enemy(s,h.pos+Vector2(100+i*95,0),"hilichurl_brute")
	var backstep:=0.0
	for frame in 180:
		previous.clear()
		for e:Dictionary in s.enemies:previous.append(e.pos)
		move(s,1.0/60)
		for i in s.enemies.size():backstep=maxf(backstep,float(s.enemies[i].pos.x)-previous[i].x)
	check(backstep<0.01 and h.hp<100000,"reverse spawn order preserves forward queue and front-rank strikes")
	var front:Dictionary=s.enemies[-1];var follower:Dictionary=s.enemies[-2]
	front.hp=0;var before:Vector2=follower.pos;move(s,0.5)
	check(follower.pos.x<before.x-1,"dead front rank releases the next unit's queue reservation")
	h.pos+=Vector2(0,150);h.target=h.pos;before=follower.pos;move(s,0.5)
	check(follower.pos.x<before.x-1,"moving blocker invalidates shared lane ranks on the next tick")
	s=arena();h=s.heroes[0];s.endless_mode=true
	var probe:=enemy(s,Vector2(700,360),"grunt")
	for i in 30:
		var other:=enemy(s,Vector2(500+(i%6)*97,190+int(i/6)*79),"grunt")
		other.melee_slot_pos=Vector2(other.pos)+Vector2(19,-17)
	s.enemy_crowd.begin(s.enemies);s.enemy_crowd.prepare_terrain(s)
	var body_equal:=true;var slot_equal:=true
	for i in 160:
		var from:=Vector2(520+(i*43)%610,170+(i*29)%390)
		var to:=from+Vector2(7,-3)
		s.enemy_crowd.active=false
		var body:bool=Sim.EnemyMelee._step_clear(s,probe,from,to)
		var slot:bool=Sim.EnemyMelee._available(s,probe,h,to)
		s.enemy_crowd.active=true
		body_equal=body_equal and body==Sim.EnemyMelee._step_clear(s,probe,from,to)
		slot_equal=slot_equal and slot==Sim.EnemyMelee._available(s,probe,h,to)
	check(body_equal,"indexed movement collision matches complete scan across 160 cell-boundary probes")
	check(slot_equal,"indexed reserved slots match complete scan across 160 probes")
	var moved:Dictionary=s.enemies[-1]
	moved.pos=Vector2(702,358);moved.melee_slot_pos=Vector2(713,367)
	s.enemy_crowd.update_body(moved);s.enemy_crowd.update_slot(moved)
	check(not Sim.EnemyMelee._step_clear(s,probe,Vector2(670,358),Vector2(679,358)),"body moved across cells blocks later movement in the same tick")
	check(not Sim.EnemyMelee._available(s,probe,h,moved.melee_slot_pos),"moved reservation is visible in its new cell during the same tick")
	Sim.EnemyMelee.release(moved);moved.hp=0
	s.enemy_crowd.active=false;var released:bool=Sim.EnemyMelee._available(s,probe,h,Vector2(713,367));s.enemy_crowd.active=true
	check(Sim.EnemyMelee._available(s,probe,h,Vector2(713,367))==released,"dead and released reservations never survive through cached dictionary references")
	s.enemy_crowd.finish()
	s.terrain_features.clear()
	s.terrain_features.append_array([{"type":"blocked","area":Rect2(620,220,45,190),"collision_shape":"ellipse","collision_scale":[0.8,0.9],"collision_offset":[8,-6]}, {"type":"door","area":Rect2(760,250,55,160),"hp":10}, {"type":"blocked","area":Rect2(960,250,45,80),"grid_cells":[Rect2(930,410,50,45)]}])
	s.enemy_crowd.begin(s.enemies);s.enemy_crowd.prepare_terrain(s)
	var terrain_equal:=true
	for i in 240:
		var from:=Vector2(520+(i*47)%530,170+(i*31)%320)
		var to:=from+Vector2(180-(i%7)*50,70-(i%5)*35)
		var radius:=float(i%4)*9
		s.enemy_crowd.active=false
		var point_hit:Dictionary=s._terrain_blocker_at(from,radius)
		var segment_hit:Dictionary=s._terrain_blocker_on_segment(from,to,radius)
		s.enemy_crowd.active=true
		terrain_equal=terrain_equal and point_hit==s._terrain_blocker_at(from,radius) and segment_hit==s._terrain_blocker_on_segment(from,to,radius)
	check(terrain_equal,"terrain index preserves exact ellipse/rect/grid collision and authored obstacle priority in 240 probes")
	var door:Dictionary=s.terrain_features[1]
	check(not s._terrain_blocker_at(Vector2(775,300),0).is_empty(),"closed door remains solid in cached terrain")
	door.hp=0
	check(s._terrain_blocker_at(Vector2(775,300),0).is_empty(),"door destruction removes collision immediately within the same tick")
	s.enemy_crowd.finish()
	s=arena();var pushed:=enemy(s,Vector2(900,360),"grunt")
	s.enemy_crowd.begin(s.enemies);s.enemy_crowd.prepare_terrain(s)
	s._push_enemy_grid_cells(pushed,Vector2(600,360),3)
	check(pushed.pos.x==1080 and pushed in s.enemy_crowd.nearby(Vector2(1130,360)),"real skill knockback updates body membership across multiple cells immediately")
	s.enemy_crowd.finish()

func crossing_roads_case() -> void:
	var s=Sim.new(9121,true);s.reset_stage("stage_01",["traveler"],9121)
	var crowd:Array[Dictionary]=[]
	for lane:String in s.stage_routes():
		for i in 6:crowd.append(s.spawn_on_route("ranged" if i%3==0 else "grunt",lane,i,true))
	for frame in 800:
		for h:Dictionary in s.heroes:h.blocked=0
		s._enemy_tick(0.1)
	check(crowd.all(func(e:Dictionary)->bool:return int(e.route_index)>=e.route_points.size()),"all mixed enemies cross nearby authored lanes and merged junctions without a deadlock")

func hero_overlap_recovery_case() -> void:
	for reverse:bool in [false,true]:
		var s=arena();var h:Dictionary=s.heroes[0]
		var units:Array[Dictionary]=[]
		for offset:int in ([40,0] if reverse else [0,40]):units.append(enemy(s,h.pos+Vector2(offset,0)))
		move(s,20)
		check(units.all(func(e:Dictionary)->bool:return e.pos.distance_to(h.pos)>=Sim.EnemyMelee.distance(e)-1),"hero-overlap front and rear recover their body gap (reverse=%s)"%reverse)
		check(h.hp<100000,"hero-overlap queue resumes real front attacks (reverse=%s)"%reverse)
		var rear:Dictionary=units[0] if reverse else units[1]
		var before:Vector2=rear.pos
		move(s,2)
		check(rear.pos.x<=before.x+0.01,"temporary overlap recovery never becomes continuing crowd retreat (reverse=%s)"%reverse)

func endless_manual_wall_case() -> void:
	var w=Workshop.new();w.change_map("stage_endless");w.auto_attack=false
	w.sim.terrain_features.clear()
	w.sim.terrain_features.append({"type":"blocked","area":Rect2(900,100,60,800)})
	w.sim._rebuild_endless_navigation_grid()
	w.place_hero("traveler",Vector2(400,350))
	w.place_enemy("grunt",Vector2(700,350));var e:Dictionary=w.selected()
	var goal:=Vector2(1100,350)
	check(w.move_selected(goal),"endless manual order accepts a goal beyond a long wall")
	var reached:=false;var clipped:=false;var passed_end:=false
	for frame in 3600:
		w.tick(1.0/60)
		clipped=clipped or w.sim._terrain_blocks(e.pos,17)
		passed_end=passed_end or float(e.pos.y)>918
		if e.pos.distance_to(goal)<=1:reached=true;break
	check(reached and passed_end,"endless manual order rounds the entire wall to its own goal rather than hero flow fields")
	check(not clipped,"endless manual wall detour preserves collision for every movement step")
	if reached:
		w.tick(1.0/60)
		check(not e.has("workshop_target"),"endless manual goal clears on arrival and autonomous targeting resumes")

func run(_game = null) -> int:
	cache_cases()
	crossing_roads_case()
	hero_overlap_recovery_case()
	endless_manual_wall_case()
	for direction: Vector2 in [Vector2.LEFT,Vector2.DOWN]:
		for kind: String in ["grunt","hilichurl_brute"]: crowd_case(direction,27.0,kind)
	crowd_case(Vector2.LEFT,95.0,"hilichurl_brute")
	var s = arena(); var h: Dictionary = s.heroes[0]
	var e := enemy(s,h.pos,"hilichurl_brute")
	move(s,4)
	check(e.pos.distance_to(h.pos)>=94,"overlap with hero still recovers to intentional standoff")
	var before: Vector2 = e.pos
	s._push_enemy_grid_cells(e,h.pos,1)
	check(e.pos.x>before.x+40,"real knockback can still displace enemy upstream")
	before=e.pos; move(s,0.5)
	check(e.pos.x<before.x,"knocked-back enemy resumes forward approach")
	e.pos = Vector2(850,450); e.route_index = 1
	move(s,1)
	check(absf(float(e.pos.x)-850)<1 and e.pos.y<450,"off-route skill displacement rejoins interrupted segment")
	s=arena(); e=enemy(s,h.pos+Vector2(230,0),"charger"); e.tactic_cooldown=0
	move(s,0.05)
	check(float(e.get("dash_windup",0))>0,"natural charger retains committed dash startup")
	before=e.pos; move(s,1.0)
	check(e.pos.distance_to(before)>50,"committed dash still moves through its own action")
	var w=workshop()
	check(w.auto_attack and w.enemy_action and w.sim.workshop_auto_attack and w.sim.workshop_enemy_action,"workshop defaults to live combat for both sides")
	w.auto_attack=false; w.enemy_action=false
	w.place_hero("traveler",Vector2(500,350)); h=w.selected()
	before=h.pos
	check(w.move_selected(Vector2(700,350)),"hero walking order accepted")
	check(h.pos==before and h.target==Vector2(700,350),"hero order changes destination without teleporting")
	w.tick(1.0/60)
	check(h.pos.x>before.x and h.pos.x<before.x+10 and h.moving,"hero walks at real movement speed with auto attacks disabled")
	tick_workshop(w,2)
	check(h.pos.distance_to(Vector2(700,350))<1,"hero walking order reaches its goal")
	w.place_enemy("grunt",Vector2(500,450)); e=w.selected(); before=e.pos
	check(w.move_selected(Vector2(750,450)),"enemy walking order accepted")
	check(e.pos==before,"enemy order never teleports")
	w.tick(0.1)
	check(e.pos==before,"enemy action toggle freezes its walking order")
	w.enemy_action=true; w.tick(1.0/60)
	check(e.pos.x>before.x and e.pos.x<before.x+5,"enemy walks toward manual goal before autonomous targeting")
	tick_workshop(w,8)
	check(e.pos.distance_to(h.pos)<115,"enemy resumes natural combat after manual destination")
	w=workshop(); w.invulnerable=false
	w.place_hero("traveler",Vector2(700,350)); h=w.selected(); h.hp=100000; h.max_hp=h.hp
	w.place_enemy("grunt",Vector2(360,350)); e=w.selected(); e.hp=100000; e.max_hp=e.hp
	before=e.pos; var hp:float=h.hp; var enemy_hp:float=e.hp
	tick_workshop(w,12)
	check(e.pos.x>before.x+100,"workshop enemies approach heroes in either direction instead of leaking left")
	check(h.hp<hp and e.hp<enemy_hp,"live workshop resolves both hero and enemy attacks")
	w=workshop(); w.auto_attack=false
	w.sim.terrain_features.append({"type":"blocked","area":Rect2(600,260,60,180),"hp":1000})
	w.place_enemy("grunt",Vector2(500,350)); e=w.selected()
	check(w.move_selected(Vector2(780,350)),"enemy accepts destination beyond a wall")
	var clips:=false
	for i in 1200:
		w.tick(1.0/60)
		clips=clips or w.sim._terrain_blocks(e.pos,17)
	check(not clips,"enemy walking never clips through an obstacle")
	check(e.pos.distance_to(Vector2(780,350))<2,"enemy reaches manual goal by walking around wall")
	w.enemy_action=false
	w.place_hero("traveler",Vector2(500,350)); h=w.selected()
	check(w.move_selected(Vector2(780,350)),"hero accepts destination beyond a wall")
	clips=false
	for i in 600:
		w.tick(1.0/60)
		clips=clips or w.sim._terrain_blocks(h.pos,17)
	check(not clips,"hero walking never clips through an obstacle")
	check(h.pos.distance_to(Vector2(780,350))<2,"hero reaches manual goal by walking around wall")
	w=workshop(); w.auto_attack=false
	w.place_enemy("charger",Vector2(700,350)); e=w.selected()
	e.dash_time=0.20; e.dash_direction=Vector2.LEFT; e.dash_hits=[]; e.tactic_cooldown=999
	w.move_selected(Vector2(950,350)); before=e.pos
	w.tick(0.10)
	check(e.pos.x<before.x and float(e.dash_time)>0,"manual destination does not cancel a committed dash")
	w.tick(0.11); before=e.pos; w.tick(0.05)
	check(e.pos.x>before.x,"queued enemy walking resumes after committed dash")
	e.frozen_timer=0.5; before=e.pos
	w.tick(0.2)
	check(e.pos==before,"freeze still stops a manually commanded enemy")
	tick_workshop(w,0.5)
	check(e.pos.x>before.x,"manual walking continues after freeze ends")
	before=e.pos
	check(not w.move_selected(Vector2(-100,-100)) and e.pos==before,"illegal enemy destination is rejected without relocation")
	w.place_enemy("splitter",Vector2(850,500)); e=w.selected(); before=e.pos
	check(not w.move_selected(Vector2(950,500)) and e.pos==before,"stationary structures retain their authored immobility")
	print("V95 SIMULATION COMPLETE: %d checks, %d failures" % [checks,failures.size()])
	return 0 if failures.is_empty() else 1
