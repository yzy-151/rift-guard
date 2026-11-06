extends SceneTree
## Test the painted texture transform independently of the muzzle helper.
const Sim = preload("res://scripts/combat_simulation.gd")
const GroundProjection = preload("res://scripts/stage_projection.gd")
const PeaVisual = preload("res://scripts/peashooter_visual_20261005.gd")

class PaintProbe extends RefCounted:
	var sim
	var clock := 0.0
	var position := Vector2.ZERO
	var angle := 0.0
	var scale := Vector2.ONE
	var painted_mouth := Vector2(INF,INF)
	var source := Rect2()
	var texture: Texture2D
	var shadows: Array[Dictionary] = []
	var circles: Array[Dictionary] = []
	func world_to_screen(point: Vector2) -> Vector2: return GroundProjection.project(point)
	func world_depth_scale(point: Vector2) -> float: return GroundProjection.depth_scale(point)
	func draw_set_transform(point: Vector2, rotation: float = 0.0, stretch: Vector2 = Vector2.ONE) -> void:
		position = point
		angle = rotation
		scale = stretch
	func draw_texture_rect_region(value: Texture2D, destination: Rect2, region: Rect2) -> void:
		texture = value
		source = region
		var landmark_local: Vector2 = destination.position + (PeaVisual.MOUTH-region.position)/region.size*destination.size
		painted_mouth = position + (landmark_local*scale).rotated(angle)
	func draw_ellipse_shadow(center: Vector2, radius: float, color: Color) -> void:
		shadows.append({"center":center,"radius":radius,"color":color})
	func draw_circle(center: Vector2, radius: float, color: Color, _filled: bool = true, _width: float = -1.0, _antialias: bool = false) -> void:
		circles.append({"center":center,"radius":radius,"color":color})
	func draw_line(_start: Vector2, _end: Vector2, _color: Color, _width: float = -1.0, _antialias: bool = false) -> void: pass

