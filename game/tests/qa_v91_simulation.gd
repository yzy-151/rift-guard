extends SceneTree
const Sim = preload("res://scripts/combat_simulation.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS " + label)

func distance_to_route(point: Vector2, route: Array) -> float:
	var best := INF
	for i in range(1, route.size()):
		best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point, route[i-1], route[i])))
	return best

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for stage in range(1, 9):
		var s = Sim.new(9100 + stage, true)
		s.reset_stage("stage_%02d" % stage, ["traveler"], 9100 + stage)
		for route_id: String in s.stage_routes():
			for sequence in 3:
				s.enemies.clear(); s.enemy_lookup.clear()
				var route: Array = s.stage_route(route_id)
				var e: Dictionary = s.spawn_on_route("grunt", route_id, sequence, true)
				check(e.route_points == route, "%02d %s/%d movement and paint share route" % [stage,route_id,sequence])
				var worst := 0.0
				for frame in 500:
					s._enemy_tick(0.1)
					worst = maxf(worst, distance_to_route(e.pos,route))
					if int(e.route_index) >= route.size(): break
				check(worst <= 1.0, "%02d %s/%d ground stays on road (%.1f)" % [stage,route_id,sequence,worst])
				check(int(e.route_index) >= route.size(), "%02d %s/%d reaches exit without stalling" % [stage,route_id,sequence])
	var s = Sim.new(9191, true)
	s.reset_stage("stage_03", ["traveler"], 9191)
	s.terrain_features.clear()
	var e: Dictionary = s.spawn_on_route("grunt", "main", 0, true)
	var route: Array = e.route_points
	e.pos = Vector2(route[0]).lerp(route[1],0.5) + Vector2(50,50)
	for frame in 100: s._enemy_tick(0.1)
	check(distance_to_route(e.pos,route) <= 1.0, "displaced ground unit returns to route")
	check(s.has_method("endless_layout_options"), "endless layout selection API exists")
	check(s.has_method("endless_forecast"), "endless growth forecast API exists")
	check(s.has_method("ability_preview_geometry"), "shared skill geometry API exists")
	var deliveries := {}
	for id in ["traveler","hero_01","hero_02","hero_03","hero_04","hero_06","hero_07","hero_08","hero_10","hero_13"]:
		var a = Sim.new(9192,true)
		if id != "traveler": a._add_reinforcement(id)
		var hero: Dictionary = a.heroes[-1]
		check(hero.has("attack_delivery"), id+" has an explicit delivery mechanism")
		deliveries[str(hero.get("attack_delivery","missing"))] = true
	check(deliveries.size() >= 5, "ten heroes cover at least five attack mechanisms")
	test_geometry_and_attacks()
	test_endless()
	test_enemy_commitments()
	print("V91 SIMULATION: checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)

func arena(id: String):
	var s=Sim.new(9193,true)
	s.terrain_features.clear()
	if id!="traveler": s._add_reinforcement(id)
	for hero: Dictionary in s.heroes: hero.deployed=false
	var h: Dictionary=s.heroes[-1]
	h.deployed=true; h.pos=Vector2(400,360); h.target=h.pos; h.crit_chance=0.0
	h.splash=false; h.blast_radius=0.0; h.chain_count=0; h.echo_ratio=0.0; h.element=""
	return s

func dummy(s,point: Vector2) -> Dictionary:
	var e: Dictionary=s.spawn_enemy(point,"grunt")
	e.pos=point; e.hp=10000.0; e.max_hp=e.hp; e.armor=0; e.shield=0; e.speed=0; e.affixes=[]
	return e

func test_geometry_and_attacks() -> void:
	var s=arena("hero_04")
	var h: Dictionary=s.heroes[-1]
	var cross: Dictionary=s.ability_preview_geometry(h,h.ultimate,Vector2(650,360))
	check(s.is_in_skill_geometry(cross,Vector2(800,360)),"cross includes horizontal arm")
	check(s.is_in_skill_geometry(cross,Vector2(650,500)),"cross includes vertical arm")
	check(not s.is_in_skill_geometry(cross,Vector2(760,470)),"cross excludes empty corner")
	check(not s.is_in_skill_geometry(cross,Vector2(985,360)),"base cross does not reach beyond its declared arm")
	s.run_state.equipped_relics["relic_resonant_core"]=true
	var relic_cross: Dictionary=s.ability_preview_geometry(h,h.ultimate,Vector2(650,360))
	check(s.is_in_skill_geometry(relic_cross,Vector2(985,360)),"resonant core expands the shared ultimate preview")
	var relic_victim=dummy(s,Vector2(985,360))
	s._execute_ability_impact(h,h.ultimate,Vector2(650,360),true)
	check(relic_victim.hp<10000,"resonant core expands actual noncircular ultimate damage")
	s.run_state.equipped_relics.clear();s.enemies.clear();s.events.clear();s.skill_effects.clear()
	var locked_start: Vector2=h.pos
	s._queue_ability(h,h.active_skill,Vector2(650,360),false)
	h.pos=Vector2(400,490)
	s._pending_impact_tick(1.0)
	var release: Array=s.events.filter(func(event: Dictionary)->bool:return event.kind=="skill_geometry")
	check(not release.is_empty() and Vector2(release[-1].geometry.origin)==locked_start,"cast direction remains committed when caster moves during anticipation")
	h.pos=locked_start
	var on=dummy(s,Vector2(550,360)); var ahead=dummy(s,Vector2(650,360)); var side=dummy(s,Vector2(550,450))
	Sim.HeroSignature.launch_attack(s,h,on,100,false)
	for i in 8: s._projectile_tick(0.1)
	check(on.hp<10000 and ahead.hp==10000 and side.hp==10000,"V93 unupgraded water lance hits one target without bending")
	for card_bonus in [0,1]:
		s=arena("hero_04"); h=s.heroes[-1]; h.pierce=card_bonus
		var row: Array[Dictionary]=[]
		for distance in [70,110,150,190]: row.append(dummy(s,Vector2(400+distance,360)))
		Sim.HeroSignature.launch_attack(s,h,row[0],100,false)
		for i in 8:s._projectile_tick(0.1)
		check(row.filter(func(enemy: Dictionary)->bool:return enemy.hp<10000).size()==1+card_bonus,"V93 piercing card increases actual hit capacity (%d)"%card_bonus)
	s=arena("hero_04"); h=s.heroes[-1]; on=dummy(s,Vector2(650,360))
	Sim.HeroSignature.launch_attack(s,h,on,100,false)
	on.pos=Vector2(650,470)
	for i in 8: s._projectile_tick(0.1)
	check(on.hp==10000,"locked straight shot can be evaded after launch")
	s=arena("hero_03"); h=s.heroes[-1]; on=dummy(s,Vector2(600,360))
	Sim.HeroSignature.launch_attack(s,h,on,100,false)
	s._projectile_tick(0.3)
	check(on.hp==10000,"lob does not damage before reaching its locked ground point")
	on.pos=Vector2(600,500)
	s._projectile_tick(0.4)
	check(on.hp==10000,"moving away avoids lob splash")
	s=arena("hero_02"); h=s.heroes[-1]; on=dummy(s,Vector2(550,360))
	Sim.HeroSignature.launch_attack(s,h,on,100,false)
	for i in 30: s._projectile_tick(0.05)
	check(is_equal_approx(float(on.hp),9900.0),"V93 wind blade cannot gain a free return hit")
	s=arena("hero_07"); h=s.heroes[-1]; on=dummy(s,Vector2(560,360))
	Sim.HeroSignature.launch_attack(s,h,on,100,false)
	check(s.projectiles.size()==1,"V93 music attack starts with one fixed ray")
	s=arena("hero_13"); h=s.heroes[-1]; on=dummy(s,Vector2(510,360))
	s._hero_tick()
	check(not s.pending_impacts.is_empty() and on.hp==10000,"scissor cone waits for the attack hit frame")
	on.pos=Vector2(290,360)
	s._pending_impact_tick(1.0)
	check(on.hp==10000,"moving behind the fixed cone avoids scissor damage")
	for id in ["traveler","hero_01","hero_02","hero_03","hero_04","hero_06","hero_07","hero_08","hero_10","hero_13"]:
		s=arena(id); h=s.heroes[-1]
		on=dummy(s,Vector2(540,360))
		h.hp=float(h.max_hp)*0.6
		for ultimate in [false,true]:
			s._execute_ability_impact(h,s.hero_ability(int(h.id),ultimate),Vector2(550,360),ultimate)
		for i in 40: s._skill_effect_tick(0.1)
		check(s.events.any(func(event: Dictionary)->bool:return event.kind=="skill_geometry" and event.character_id==id),id+" actual skill release exposes shared footprint")
		check(h.hp>0,"%s survives own normal skill sequence" % id)

func test_endless() -> void:
	var s=Sim.new(9194,true)
	var signatures: Dictionary={}
	for option: Dictionary in s.endless_layout_options():
		check(s.select_endless_layout(option.id),"layout accepted "+str(option.id))
		s.reset_stage("stage_endless",["traveler"],9194)
		signatures[str(s.terrain_features)]=true
		check(s.terrain_features.size()>3 and not s._terrain_blocks(s.heroes[0].pos,17),"layout loads actual terrain and safe start "+str(option.id))
		check(not option.preview_regions.is_empty(),"layout preview comes from terrain "+str(option.id))
	check(signatures.size()==3,"three layouts have different playable obstacle fields")
	s.start()
	check(s.drain_events().filter(func(event: Dictionary)->bool:return event.kind=="deploy").size()==1,"endless opening publishes entry feedback for each deployed hero")
	s.start()
	check(not s.drain_events().any(func(event: Dictionary)->bool:return event.kind=="deploy"),"repeated start cannot replay entry feedback")
	s.elapsed=75; s._endless_pacing_tick()
	check(s.endless_forecast().warning and s.events.any(func(event: Dictionary)->bool:return event.kind=="endless_warning"),"boss advance warns fifteen seconds ahead")
	s.heroes[0].hp=100.0; s.heroes[0].energy=0.0; s.elapsed=83
	s._endless_pacing_tick(); var hp: float=s.heroes[0].hp; s._endless_pacing_tick()
	check(hp>100 and s.heroes[0].hp==hp and s.heroes[0].energy==15.0,"each phase supplies once with bounded recovery")
	s.enemies.clear(); s.endless_spawn_timer=0; s._endless_spawn_tick(0.1)
	check(s.enemies.is_empty(),"eight-second supply window suspends reinforcement pressure")
	var snapshot: Dictionary=s.export_run_snapshot()
	var restored=Sim.new(9195,true); restored.reset_stage("stage_endless",["traveler"],9195); restored.import_run_snapshot(snapshot)
	check(restored.endless_layout_id=="wind_cross","inherited endless build keeps chosen layout")
	s.endless_objectives.objective_index=5; s.contract_completed=true; s.endless_objectives.next_at=s.elapsed
	s._contract_tick()
	check(s.combat_contract.metric=="zone_hold","objective rotation includes a physical supply point")
	s.heroes[0].pos=s.combat_contract.zone_pos
	for i in 65:
		s.elapsed+=0.2; s._contract_tick()
	check(s.contract_completed,"supply objective completes through real time inside its circle")

func test_enemy_commitments() -> void:
	var s=arena("traveler")
	var h: Dictionary=s.heroes[0]
	h.armor=0; h.hp=10000; h.max_hp=10000
	var charger: Dictionary=s.spawn_enemy(Vector2(640,360),"charger")
	charger.tactic_cooldown=0.0
	Sim.EnemyTactics.tick(s,charger,0.01)
	check(float(charger.get("dash_windup",0.0))>0,"charger commits a visible windup before charging")
	h.pos=Vector2(400,500)
	for i in 30: Sim.EnemyTactics.tick(s,charger,0.05)
	check(h.hp==10000,"sidestepping evades a committed charge")
	var brute: Dictionary=s.spawn_enemy(Vector2(500,500),"hilichurl_brute")
	brute.tactic_cooldown=0.0
	Sim.EnemyTactics.tick(s,brute,0.01)
	check(float(brute.get("spin_windup",0.0))>0,"brute warns before a bounded spin attack")
	var hp: float=h.hp
	for i in 40: Sim.EnemyTactics.tick(s,brute,0.05)
	check(h.hp<hp,"remaining in brute spin takes periodic contact damage")
	charger=s.spawn_enemy(Vector2(640,500),"charger");charger.tactic_cooldown=0.0
	Sim.EnemyTactics.tick(s,charger,0.01)
	var delay: float=charger.dash_windup
	charger.frozen_timer=2.0
	Sim.EnemyTactics.tick(s,charger,0.5)
	check(charger.dash_windup==delay,"freeze pauses the committed dash warning")
	s=Sim.new(9196,true)
	s.reset_stage("stage_03",["traveler"],9196);s.terrain_features.clear()
	charger=s.spawn_on_route("charger","main",0,true)
	var road: Array=charger.route_points
	h=s.heroes[0];h.deployed=true;h.pos=Vector2(charger.pos)+Vector2(-90,90);h.max_hp=10000;h.hp=10000
	charger.tactic_cooldown=0.0
	for i in 20: s._enemy_tick(0.1)
	h.deployed=false
	for i in 120: s._enemy_tick(0.1)
	check(distance_to_route(charger.pos,road)<=1.0,"committed charge rejoins its original road segment")
	var boss: Dictionary=s.spawn_on_route("boss_02","main",0,true)
	boss.pos=Vector2(road[1])+Vector2(0,65);boss.special_timer=999;boss.attack_timer=999
	for i in 80:s._enemy_tick(0.1)
	check(distance_to_route(boss.pos,road)<=1.0,"boss landing displacement rejoins the painted route")
	var minion: Dictionary=s.spawn_enemy(boss.pos+Vector2(0,30),"runner")
	s._inherit_enemy_route(minion,boss)
	check(minion.route_points==road and minion.route_index==boss.route_index,"summoned ground units inherit route and progress")
