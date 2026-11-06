extends SceneTree
const Sim = preload("res://scripts/combat_simulation.gd")
var checks := 0
var failures: Array[String] = []
var observations := {}
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("BOTANY QA: " + label)
func _initialize() -> void:
	_caps()
	_types_and_occupancy()
	_bursts_and_transformations()
	_ground_and_economy()
	_melon_and_slow()
	_live_modifiers()
	_projectiles_and_lifecycle()
	var path := ProjectSettings.globalize_path("res://../qa/botany-20261005/mechanics.json")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): path = arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations}, "\t"))
	output.close()
	print("BOTANY MECHANICS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _sim(stage: String = "stage_02"):
	var sim = Sim.new(51058, true)
	sim.reset_stage(stage, ["traveler"], 51058)
	sim.state = "running"
	sim.terrain_features.clear()
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	sim.skill_effects.clear()
	sim.pending_impacts.clear()
	sim.geo_constructs.clear()
	sim.battle_devices.gold = 100000
	for hero: Dictionary in sim.heroes:
		hero.deployed = false
		hero.pos = Vector2(250,200)
		hero.target = hero.pos
	sim.drain_events()
	return sim
func _enemy(sim, point: Vector2) -> Dictionary:
	var enemy: Dictionary = sim.spawn_enemy(point, "grunt")
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	enemy.armor = 0.0
	enemy.shield = 0.0
	enemy.affixes = []
	enemy.aura = ""
	enemy.intrinsic_element = ""
	enemy.aura_timer = 0.0
	enemy.speed = 0.0
	enemy.damage = 50.0
	enemy.rate = 5.0
	enemy.attack_timer = 0.0
	enemy.special_timer = 1000.0
	enemy.route_points = []
	return enemy
func _place(sim, kind: String, point: Vector2 = Vector2(430,360)) -> Dictionary:
	check(sim.battle_devices.select(sim,kind), kind + " selects")
	check(sim.battle_devices.place(sim,point), kind + " deploys")
	return sim.battle_devices.placed[-1]
func _cards(sim, values: Dictionary) -> void:
	for id: String in values: sim.run_state.buff_levels[id] = values[id]
	sim.battle_devices.sync_modifiers(sim)
func _caps() -> void:
	for index in range(1,9):
		var sim = _sim("stage_%02d" % index)
		var d = sim.battle_devices
		check(d.limit == 25 and sim.run_state.device_cards_enabled, "stage_%02d supports 25 devices and relevant card pool" % index)
		for slot in 25:
			var point := Vector2(250 + (slot % 5) * 60, 200 + (slot / 5) * 40)
			d.select(sim,"power")
			check(d.place(sim,point), "stage_%02d accepted slot %02d" % [index,slot+1])
		var gold: int = d.gold
		check(d.active_count() == 25 and not d.select(sim,"range") and d.gold == gold, "stage_%02d rejects purchase 26 without charge" % index)
		d.selected_kind = "range"
		check(not d.place(sim,Vector2(610,400)) and d.gold == gold, "stage_%02d rejects direct placement 26" % index)
		d.placed[0].hp = 0.0
		d.tick(sim,.001)
		d.cancel()
		check(d.active_count() == 24 and d.select(sim,"range") and d.place(sim,Vector2(610,400)), "stage_%02d frees slot after destruction" % index)
	observations.stage_caps = {"stages":8,"limit":25,"rejected_next":26}
func _types_and_occupancy() -> void:
	var sim = _sim()
	var d = sim.battle_devices
	check(d.ITEMS.size() == 10, "ten distinct device kinds exist")
	var index := 0
	for kind: String in d.ITEMS:
		var plant := _place(sim,kind,Vector2(250 + index * 60, 360))
		check(plant.cell.size == sim.GRID_CELL_SIZE and plant.pos == plant.cell.get_center(), kind + " occupies exactly one logical cell")
		if kind in d.BLOCKING_PLANTS:
			check(sim.geo_constructs.has(plant) and plant.device, kind + " shares live damageable construct")
			var before: Vector2 = sim.heroes[0].pos
			check(not sim.deploy_hero(0,plant.pos) and sim.heroes[0].pos == before, kind + " existing plant rejects reverse hero deployment without moving the hero")
		else:
			check(not sim.geo_constructs.has(plant), kind + " remains a traversable ground device")
			check(sim.deploy_hero(0,plant.pos) and sim.heroes[0].pos == plant.pos, kind + " ground effect still permits actual hero deployment")
		index += 1
	check(d.active_count() == 10 and sim.geo_constructs.size() == 5, "ten kinds retain five physical plants and five ground effects")
	d.select(sim,"power")
	check(not d.place(sim,Vector2(250,360)), "no second device on occupied cell")
	var hero: Dictionary = sim.heroes[0]
	hero.deployed = true
	hero.pos = Vector2(850,440)
	d.selected_kind = "sunflower"
	check(not d.place(sim,hero.pos), "standing plant cannot replace a live hero")
	d.selected_kind = "mine"
	check(d.place(sim,hero.pos), "ground mine can coexist with hero")
	var enemy := _enemy(sim,Vector2(910,440))
	d.selected_kind = "melon"
	check(not d.place(sim,enemy.pos), "physical plant cannot be placed on enemy")
	d.selected_kind = "mine"
	check(d.place(sim,enemy.pos), "unarmed mine can be placed beneath enemy")
func _bursts_and_transformations() -> void:
	for variant: String in ["pea","repeater","threepeater","gatling","melon"]:
		var sim = _sim()
		var d = sim.battle_devices
		var plant := _place(sim,"pea")
		var card_id: String = str({"repeater":"device_repeater", "threepeater":"device_threepeater", "gatling":"device_gatling", "melon":"device_melon"}.get(variant, ""))
		if not card_id.is_empty(): _cards(sim,{card_id:1})
		var enemy := _enemy(sim,Vector2(1090,360))
		d.tick(sim,.36)
		var first_count: int = d.shots.size()
		check(plant.visual_variant == variant, variant + " applies to an existing pea")
		check(first_count == (3 if variant == "threepeater" else 1), variant + " releases initial volley")
		if variant == "threepeater":
			var lanes: Array[int] = []
			for shot: Dictionary in d.shots:
				lanes.append(int(shot.muzzle_lane))
				check(shot.visual_origin == plant.pos and shot.visual_variant == variant and shot.model_origin.y == plant.pos.y + shot.muzzle_lane * sim.GRID_CELL_SIZE.y, "threepeater mouth lane matches fixed model row")
			check(lanes == [-1,0,1], "threepeater has three distinct mouth lanes")
		if variant in ["repeater","gatling"]:
			d.tick(sim,.10)
			check(d.shots.size() == 1, variant + " does not stack entire burst on launch")
			d.tick(sim,.03)
			check(d.shots.size() == 2, variant + " second shot releases after 120 ms")
			if variant == "gatling":
				d.tick(sim,.12)
				d.tick(sim,.12)
				check(d.shots.size() == 4 and plant.burst_queue.is_empty(), "gatling releases four separately timed peas")
		var future := _place(sim,"snowpea",Vector2(550,440))
		check(future.visual_variant == ("snowpea" if variant == "pea" else variant), variant + " applies to future snow pea")
		if not d.shots.is_empty():
			var shot: Dictionary = d.shots[0]
			check(shot.direction == Vector2.RIGHT and shot.visual_origin == plant.pos and shot.visual_time > 0.0 and shot.has("muzzle_lane"), variant + " freezes actual launch pose metadata")
		if variant == "melon":
			check(d.shots[0].target == enemy.pos and d.shots[0].arc_height > 0.0, "melon stores fixed landing target and arc height")
	var sim = _sim()
	var plant := _place(sim,"pea")
	_cards(sim,{"device_repeater":1,"device_threepeater":1,"device_gatling":1,"device_melon":1})
	check(plant.visual_variant == "melon", "upgrade priority melon > gatling > threepeater > repeater")
func _ground_and_economy() -> void:
	var sim = _sim()
	var d = sim.battle_devices
	var mine := _place(sim,"mine")
	var target := _enemy(sim,mine.pos)
	d.tick(sim,2.99)
	check(mine.hp > 0.0 and not mine.armed and target.hp == 100000.0, "potato mine waits its full three-second fuse")
	d.tick(sim,.02)
	check(mine.hp == 0.0 and is_equal_approx(target.hp,100000.0 - 495.0), "armed mine damages and consumes on first ground contact")
	check(d.active_count() == 0, "potato consumption frees deployment slot")
	var events := sim.drain_events()
	check(events.filter(func(e: Dictionary) -> bool: return e.kind == "device_explosion").size() == 1, "potato emits one filled explosion event")
	sim = _sim()
	d = sim.battle_devices
	var cherry := _place(sim,"cherry")
	target = _enemy(sim,cherry.pos)
	d.tick(sim,.99)
	check(cherry.hp > 0.0 and target.hp == 100000.0, "cherry keeps one-second fuse")
	d.tick(sim,.02)
	check(cherry.hp == 0.0 and is_equal_approx(target.hp,100000.0-710.0), "cherry explodes on fixed countdown without contact")
	sim = _sim()
	d = sim.battle_devices
	var spike := _place(sim,"spikeweed")
	target = _enemy(sim,spike.pos)
	var flying := _enemy(sim,spike.pos)
	flying.flying = true
	d.tick(sim,.01)
	var first_hp: float = target.hp
	d.tick(sim,.5)
	check(target.hp < first_hp and flying.hp == 100000.0 and spike.hp > 0.0, "spikes repeatedly hurt ground foes and spare flying foes")
	sim = _sim()
	d = sim.battle_devices
	var sun := _place(sim,"sunflower")
	var gold: int = d.gold
	d.tick(sim,7.99)
	check(d.gold == gold, "sunflower does not produce sun early")
	d.tick(sim,.02)
	check(d.gold == gold+20, "sunflower generates exactly 20 gold at eight seconds")
	_cards(sim,{"device_photosynthesis":3,"device_quick_growth":3})
	var remaining: float = sun.timer
	check(remaining < 8.0 and remaining > 5.0, "growth card accelerates current production timer immediately")
	d.tick(sim,remaining+.01)
	check(d.gold == gold+55, "photosynthesis makes next sun 35 gold")
func _melon_and_slow() -> void:
	var sim = _sim()
	var d = sim.battle_devices
	var plant := _place(sim,"melon")
	var enemy := _enemy(sim,Vector2(910,360))
	var splash := _enemy(sim,Vector2(940,360))
	var distant := _enemy(sim,Vector2(1090,440))
	d.tick(sim,.36)
	check(d.shots.size() == 1 and d.shots[0].kind == "melon", "melon device launches its arcing projectile")
	var shot: Dictionary = d.shots[0]
	var landing: Vector2 = shot.target
	enemy.pos = Vector2(1120,500)
	d.tick(sim,float(shot.flight_total)-float(shot.flight_time)+.01)
	check(shot.target == landing and enemy.hp == 100000.0, "melon never homes after target walks away")
	check(splash.hp < 100000.0 and distant.hp == 100000.0 and d.shots.is_empty(), "melon damages only fixed landing area and is cleaned up")
	var events := sim.drain_events()
	check(events.any(func(e: Dictionary) -> bool: return e.kind == "device_melon_hit"), "melon splash emits dedicated impact event")
	for ice: bool in [true,false]:
		sim = _sim()
		d = sim.battle_devices
		_place(sim,"snowpea" if ice else "pea")
		if not ice: _cards(sim,{"device_frost":1})
		enemy = _enemy(sim,Vector2(790,360))
		d.tick(sim,.36)
		d.tick(sim,.35)
		check(enemy.hp < 100000.0 and is_equal_approx(float(enemy.get("device_slow_timer",0)),2.0) and is_equal_approx(float(enemy.get("device_slow_scale",1)),.8), "snow pea or frost card applies two-second 20% slow")
		enemy.speed = 100.0
		var before: Vector2 = enemy.pos
		sim._enemy_tick(.1)
		check(is_equal_approx(before.distance_to(enemy.pos),8.0), "ice-pea slow changes actual enemy movement to 80%")
		enemy.device_slow_timer = .01
		before = enemy.pos
		sim._enemy_tick(.1)
		check(is_equal_approx(before.distance_to(enemy.pos),10.0), "expired ice-pea slow restores actual speed")
func _live_modifiers() -> void:
	var sim = _sim()
	var d = sim.battle_devices
	var power := _place(sim,"power")
	var reach := _place(sim,"range",Vector2(550,360))
	var hero: Dictionary = sim.heroes[0]
	hero.damage = 100.0
	hero.range = 200.0
	hero.pos = power.pos
	check(is_equal_approx(sim.displayed_attack_damage(hero),135.0), "default attack pad modifies actual hero damage")
	_cards(sim,{"device_power_pad":3,"device_range_pad":3,"device_soil_discount":3})
	check(is_equal_approx(sim.displayed_attack_damage(hero),180.0), "attack-pad card immediately upgrades existing actual damage")
	hero.pos = reach.pos
	check(is_equal_approx(sim.displayed_attack_range(hero),350.0), "range-pad card immediately upgrades existing actual targeting range")
	check(d.price_of("pea") == 126 and d.snapshot(sim).items.pea.price == 126, "soil card changes both actual and displayed pea price")
	var gold: int = d.gold
	var nut := _place(sim,"barricade",Vector2(670,360))
	check(d.gold == gold-63, "discounted nut charges exactly discounted price")
	nut.hp = float(nut.max_hp)*.5
	var old_max: float = nut.max_hp
	_cards(sim,{"device_iron_nut":1,"device_nut_repair":3,"device_rooted":4,"device_salvage":1})
	check(is_equal_approx(nut.max_hp,old_max*2.5*1.9*2.0) and is_equal_approx(nut.hp/nut.max_hp,.5), "iron/recovery/root buffs stack once and preserve damaged HP ratio")
	check(nut.visual_variant == "iron_nut" and nut.armor == 30.0, "iron card changes existing wall-nut body and armor")
	var hp: float = nut.hp
	sim.damage_construct(int(nut.id),50.0)
	check(is_equal_approx(nut.hp,hp-20.0), "iron armor reduces a real incoming hit by 30")
	hp = nut.hp
	d.tick(sim,1.0)
	check(is_equal_approx(nut.hp,hp+36.0), "repair restores actual nut HP at 36 per second")
	var future := _place(sim,"pea",Vector2(790,440))
	check(future.max_hp == future.base_hp*2.0, "rooted card doubles future plant health")
	hp = future.hp
	sim.damage_construct(int(future.id),50.0)
	check(future.hp == hp-50.0, "non-iron plants do not inherit nut armor")
	gold = d.gold
	sim.damage_construct(int(future.id),10000.0)
	d.tick(sim,.01)
	check(d.gold == gold+63 and not d.placed.has(future) and not sim.geo_constructs.has(future), "destroyed plant refunds half its actually paid 126 gold exactly once")
	d.tick(sim,.01)
	check(d.gold == gold+63, "destroyed device cannot refund twice")
	sim = _sim()
	d = sim.battle_devices
	var plant := _place(sim,"pea")
	_cards(sim,{"device_botanist":5,"device_quick_growth":3})
	var target := _enemy(sim,Vector2(790,360))
	d.tick(sim,.25)
	check(d.shots.size() == 1 and is_equal_approx(d.shots[0].damage,102.0) and is_equal_approx(plant.timer,.704), "botanist doubles actual pea damage and growth reduces firing interval")
	d.tick(sim,.5)
	check(is_equal_approx(target.hp,100000.0-102.0), "card damage affects a real enemy hit")
	sim = _sim()
	d = sim.battle_devices
	var mine := _place(sim,"mine")
	_cards(sim,{"device_botanist":1,"device_mine_chain":3,"device_salvage":1})
	target = _enemy(sim,mine.pos)
	var farther := _enemy(sim,Vector2(mine.pos)+Vector2(175,0))
	check(not sim.is_in_ability_area(mine.pos,farther.pos,150.0) and sim.is_in_ability_area(mine.pos,farther.pos,240.0), "explosive card area sample lies beyond base ellipse and within upgraded ellipse")
	gold = d.gold
	d.tick(sim,3.01)
	check(is_equal_approx(target.hp,100000.0-495.0*1.2*1.9) and farther.hp < 100000.0, "explosive card increases real potato damage and area")
	check(d.gold == gold+70 and mine.refunded, "consumed mine salvages half price once")
func _projectiles_and_lifecycle() -> void:
	var sim = _sim()
	var d = sim.battle_devices
	var plant := _place(sim,"pea")
	_cards(sim,{"device_gatling":1,"device_salvage":1})
	var enemy := _enemy(sim,Vector2(910,360))
	d.tick(sim,.21)
	check(d.shots.size() == 1 and plant.burst_queue.size() == 3, "gatling has pending future burst shots")
	plant.hp = 0.0
	var gold: int = d.gold
	d.tick(sim,.5)
	check(d.shots.size() <= 1 and not d.placed.has(plant) and d.gold == gold+90, "dead gatling cannot release queued shots and refunds once")
	enemy.hp = 0.0
	d.tick(sim,3.0)
	check(d.shots.is_empty(), "all departed projectiles expire cleanly")
	sim = _sim()
	d = sim.battle_devices
	plant = _place(sim,"pea")
	enemy = _enemy(sim,Vector2(910,360))
	d.tick(sim,.36)
	var shot: Dictionary = d.shots[0]
	var direction: Vector2 = shot.direction
	enemy.pos.y += 100.0
	d.tick(sim,.3)
	check(shot.direction == direction and is_equal_approx(shot.pos.y,plant.pos.y) and enemy.hp == 100000.0, "ordinary pea stays on fixed row after target dodges")
	sim.reset_stage("stage_03",["traveler"],51059)
	check(d.placed.is_empty() and d.shots.is_empty() and sim.geo_constructs.is_empty() and d.limit == 25, "stage reset clears all devices, shots and card modifiers")
	sim.reset_stage("stage_endless",["traveler"],51059)
	check(not d.enabled and not sim.run_state.device_cards_enabled, "endless excludes unavailable device purchases and card family")