var checks := 0
var failures: Array[String] = []
var observations := {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("PEA MUZZLE QA: " + label)

func _initialize() -> void:
	_art_and_pose()
	_emission_and_advance()
	_pause_and_reward()
	_aim_and_collision()
	var path := ProjectSettings.globalize_path("res://../qa/peashooter_muzzle_20261005/validation.json")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): path = arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t"))
		file.close()
	print("PEASHOOTER MUZZLE QA: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _sim(row_y: float = 360.0):
	var sim = Sim.new(510054, true)
	sim.reset_stage("stage_02", ["traveler"], 510054)
	sim.state = "running"
	sim.terrain_features.clear()
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	sim.pending_impacts.clear()
	sim.skill_effects.clear()
	sim.stage_runtime.definition.waves = []
	sim.stage_runtime.definition.boss_at_seconds = 99999.0
	sim.battle_devices.gold = 10000
	for hero: Dictionary in sim.heroes: hero.deployed = false
	check(sim.battle_devices.select(sim, "pea"), "real purchasing can select Peashooter")
	check(sim.battle_devices.place(sim, Vector2(430,row_y)), "real purchasing can place Peashooter at y=" + str(row_y))
	sim.drain_events()
	return sim

func _enemy(sim, point: Vector2) -> Dictionary:
	var enemy: Dictionary = sim.spawn_enemy(point, "grunt")
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	enemy.armor = 0.0
	enemy.shield = 0.0
	enemy.speed = 0.0
	enemy.affixes = []
	enemy.aura = ""
	enemy.intrinsic_element = ""
	enemy.route_points = []
	enemy.xp = 0
	return enemy

func _probe(sim) -> PaintProbe:
	var probe := PaintProbe.new()
	probe.sim = sim
	return probe

func _art_and_pose() -> void:
	var image: Image = PeaVisual.TEXTURE.get_image()
	check(image != null and not image.is_empty(), "the new flat sprite actually loads")
	if image == null or image.is_empty(): return
	check(Rect2(Vector2.ZERO,image.get_size()).encloses(PeaVisual.SOURCE), "source crop lies within the imported sprite")
	check(PeaVisual.SOURCE.has_point(PeaVisual.MOUTH), "mouth landmark lies inside the source crop")
	check(PeaVisual.SOURCE.has_point(PeaVisual.FOOT), "foot landmark lies inside the source crop")
	var mouth_pixel := image.get_pixelv(PeaVisual.MOUTH)
	check(mouth_pixel.a > .9 and maxf(mouth_pixel.r,maxf(mouth_pixel.g,mouth_pixel.b)) < .15, "mouth landmark is on opaque dark mouth artwork")
	var max_error := 0.0
	for row_y: float in [160.0,360.0,560.0]:
		var sim = _sim(row_y)
		var device: Dictionary = sim.battle_devices.placed[0]
		for time: float in [0.0,.1,.5,1.3,3.7]:
			for age: float in [0.0,.045,.09,.135,.18,.25,.375,.5,.6]:
				var pulse := maxf(0.0,.18-age)
				device.visual_time = time
				device.pulse = pulse
				device.shoot_age = age
				var probe := _probe(sim)
				PeaVisual.draw(probe,device)
				var muzzle := PeaVisual.mouth_screen(probe,device.pos,time,pulse,age)
				var error := muzzle.distance_to(probe.painted_mouth)
				max_error = maxf(max_error,error)
				check(error < .001, "muzzle equals independently transformed painted mouth at %s/%s/%s" % [row_y,time,age])
				check(probe.texture == PeaVisual.TEXTURE and probe.source == PeaVisual.SOURCE, "painted art uses the same cropped flat sprite")
				check(probe.shadows.size() == 2 and float(probe.shadows[0].color.a) > .3, "every shooting pose has a substantial foot shadow")
				check(probe.position == Vector2.ZERO and probe.angle == 0.0 and probe.scale == Vector2.ONE, "plant drawing resets the transform for projectile overlays")
				var model_start := Vector2(device.pos) + Vector2(14,0)
				var snapshot := {"pos":model_start,"model_origin":model_start,"visual_origin":device.pos,"visual_time":time,"muzzle_pulse":pulse,"shoot_age":age}
				check(PeaVisual.shot_screen(probe,snapshot).distance_to(probe.painted_mouth) < .001, "zero-travel projectile sits exactly at the painted mouth")
	observations.paint_transform = {"poses":135,"max_error_pixels":max_error,"source":str(PeaVisual.SOURCE),"mouth":str(PeaVisual.MOUTH),"shoot_age_cases":[0.0,.045,.09,.135,.18,.25,.375,.5,.6]}

func _emission_and_advance() -> void:
	for row_y: float in [160.0,360.0,560.0]:
		for phase: float in [0.0,.35,1.7]:
			var sim = _sim(row_y)
			var device: Dictionary = sim.battle_devices.placed[0]
			var target := _enemy(sim,Vector2(device.pos)+Vector2(450,0))
			device.timer = 0.0
			device.visual_time = phase
			sim.battle_devices.tick(sim,0.0)
			check(sim.battle_devices.shots.size() == 1, "a real release emits one projectile at the tested height and phase")
			if sim.battle_devices.shots.is_empty(): continue
			var shot: Dictionary = sim.battle_devices.shots[0]
			var probe := _probe(sim)
			PeaVisual.draw(probe,device)
			var initial_screen := PeaVisual.shot_screen(probe,shot)
			check(initial_screen.distance_to(probe.painted_mouth) < .001, "real zero-dt release matches the actual drawn mouth")
			check(shot.pos == shot.model_origin and shot.previous_pos == shot.model_origin, "real initial model travel is zero")
			check(shot.visual_origin == device.pos and is_equal_approx(float(shot.visual_time),phase) and is_equal_approx(float(shot.muzzle_pulse),.18), "release captures source, shooting pose and time")
			check(not shot.has("target_id"), "mouth alignment does not add target locking")
			var model_start := Vector2(shot.pos)
			var launch_time := float(shot.visual_time)
			var launch_origin := Vector2(shot.visual_origin)
			for dt: float in [.07,.13]:
				var previous := Vector2(shot.pos)
				sim.battle_devices.tick(sim,dt)
				check(Vector2(shot.pos).distance_to(previous+Vector2(600.0*dt,0)) < .001, "real projectile moves right at exactly 600 world units per second")
				check(is_equal_approx(float(shot.pos.y),row_y), "projectile retains its original logical row")
				var displacement := GroundProjection.project(shot.pos)-GroundProjection.project(model_start)
				check(PeaVisual.shot_screen(probe,shot).distance_to(initial_screen+displacement) < .001, "screen flight advances from the fixed painted mouth")
				check(is_equal_approx(float(shot.visual_time),launch_time) and shot.visual_origin == launch_origin, "ongoing plant animation cannot change the captured muzzle")
			check(float(device.visual_time) > launch_time and target.hp == 100000.0, "plant pose advances while a distant projectile is still in flight")
			# Removing the original aim target still leaves a fixed straight miss.
			target.hp = 0.0
			var before_miss := Vector2(shot.pos)
			sim.battle_devices.tick(sim,.6)
			check(shot.pos == before_miss+Vector2(360,0) and sim.battle_devices.shots.size() == 1, "a pea flies beyond a removed target without stopping or homing")
	observations.release = {"height_cases":3,"animation_phases":3,"speed":600,"direction":"fixed right","row_tolerance":20}

func _pause_and_reward() -> void:
	var sim = _sim()
	var device: Dictionary = sim.battle_devices.placed[0]
	_enemy(sim,Vector2(1000,360))
	device.timer = 0.0
	sim.battle_devices.tick(sim,0.0)
	var shot: Dictionary = sim.battle_devices.shots[0]
	var probe := _probe(sim)
	var screen_before := PeaVisual.shot_screen(probe,shot)
	var devices_before: Array = sim.battle_devices.placed.duplicate(true)
	var shots_before: Array = sim.battle_devices.shots.duplicate(true)
	for frozen_state: String in ["paused","reward"]:
		sim.state = frozen_state
		sim.tick(.8)
		check(sim.battle_devices.placed == devices_before and sim.battle_devices.shots == shots_before, frozen_state + " freezes release time, spring pose and model flight")
		check(PeaVisual.shot_screen(probe,shot) == screen_before, frozen_state + " freezes the rendered projectile position")
	sim.state = "running"
	sim.tick(.1)
	check(is_equal_approx(float(shot.pos.x),float(shot.model_origin.x)+60), "resuming actual simulation moves the same projectile")
	check(is_equal_approx(float(device.visual_time),.1), "resuming actual simulation advances device animation by simulation time")

func _aim_and_collision() -> void:
	var sim = _sim()
	var device: Dictionary = sim.battle_devices.placed[0]
	var left := _enemy(sim,Vector2(350,360))
	var next_row := _enemy(sim,Vector2(700,381))
	var flyer := _enemy(sim,Vector2(700,360)); flyer.flying = true
	var dead := _enemy(sim,Vector2(700,360)); dead.hp = 0.0
	device.timer = 0.0
	sim.battle_devices.tick(sim,.4)
	check(sim.battle_devices.shots.is_empty(), "left, other-row, flying and dead targets cannot trigger a shot")
	var edge_row := _enemy(sim,Vector2(1000,380))
	sim.battle_devices.tick(sim,0.0)
	check(sim.battle_devices.shots.size() == 1, "a live target at the inclusive row boundary can trigger a shot")
	sim.battle_devices.tick(sim,.4)
	check(left.hp == 100000.0 and next_row.hp == 100000.0 and flyer.hp == 100000.0 and edge_row.hp == 100000.0, "launch and fly-through never hurt invalid targets")
	sim = _sim()
	device = sim.battle_devices.placed[0]
	var blocked_target := _enemy(sim,Vector2(900,360))
	sim.terrain_features.append({"type":"blocked","area":Rect2(660,340,10,40)})
	device.timer = 0.0
	sim.battle_devices.tick(sim,.5)
	check(sim.battle_devices.shots.is_empty() and blocked_target.hp == 100000.0, "an existing wall prevents release toward an occluded target")
	sim.terrain_features.clear()
	sim.battle_devices.tick(sim,0.0)
	check(sim.battle_devices.shots.size() == 1, "removing the wall allows an actual release")
	sim.terrain_features.append({"type":"blocked","area":Rect2(660,340,10,40)})
	sim.battle_devices.tick(sim,.6)
	check(sim.battle_devices.shots.is_empty() and blocked_target.hp == 100000.0, "a new wall intercepts the in-flight swept segment before target damage")
	sim = _sim()
	device = sim.battle_devices.placed[0]
	var farther := _enemy(sim,Vector2(740,360))
	var nearer := _enemy(sim,Vector2(650,360))
	device.timer = 0.0
	sim.battle_devices.tick(sim,0.0)
	var release: Dictionary = sim.battle_devices.shots[0].duplicate(true)
	sim.battle_devices.tick(sim,.6)
	var expected := 45.0 + float(sim.team_level)*6.0
	check(is_equal_approx(100000.0-float(nearer.hp),expected), "large-dt swept collision hits the nearer body once at the unchanged damage")
	check(farther.hp == 100000.0 and sim.battle_devices.shots.is_empty(), "first-contact projectile does not penetrate the farther target")
	var hit_events: Array[Dictionary] = []
	for event: Dictionary in sim.drain_events():
		if str(event.kind) == "device_pea_hit": hit_events.append(event)
	check(hit_events.size() == 1, "one actual collision emits one impact event")
	if not hit_events.is_empty():
		var hit: Dictionary = hit_events[0]
		var probe := _probe(sim)
		var expected_screen := PeaVisual.mouth_screen(probe,release.visual_origin,release.visual_time,release.muzzle_pulse)+GroundProjection.project(hit.pos)-GroundProjection.project(release.model_origin)
		check(PeaVisual.shot_screen(probe,hit.shot_visual,hit.pos).distance_to(expected_screen) < .001, "collision spark resolves to the same mouth-derived flight line")
	observations.collision = {"swept_dt":.6,"damage":expected,"nearest_hit_only":true,"walls_intercept":true}
