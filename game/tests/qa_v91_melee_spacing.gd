extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func arena():
	var s=Sim.new(9118,true)
	s.reset_stage("stage_01",["traveler"],9118)
	s.terrain_features.clear();s.enemies.clear();s.enemy_lookup.clear()
	var h:Dictionary=s.heroes[0]
	h.deployed=true;h.pos=Vector2(600,360);h.target=h.pos;h.hp=100000;h.max_hp=h.hp;h.armor=0;h.block=3
	s.crystal_shield=0
	return s
func spawn(s,kind: String,pos:Vector2) -> Dictionary:
	var e:Dictionary=s.spawn_enemy(pos,kind)
	e.pos=pos;e.route_points=[Vector2(1050,360),Vector2(100,360)];e.route_index=1;e.route_id="main"
	e.speed=100.0;e.special_timer=999;e.tactic_cooldown=999;e.burrow_new=false;e.damage=10
	return e
func step(s,frames:int) -> void:
	for i in frames:
		for h:Dictionary in s.heroes:h.blocked=0
		s._enemy_tick(0.05)
func run() -> void:
	for kind:String in ["grunt","runner","armored","charger","shielded","originium_bug","hilichurl_brute"]:
		var s=arena();var h:Dictionary=s.heroes[0]
		var e=spawn(s,kind,Vector2(850,360))
		step(s,120)
		var spacing:float=Vector2(e.pos).distance_to(h.pos)
		check(spacing>=59.0 and spacing<=110.0,kind+" stops one body away: %.2f"%spacing)
		check(h.hp<100000,kind+" deals real melee damage from the stand-off point")
		var anchor:Vector2=e.pos
		step(s,40)
		check(Vector2(e.pos).distance_to(anchor)<0.5,kind+" holds a stable attack position")
	var s=arena();var h:Dictionary=s.heroes[0]
	var crowd:Array[Dictionary]=[]
	for i in 8:crowd.append(spawn(s,"grunt",Vector2(830+i*7,335+i*7)))
	var worst_backstep:=0.0
	for frame in 260:
		var before:Array[Vector2]=[]
		for unit:Dictionary in crowd:before.append(unit.pos)
		step(s,1)
		for i in crowd.size():worst_backstep=maxf(worst_backstep,float(crowd[i].pos.x)-before[i].x)
	var nearest:=INF
	for a in crowd.size():
		check(Vector2(crowd[a].pos).distance_to(h.pos)>=59.0,"crowd member %d avoids hero overlap"%a)
		for b in range(a+1,crowd.size()):nearest=minf(nearest,Vector2(crowd[a].pos).distance_to(crowd[b].pos))
	# The fixture intentionally starts 7px apart. V95 preserves its queue
	# without forcing rear bodies upstream to manufacture full separation.
	check(nearest>=6.9 and worst_backstep<0.01,"overlapping spawn queue adds no compression or backward walking: %.2f"%nearest)
	check(h.hp<100000,"front rank attacks while excess melee enemies wait")
	var spaced=arena();var regular:Array[Dictionary]=[]
	for i in 8:regular.append(spawn(spaced,"grunt",Vector2(680+i*48,360)))
	step(spaced,260)
	var regular_gap:=INF
	for a in regular.size():
		for b in range(a+1,regular.size()):regular_gap=minf(regular_gap,Vector2(regular[a].pos).distance_to(regular[b].pos))
	check(regular_gap>=38,"normally separated crowd preserves body spacing: %.2f"%regular_gap)
	var e:Dictionary=crowd[0]
	h.deployed=false
	step(s,30)
	check(absf(float(e.pos.y)-360.0)<1.0,"disengaged enemy returns to its interrupted road")
	s=arena();h=s.heroes[0];e=spawn(s,"grunt",h.pos)
	step(s,30)
	check(Vector2(e.pos).distance_to(h.pos)>=59.0,"overlapping spawn recovers through movement")
	s=arena();h=s.heroes[0];e=spawn(s,"charger",h.pos+Vector2(290,0));e.tactic_cooldown=0.0
	step(s,55)
	check(Vector2(e.pos).distance_to(h.pos)>=63.0,"charge landing rebuilds melee separation")
	s=arena();h=s.heroes[0];e=spawn(s,"boss_02",Vector2(850,360))
	step(s,50);e.pos=h.pos
	step(s,40)
	check(Vector2(e.pos).distance_to(h.pos)>=100.0,"boss jump landing reacquires a safe melee position")
	s=arena();h=s.heroes[0];e=spawn(s,"grunt",h.pos+Vector2(64,0))
	step(s,12)
	var health:float=h.hp
	h.pos+=Vector2(0,170);h.target=h.pos
	step(s,18)
	check(h.hp==health,"moving beyond committed contact range dodges a normal swing")
	s=arena();h=s.heroes[0];e=spawn(s,"ranged",Vector2(830,360))
	step(s,10)
	check(Vector2(e.pos).distance_to(h.pos)>200.0,"ranged enemies keep their original ranged stopping distance")
	s=arena();h=s.heroes[0];e=spawn(s,"hilichurl_brute",h.pos);e.tactic_cooldown=0.0
	step(s,1)
	check(float(e.get("spin_windup",0.0))==0.0,"brute cannot start spinning inside a hero body")
	step(s,30)
	check(Vector2(e.pos).distance_to(h.pos)>=94.0 and (float(e.get("spin_windup",0.0))>0.0 or float(e.get("spin_time",0.0))>0.0),"brute establishes its body spacing before spinning")
	s=arena();s.reset_stage("stage_endless",["traveler","hero_04","hero_08"],9118)
	s.terrain_features.clear();s._rebuild_endless_navigation_grid();s.enemies.clear();s.enemy_lookup.clear();s.active_view_rect=s.ENDLESS_ARENA
	h=s.heroes[0];h.pos=s.ENDLESS_ARENA.get_center();h.target=h.pos;h.hp=100000;h.max_hp=h.hp
	for i in [1,2]:s.heroes[i].pos=h.pos+Vector2(0,180.0*i);s.heroes[i].target=s.heroes[i].pos;s.heroes[i].hp=100000;s.heroes[i].max_hp=100000
	crowd=[]
	for i in 12:
		e=spawn(s,"grunt",h.pos+Vector2.from_angle(i*TAU/12)*330.0);crowd.append(e)
	step(s,240)
	var closest_hero:=INF
	nearest=INF
	for a in crowd.size():
		for ally:Dictionary in s.heroes:closest_hero=minf(closest_hero,Vector2(crowd[a].pos).distance_to(ally.pos))
		for b in range(a+1,crowd.size()):nearest=minf(nearest,Vector2(crowd[a].pos).distance_to(crowd[b].pos))
	check(closest_hero>=59.0,"endless three-hero crowd keeps body spacing: %.2f"%closest_hero)
	check(nearest>=38.0,"endless crowd does not collapse onto shared attack points: %.2f"%nearest)
	check(s.heroes.any(func(ally:Dictionary)->bool:return ally.hp<100000),"endless front ranks still land real attacks")
	print("V91 MELEE SPACING: checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
