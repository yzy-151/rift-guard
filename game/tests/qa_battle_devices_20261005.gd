extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const Traveler = preload("res://scripts/traveler_elements.gd")
const GroundProjection = preload("res://scripts/stage_projection.gd")
const DeviceVfx = preload("res://scripts/battle_device_vfx.gd")
const DeviceShopIcon = preload("res://scripts/device_shop_icon.gd")
const Plants = preload("res://scripts/pvz_plant_visual.gd")

class DeviceArtRecorder extends RefCounted:
	var clock := 1.25
	var texture: Texture2D
	var source := Rect2()
	var destination := Rect2()
	var shadows: Array[Dictionary] = []
	func world_to_screen(point: Vector2) -> Vector2: return point
	func world_depth_scale(_point: Vector2) -> float: return 1.0
	func draw_ellipse_shadow(center: Vector2, radius: float, color: Color) -> void:
		shadows.append({"center":center+Vector2(0,9),"radius":radius,"color":color})
	func draw_texture_rect_region(value: Texture2D, target: Rect2, region: Rect2) -> void:
		texture = value
		source = region
		destination = target
	func draw_rect(_rectangle: Rect2, _color: Color) -> void: pass
	func draw_circle(_center: Vector2, _radius: float, _color: Color) -> void: pass

var checks := 0
var failures: Array[String] = []
var observations := {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("DEVICE QA: " + label)

func _initialize() -> void:
	_placement()
	_buffs()
	_barricade()
	_mine()
	_pea()
	_lifecycle()
	_recursive_settlement()
	_geo_coexistence()
	_wallnut_art_contract()
	var output_path := ProjectSettings.globalize_path("res://../qa/battle_devices_20261005/validation.json")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output_path = arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t"))
		output.close()
	print("BATTLE DEVICE QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _sim():
	var sim = Sim.new(51005, true)
	sim.reset_stage("stage_02", ["traveler"], 51005)
	sim.state = "running"
	sim.terrain_features.clear()
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	sim.skill_effects.clear()
	sim.pending_impacts.clear()
	sim.geo_constructs.clear()
	sim.battle_devices.gold = 10000
	for hero: Dictionary in sim.heroes:
		hero.deployed = false
		hero.pos = Vector2(250,200)
		hero.target = hero.pos
	sim.drain_events()
	return sim

func _enemy(sim, point: Vector2, kind: String = "grunt") -> Dictionary:
	var enemy: Dictionary = sim.spawn_enemy(point,kind)
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

func _place(sim, kind: String, point: Vector2) -> Dictionary:
	check(sim.battle_devices.select(sim,kind), "%s can be selected" % kind)
	check(sim.battle_devices.place(sim,point), "%s can be placed on a clear cell" % kind)
	return sim.battle_devices.placed[-1] if not sim.battle_devices.placed.is_empty() else {}

func _reject_place(sim, point: Vector2, label: String) -> void:
	var gold: int = sim.battle_devices.gold
	var count: int = sim.battle_devices.active_count()
	check(not sim.battle_devices.place(sim,point), label + " rejects placement")
	check(sim.battle_devices.gold == gold and sim.battle_devices.active_count() == count,label + " does not spend gold or create an object")

func _placement() -> void:
	var sim = _sim()
	var d = sim.battle_devices
	check(d.enabled and d.limit == 25, "campaign device purchasing is enabled with the intended 25-cell cap")
	check(d.cell_at(sim,Vector2(449,379)) == Rect2(400,340,60,40), "off-center clicks snap to precisely one logical cell")
	check(d.cell_at(sim,Vector2(400,340)).size == Vector2(60,40), "cell boundary clicks use the same grid")
	check(d.select(sim,"power"), "valid item selection succeeds")
	_reject_place(sim,Vector2(10,10),"outside grid")
	_reject_place(sim,Vector2(130,360),"crystal area")
	_reject_place(sim,Vector2(1210,360),"spawn entrance area")
	for kind: String in ["blocked","door","trap","attack_ground","high_ground"]:
		sim.terrain_features.append({"type":kind,"area":Rect2(400,340,60,40),"hp":100})
		_reject_place(sim,Vector2(430,360),kind + " feature")
		sim.terrain_features.clear()
	sim.terrain_features.append({"type":"door","area":Rect2(400,340,60,40),"hp":0})
	check(d.place(sim,Vector2(430,360)), "a destroyed door cell becomes deployable")
	sim.terrain_features.clear()
	check(d.selected_kind.is_empty() and d.placed[0].cell == Rect2(400,340,60,40), "successful deployment clears selection and retains one-cell footprint")
	check(d.gold == 9900, "successful power purchase spends exactly its price")
	d.select(sim,"range")
	_reject_place(sim,Vector2(431,361),"already occupied device cell")
	d.gold = 119
	_reject_place(sim,Vector2(490,360),"funds changed after selection")
	check(not d.select(sim,"pea") and d.gold == 119, "insufficient selection does not spend gold")
	d.gold = 10000
	d.cancel()
	var hero: Dictionary = sim.heroes[0]
	hero.deployed = true
	hero.pos = Vector2(490,360)
	d.select(sim,"barricade")
	_reject_place(sim,hero.pos,"deployed character on barricade cell")
	hero.deployed = false
	var enemy := _enemy(sim,Vector2(490,360))
	_reject_place(sim,enemy.pos,"live enemy on barricade cell")
	enemy.hp = 0
	check(d.place(sim,enemy.pos), "a dead enemy does not occupy a deployment cell")
	d.limit = d.active_count()
	var gold: int = d.gold
	check(not d.select(sim,"mine") and d.gold == gold, "item cap blocks selection without charge")
	d.selected_kind = "mine"
	_reject_place(sim,Vector2(550,360),"item cap rechecked at placement")
	d.limit = 8
	sim.state = "paused"
	_reject_place(sim,Vector2(550,360),"paused state")
	check(not d.select(sim,"range"), "paused state cannot start a purchase")

func _buffs() -> void:
	var sim = _sim()
	var hero: Dictionary = sim.heroes[0]
	hero.deployed = true
	hero.damage = 100.0
	hero.range = 200.0
	hero.pos = Vector2(430,360)
	_place(sim,"power",hero.pos)
	check(is_equal_approx(sim.displayed_attack_damage(hero),135), "power tile changes the actual displayed attack to 135 percent")
	check(is_equal_approx(sim.terrain_attack_scale(hero.pos),1.35), "combat damage multiplier uses the same power tile")
	hero.attack_timer = 0
	hero.crit_chance = 0.0
	hero.element = ""
	var victim := _enemy(sim,Vector2(470,360))
	sim._hero_tick()
	sim._pending_impact_tick(1.0)
	check(is_equal_approx(100000-victim.hp,135), "power tile increases actual melee hit damage by the displayed amount")
	var ability := Traveler.definition("hydro",false)
	sim._execute_ability_impact(hero,ability,victim.pos,false)
	var zone: Dictionary = sim.skill_effects[-1]
	var expected_skill := float(ability.power)+135.0*float(ability.attack_ratio)
	check(is_equal_approx(zone.power,expected_skill), "power tile also contributes to the actual skill attack-ratio component")
	sim._skill_effect_tick(.001)
	check(is_equal_approx(100000-victim.hp,135+expected_skill), "buffed skill actually deals the previewed power rather than only changing the HUD")
	for point: Vector2 in [Vector2(399.999,360),Vector2(460,360),Vector2(430,380)]:
		hero.pos = point
		check(is_equal_approx(sim.displayed_attack_damage(hero),100), "power tile stops exactly outside its cell at %s" % point)
	hero.pos = Vector2(550,360)
	_place(sim,"range",hero.pos)
	check(is_equal_approx(sim.displayed_attack_range(hero),260), "range tile changes the actual displayed range to 130 percent")
	var radii: Vector2 = sim.attack_range_screen_radii(hero)
	var world_radii: Vector2 = GroundProjection.ground_world_radii(hero.pos,radii)
	var center: Vector2 = GroundProjection.ground_center(hero.pos)
	check(sim.is_in_attack_range(hero,center + Vector2(world_radii.x*.98,0)), "buffed actual targeting accepts just inside its ellipse")
	check(not sim.is_in_attack_range(hero,center + Vector2(world_radii.x*1.02,0)), "buffed actual targeting rejects just outside its ellipse")
	hero.pos = Vector2(580,360)
	check(is_equal_approx(sim.displayed_attack_range(hero),200), "moving outside the range cell restores base range")
	check(is_equal_approx(sim.displayed_attack_damage(hero),100), "range tile does not add attack damage")

func _barricade() -> void:
	var sim = _sim()
	var wall := _place(sim,"barricade",Vector2(430,360))
	check(sim.geo_constructs.size() == 1 and sim.geo_constructs[0] == wall and wall.device, "purchased barricade is registered as the same live destructible object")
	var enemy := _enemy(sim,Vector2(471,360))
	enemy.speed = 80.0
	var start := Vector2(enemy.pos)
	sim._enemy_tick(.1)
	check(enemy.pos == start and enemy.attack_pending and int(enemy.warning_construct) == int(wall.id), "ordinary melee enemy stops and winds up against the barricade")
	var hp: float = wall.hp
	for frame in 60: sim._enemy_tick(1.0/60.0)
	check(wall.hp < hp and wall.hp > 0, "ordinary enemy attacks really reduce barricade HP")
	enemy.damage = 10000.0
	for frame in 120: sim._enemy_tick(1.0/60.0)
	check(wall.hp == 0, "ordinary enemy can break the barricade")
	check(enemy.pos.x < 400, "enemy resumes walking through the destroyed barricade cell")
	sim.battle_devices.tick(sim,.001)
	check(sim.battle_devices.active_count() == 0 and sim.battle_devices.placed.is_empty(), "destroyed barricade frees a purchase slot")

func _mine() -> void:
	var sim = _sim()
	var mine := _place(sim,"mine",Vector2(550,360))
	var trigger := _enemy(sim,Vector2(mine.pos)+Vector2(29,0))
	trigger.flying = true
	sim.battle_devices.tick(sim,.01)
	check(mine.hp > 0 and trigger.hp == 100000, "flying enemy cannot trigger a floor mine")
	sim.battle_devices.tick(sim,3.0)
	check(mine.armed and mine.hp > 0, "potato mine arms after three seconds without triggering on a flying enemy")
	trigger.flying = false
	trigger.pos = Vector2(mine.pos) + Vector2(31,0)
	sim.battle_devices.tick(sim,.01)
	check(mine.hp > 0, "a ground enemy just outside the mine cell does not trigger it")
	trigger.pos = mine.pos
	var radii: Vector2 = GroundProjection.ground_world_radii(mine.pos,sim.ability_area_screen_radii(mine.pos,150))
	var center: Vector2 = GroundProjection.ground_center(mine.pos)
	var inside := _enemy(sim,center + Vector2(radii.x*.98,0))
	var outside := _enemy(sim,center + Vector2(radii.x*1.02,0))
	var vertical_outside := _enemy(sim,center + Vector2(0,radii.y*1.02))
	sim.battle_devices.tick(sim,.01)
	var damage: float = 420.0 + sim.team_level*75.0
	check(is_equal_approx(100000-trigger.hp,damage), "mine trigger receives exactly one intended explosion hit")
	check(is_equal_approx(100000-inside.hp,damage), "mine blast reaches the actual ellipse edge")
	check(outside.hp == 100000 and vertical_outside.hp == 100000, "mine blast does not leak outside horizontal or vertical ellipse boundaries")
	check(mine.hp == 0 and sim.battle_devices.active_count() == 0 and sim.battle_devices.placed.is_empty(), "mine is consumed and frees its slot in the trigger tick")
	var explosion_count := 0
	for event: Dictionary in sim.drain_events():
		if event.kind == "device_explosion": explosion_count += 1
	check(explosion_count == 1, "mine emits one explosion even with multiple nearby victims")

func _pea() -> void:
	var sim = _sim()
	var pea := _place(sim,"pea",Vector2(430,360))
	var behind := _enemy(sim,Vector2(350,360))
	var next_row := _enemy(sim,Vector2(550,381))
	var flying := _enemy(sim,Vector2(550,360))
	flying.flying = true
	sim.battle_devices.tick(sim,.4)
	check(sim.battle_devices.shots.is_empty(), "pea does not aim left, at other rows, or at flying targets")
	var target := _enemy(sim,Vector2(650,360))
	sim.battle_devices.tick(sim,.01)
	check(sim.battle_devices.shots.size() == 1, "pea fires along its row toward an actual target on the right")
	var shot: Dictionary = sim.battle_devices.shots[0]
	check(not shot.has("target_id") and is_equal_approx(shot.pos.y,360), "pea stores no homing target and keeps a fixed row")
	target.hp = 0
	sim.battle_devices.tick(sim,.45)
	check(sim.battle_devices.shots.size() == 1 and shot.pos.x > 650 and behind.hp == 100000 and next_row.hp == 100000, "a dead aim target produces a true miss that continues beyond the former target")
	sim.battle_devices.tick(sim,3.0)
	check(sim.battle_devices.shots.is_empty(), "missed peas expire or leave the board instead of accumulating")
	sim = _sim()
	pea = _place(sim,"pea",Vector2(430,360))
	target = _enemy(sim,Vector2(700,360))
	sim.battle_devices.tick(sim,.36)
	check(sim.battle_devices.shots.size() == 1, "wall test has one airborne pea")
	sim.terrain_features.append({"type":"blocked","area":Rect2(660,340,10,40)})
	sim.battle_devices.tick(sim,.3)
	check(sim.battle_devices.shots.is_empty() and target.hp == 100000, "a newly obstructing wall intercepts the pea before the victim")
	sim = _sim()
	pea = _place(sim,"pea",Vector2(430,360))
	sim.terrain_features.append({"type":"blocked","area":Rect2(550,340,60,40)})
	target = _enemy(sim,Vector2(700,360))
	sim.battle_devices.tick(sim,.5)
	check(sim.battle_devices.shots.is_empty(), "pea does not start a shot through an existing wall")
	sim = _sim()
	pea = _place(sim,"pea",Vector2(430,360))
	var farther := _enemy(sim,Vector2(740,360))
	var nearer := _enemy(sim,Vector2(650,360))
	sim.battle_devices.tick(sim,.6)
	check(is_equal_approx(100000-nearer.hp,45+sim.team_level*6.0), "large-dt pea uses swept collision and hits the nearer body exactly once")
	check(farther.hp == 100000 and sim.battle_devices.shots.is_empty(), "nearest-hit contact does not penetrate to a later body")
	observations.pea = {"swept_dt":.6,"nearest_damage":100000-nearer.hp,"miss_heading":"right only"}

func _lifecycle() -> void:
	var sim = _sim()
	var d = sim.battle_devices
	var pea := _place(sim,"pea",Vector2(430,360))
	var target := _enemy(sim,Vector2(700,360))
	sim.battle_devices.tick(sim,.4)
	sim.state = "paused"
	var before_shot: Array = d.shots.duplicate(true)
	var before_device: Array = d.placed.duplicate(true)
	var before_hp: float = target.hp
	sim.tick(.8)
	check(d.shots == before_shot and d.placed == before_device and target.hp == before_hp, "actual paused simulation does not move peas, advance devices, or deal damage")
	sim.state = "reward"
	sim.tick(.8)
	check(d.shots == before_shot and d.placed == before_device, "reward picker also freezes devices")
	sim.state = "running"
	target.hp = 1
	var gold: int = d.gold
	sim.apply_hit(target,100.0,"",-1)
	check(d.gold == gold+12, "actual ordinary enemy death grants one gold reward")
	sim.apply_hit(target,100.0,"",-1)
	check(d.gold == gold+12, "hitting an already dead enemy cannot reward gold again")
	var elite := _enemy(sim,Vector2(900,360),"hilichurl_brute")
	elite.hp = 1
	sim.apply_hit(elite,100.0,"",-1)
	check(d.gold == gold+34, "elite kill grants its larger purchase reward")
	var boss := _enemy(sim,Vector2(900,400),"boss_02")
	boss.hp = 1
	boss.split_done = true
	sim.apply_hit(boss,100.0,"",-1)
	check(d.gold == gold+134, "boss death grants exactly the boss purchase reward")
	sim.reset_stage("stage_02",["traveler"],51006)
	check(d.placed.is_empty() and d.shots.is_empty() and sim.geo_constructs.is_empty() and d.gold == 120, "fresh stage reset clears old objects, shots, barricades, and gold")
	sim.reset_stage("stage_endless",["traveler"],51007)
	check(not d.enabled and d.gold == 0 and d.placed.is_empty(), "endless mode does not inherit campaign purchases")
	sim = Sim.new(1,false)
	check(not sim.battle_devices.enabled and sim.battle_devices.gold == 0, "legacy mode cannot inherit enabled campaign purchases")

func _recursive_settlement() -> void:
	for revive in [false,true]:
		var sim = _sim()
		var a := _enemy(sim,Vector2(500,300),"shielded" if revive else "runner")
		var b := _enemy(sim,Vector2(540,300),"runner")
		a.hp = 1.0; a.max_hp = 100.0; a.aura = "electro"
		b.hp = 1.0; b.max_hp = 100.0
		sim.death_burst_ratio = 1.0
		var gold: int = sim.battle_devices.gold
		var kills: int = sim.kills
		sim.apply_hit(a,10.0,"pyro",-1)
		if not revive:
			check(sim.kills == kills+2 and sim.battle_devices.gold == gold+24, "recursive overload and death bursts settle two real kills and 24 gold once")
			check(bool(a.get("death_settled",false)) and bool(b.get("death_settled",false)), "recursive deaths are marked settled before further area blasts")
		else:
			check(bool(a.get("revive_pending",false)) and not bool(a.get("death_settled",false)), "recursive overload leaves a shielded enemy down for its one revival")
			check(sim.kills == kills+1 and sim.battle_devices.gold == gold+12, "pending revival awards no kill or purchase gold")
			Sim.EnemyTactics.tick_revival(sim,a,float(a.revive_duration)+.01)
			check(a.hp == a.max_hp and not bool(a.revive_pending), "shielded enemy revives with the existing gameplay rule")
			sim.apply_hit(a,1000.0,"",-1)
			check(sim.kills == kills+2 and sim.battle_devices.gold == gold+24, "final shielded death rewards exactly once after revival")
			sim.apply_hit(a,1000.0,"",-1)
			check(sim.kills == kills+2 and sim.battle_devices.gold == gold+24, "additional hits cannot settle final shielded death again")

func _geo_coexistence() -> void:
	var sim = _sim()
	var hero: Dictionary = sim.heroes[0]
	hero.deployed = true
	var ability := Traveler.definition("geo",false)
	Traveler.start(sim,hero,ability,Vector2(850,360),100,125)
	var wall := _place(sim,"barricade",Vector2(430,360))
	for index in 4: Traveler.start(sim,hero,ability,Vector2(850+index*20,360),100,125)
	var ids := {}
	var stars := 0
	var found_wall := false
	for construct: Dictionary in sim.geo_constructs:
		ids[construct.id] = true
		if bool(construct.get("device",false)): found_wall = int(construct.id) == int(wall.id)
		else: stars += 1
	check(found_wall, "casting a fourth and later geo star does not unregister the purchased barricade")
	check(stars == 3, "geo star cap remains three independently of purchased barricades")
	check(ids.size() == sim.geo_constructs.size(), "geo stars and purchased barricades have unique construct IDs")
	var before: float = wall.hp
	sim.damage_construct(int(wall.id),25.0)
	check(is_equal_approx(before-wall.hp,25), "damage by barricade ID hits that same purchased object after geo casts")

func _wallnut_art_contract() -> void:
	var textures: Array[Texture2D] = [Plants.TEXTURES.wallnut, Plants.TEXTURES.wallnut_cracked, Plants.TEXTURES.wallnut_broken]
	var counts: Array[int] = [16,11,15]
	var keys: Array[String] = ["wallnut", "wallnut_cracked", "wallnut_broken"]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/pvz_botany_20261005/manifest.json")).plants
	var atlases_valid := true
	for index in textures.size():
		var texture := textures[index]
		var image := texture.get_image()
		atlases_valid = atlases_valid and texture.get_size() == Vector2(counts[index]*65,73) and image != null and image.get_pixel(0,0).a == 0.0 and image.get_pixel(32,36).a > 0.0
	check(atlases_valid, "real Wall-nut atlases preserve transparent 65x73 frames with 16/11/15 frame counts")
	var sim = _sim()
	check(str(sim.device_shop.items.barricade.name) == "坚果墙" and DeviceShopIcon.PLANTS.TEXTURES.wallnut == Plants.TEXTURES.wallnut, "live shop names the wall-nut and binds the original plant sprite library")
	var recorder := DeviceArtRecorder.new()
	var actor := {"kind":"barricade","pos":Vector2(430,360),"max_hp":100.0,"hp":100.0,"visual_time":1.25,"visual_variant":"wallnut"}
	var states_valid := true
	var cases := [[1.0,0],[.661,0],[.66,1],[.331,1],[.33,2],[.01,2]]
	for sample: Array in cases:
		var index := int(sample[1])
		actor.hp = float(sample[0])*actor.max_hp
		recorder.shadows.clear()
		DeviceVfx.actor(recorder,actor)
		# Read the preserved source GIF timing independently of frame_at().
		var info: Dictionary = data[keys[index]]
		var time := fposmod(float(actor.visual_time), float(info.period))
		var frame := counts[index] - 1
		for source_frame in info.duration_ms.size():
			time -= float(info.duration_ms[source_frame]) * .001
			if time < .000001:
				frame = source_frame
				break
		states_valid = states_valid and recorder.texture == textures[index] and recorder.source == Rect2(frame*65,0,65,73) and recorder.source.end.x <= textures[index].get_width()
		check(recorder.shadows.size() == 2 and Vector2(recorder.shadows[0].center).distance_to(Vector2(actor.pos)+Vector2(0,3)) < .001 and float(recorder.shadows[0].color.a) >= .3, "actual Wall-nut renderer retains grounded foot shadows at HP ratio=" + str(sample[0]))
		var painted_foot: Vector2 = recorder.destination.position + Vector2(float(info.foot[0]), float(info.foot[1])) * recorder.destination.size / recorder.source.size
		check(painted_foot.distance_to(Vector2(actor.pos) + Vector2(0,3)) < .001, "source Wall-nut foot anchor matches actual fixed ground shadow at HP ratio=" + str(sample[0]))
	check(states_valid, "actual renderer switches at inclusive 66/33 percent HP and wraps each state within its own atlas")
	Plants.draw_icon(recorder,"wallnut",Rect2(0,0,19,19))
	check(recorder.texture == textures[0], "original Wall-nut also supplies the seed-bag icon")
	actor.visual_variant = "iron_nut"
	actor.hp = 100.0
	DeviceVfx.actor(recorder,actor)
	var silver := recorder.texture.get_image().get_pixel(32,36)
	check(recorder.texture != textures[0] and silver.r < silver.g and silver.g < silver.b, "iron nut keeps original animation body with an actual silver finish")
	observations.wallnut = {"display_name":"坚果墙","cell":[65,73],"frames":counts,"duration_ms":[90,100,100],"cracked_at":.66,"broken_at":.33,"boundary_cases":cases.size(),"original_gif_timing":true,"fixed_foot_anchor":true}
