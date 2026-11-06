extends SceneTree
## Observe real releases and painted foot/mouth positions instead of duplicating the spring formula.
const Sim = preload("res://scripts/combat_simulation.gd")
const GroundProjection = preload("res://scripts/stage_projection.gd")
const PeaVisual = preload("res://scripts/peashooter_visual_20261005.gd")
const DeviceVfx = preload("res://scripts/battle_device_vfx.gd")

class PaintProbe extends RefCounted:
	var sim
	var clock := 0.0
	var translation := Vector2.ZERO
	var rotation := 0.0
	var stretch := Vector2.ONE
	var painted_rotation := 0.0
	var mouth := Vector2.INF
	var foot := Vector2.INF
	var destination := Rect2()
	var source := Rect2()
	var texture: Texture2D
	var shadows: Array[Dictionary] = []
	var drawing_order: Array[String] = []
	func world_to_screen(point: Vector2) -> Vector2: return GroundProjection.project(point)
	func world_depth_scale(point: Vector2) -> float: return GroundProjection.depth_scale(point)
	func draw_set_transform(point: Vector2, angle: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
		translation = point
		rotation = angle
		stretch = scale
	func _landmark(point: Vector2, region: Rect2, rectangle: Rect2) -> Vector2:
		var local := rectangle.position+(point-region.position)/region.size*rectangle.size
		return translation+(local*stretch).rotated(rotation)
	func draw_texture_rect_region(value: Texture2D, rectangle: Rect2, region: Rect2) -> void:
		texture = value
		destination = rectangle
		source = region
		painted_rotation = rotation
		drawing_order.append("sprite")
		if value == PeaVisual.TEXTURE:
			mouth = _landmark(PeaVisual.MOUTH,region,rectangle)
			foot = _landmark(PeaVisual.FOOT,region,rectangle)
	func draw_ellipse_shadow(center: Vector2, radius: float, color: Color) -> void:
		# BattleView's actual shadow helper applies this screen-space center offset.
		shadows.append({"center":center+Vector2(0,9),"radius":radius,"color":color})
		drawing_order.append("shadow")
	func draw_rect(_rectangle: Rect2, _color: Color) -> void: drawing_order.append("bar")
	func draw_line(_a: Vector2, _b: Vector2, _color: Color, _width: float = -1.0, _aa: bool = false) -> void: pass
	func draw_circle(_center: Vector2, _radius: float, _color: Color, _filled: bool = true, _width: float = -1.0, _aa: bool = false) -> void: pass

var checks := 0
var failures: Array[String] = []
var observations := {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("DEVICE RHYTHM QA: " + label)

func _initialize() -> void:
	_rhythm_and_launch()
	_pause_and_no_target()
	_wallnut_ground_contact()
	var output := ProjectSettings.globalize_path("res://../qa/device_rhythm_shadow_20261005/validation.json")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"\t"))
		file.close()
	print("DEVICE RHYTHM AND SHADOW QA: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _sim():
	var sim = Sim.new(510057,true)
	sim.reset_stage("stage_02",["traveler"],510057)
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
	sim.drain_events()
	return sim

func _place(sim, kind: String, row: float) -> Dictionary:
	check(sim.battle_devices.select(sim,kind),kind+" can be selected")
	check(sim.battle_devices.place(sim,Vector2(430,row)),kind+" can be purchased in a clear cell")
	sim.drain_events()
	return sim.battle_devices.placed[-1]

func _enemy(sim, row: float) -> Dictionary:
	var enemy: Dictionary = sim.spawn_enemy(Vector2(1100,row),"grunt")
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

func _paint(sim, device: Dictionary, time: float = 0.0) -> PaintProbe:
	var probe := PaintProbe.new()
	probe.sim = sim
	probe.clock = time
	DeviceVfx.actor(probe,device)
	return probe

func _rhythm_and_launch() -> void:
	var max_mouth_error := 0.0
	var max_foot_error := 0.0
	var rhythm_cases: Array[Dictionary] = []
	for row: float in [160.0,360.0,560.0]:
		var firing = _sim()
		var resting = _sim()
		var pea := _place(firing,"pea",row)
		var idle := _place(resting,"pea",row)
		_enemy(firing,row)
		var release_times: Array[float] = []
		var cycles: Array[Dictionary] = []
		var elapsed := 0.0
		for frame in 384:
			var dt := 1.0/120.0
			elapsed += dt
			firing.battle_devices.tick(firing,dt)
			resting.battle_devices.tick(resting,dt)
			var released := false
			for event: Dictionary in firing.drain_events():
				if str(event.kind) == "device_pea_cast": released = true
			var painted := _paint(firing,pea)
			var idle_paint := _paint(resting,idle)
			var swing := painted.painted_rotation-idle_paint.painted_rotation
			var expected_foot := GroundProjection.project(pea.pos)+Vector2(0,8)*GroundProjection.depth_scale(pea.pos)
			var foot_error := painted.foot.distance_to(expected_foot)
			max_foot_error = maxf(max_foot_error,foot_error)
			check(foot_error < .001,"shooting swing keeps the painted source foot fixed at row/frame="+str(row)+"/"+str(frame))
			check(painted.shadows.size() == 2 and Vector2(painted.shadows[0].center).distance_to(expected_foot) < .001,"foot shadow stays anchored under every firing pose")
			if released:
				release_times.append(elapsed)
				cycles.append({"negative":0.0,"positive":0.0,"returned":false})
				check(float(pea.shoot_age) == 0.0,"each real release starts its shooting swing once")
				var shot: Dictionary = firing.battle_devices.shots[-1]
				var distance := GroundProjection.project(shot.pos)-GroundProjection.project(shot.model_origin)
				var error := (PeaVisual.shot_screen(painted,shot)-distance).distance_to(painted.mouth)
				max_mouth_error = maxf(max_mouth_error,error)
				check(error < .001,"real emitted projectile starts at independently painted mouth during swing")
				check(float(shot.shoot_age) == 0.0 and shot.visual_origin == pea.pos,"released projectile stores the exact source pose rather than following later sways")
			if not cycles.is_empty():
				var cycle: Dictionary = cycles[-1]
				if float(pea.shoot_age) <= .51:
					cycle.negative = minf(float(cycle.negative),swing)
					cycle.positive = maxf(float(cycle.positive),swing)
				elif float(pea.shoot_age) < 1.05:
					cycle.returned = bool(cycle.returned) or absf(swing)<.003
					check(absf(swing)<.003,"after the shooting beat the actual drawing returns to its quiet idle pose")
		check(release_times.size() == 3,"3.2 seconds produces three actual releases at unchanged cadence")
		for index in range(1,release_times.size()):
			check(absf(release_times[index]-release_times[index-1]-1.1)<.02,"actual release interval remains 1.1 seconds")
		for index in cycles.size():
			var cycle: Dictionary = cycles[index]
			check(float(cycle.negative)<-.055 and float(cycle.positive)>.010,"release "+str(index)+" shows a visible recoil and counter-swing, including after the audio pulse ends")
			check(bool(cycle.returned),"release "+str(index)+" completes one sway and settles before its next shot")
		rhythm_cases.append({"row":row,"releases":release_times,"cycles":cycles})
	observations.rhythm = {"cases":rhythm_cases,"mouth_error_pixels":max_mouth_error,"foot_error_pixels":max_foot_error,"sample_rate":120}

func _pause_and_no_target() -> void:
	var sim = _sim()
	var pea := _place(sim,"pea",360)
	_enemy(sim,360)
	sim.battle_devices.tick(sim,.35)
	sim.battle_devices.tick(sim,.25)
	check(float(pea.pulse) == 0.0 and float(pea.shoot_age)>.18 and float(pea.shoot_age)<.5,"fixture reaches the counter-swing after the audio pulse has ended")
	var before: Dictionary = pea.duplicate(true)
	var drawing := _paint(sim,pea)
	var frozen_mouth := drawing.mouth
	var frozen_rotation := drawing.painted_rotation
	for state: String in ["paused","reward"]:
		sim.state = state
		sim.tick(.8)
		var still := _paint(sim,pea)
		check(pea == before and still.mouth == frozen_mouth and still.painted_rotation == frozen_rotation,state+" freezes the exact ongoing shot swing")
	sim.state = "running"
	sim.tick(.1)
	check(float(pea.shoot_age)>float(before.shoot_age) and _paint(sim,pea).painted_rotation != frozen_rotation,"resuming advances the existing swing without retriggering a release")
	var idle_sim = _sim()
	var idle := _place(idle_sim,"pea",360)
	var min_angle := INF
	var max_angle := -INF
	var casts := 0
	for frame in 240:
		idle_sim.battle_devices.tick(idle_sim,1.0/60.0)
		var probe := _paint(idle_sim,idle)
		min_angle = minf(min_angle,probe.painted_rotation)
		max_angle = maxf(max_angle,probe.painted_rotation)
		for event: Dictionary in idle_sim.drain_events():
			if str(event.kind) == "device_pea_cast": casts += 1
	check(casts == 0 and idle_sim.battle_devices.shots.is_empty(),"no target produces no phantom release")
	check(max_angle-min_angle>.01 and max_angle-min_angle<.035,"no target retains quiet breathing without the large shooting beat")
	observations.pause = {"frozen_mid_shot_age":before.shoot_age,"no_target_angle_span":max_angle-min_angle}

func _wallnut_ground_contact() -> void:
	var cases := 0
	var maximum_gap := 0.0
	for row: float in [160.0,360.0,560.0]:
		var sim = _sim()
		var nut := _place(sim,"barricade",row)
		for ratio: float in [1.0,.66,.33]:
			var next_hp := float(nut.max_hp)*ratio
			sim.damage_construct(int(nut.id),float(nut.hp)-next_hp)
			var expected_texture: Texture2D = DeviceVfx.NUT_IDLE if ratio>.66 else DeviceVfx.NUT_CRACKED if ratio>.33 else DeviceVfx.NUT_BROKEN
			for time: float in [0.0,.125,.4,1.1,2.5]:
				var probe := _paint(sim,nut,time)
				var depth := GroundProjection.depth_scale(nut.pos)
				var center := GroundProjection.project(nut.pos)+Vector2(0,3)*depth
				check(probe.texture == expected_texture,"real construct damage selects its correct intact/cracked/broken atlas")
				check(probe.shadows.size() == 2 and probe.drawing_order.slice(0,3) == ["shadow","shadow","sprite"],"both Wall-nut contact shadows paint behind every HP and animation state")
				if probe.shadows.size() != 2: continue
				for shadow: Dictionary in probe.shadows:
					check(Vector2(shadow.center).distance_to(center)<.001 and float(shadow.color.a)>=.2,"Wall-nut contact shadow stays fixed and visible at every depth")
				check(float(probe.shadows[0].radius)>probe.destination.size.x*.35 and float(probe.shadows[0].radius)<probe.destination.size.x*.6,"Wall-nut shadow width follows actual sprite size")
				var image := probe.texture.get_image()
				var bottom := -1
				for y in range(int(probe.source.end.y)-1,int(probe.source.position.y)-1,-1):
					for x in range(int(probe.source.position.x),int(probe.source.end.x)):
						if image.get_pixel(x,y).a>.5:
							bottom = y
							break
					if bottom>=0: break
				var contact_y := probe.destination.position.y+(float(bottom)+.5-probe.source.position.y)/probe.source.size.y*probe.destination.size.y
				var gap := absf(contact_y-center.y)
				maximum_gap = maxf(maximum_gap,gap)
				check(bottom>=0 and gap<5.0*depth,"the opaque nut foot meets its shadow rather than floating above it")
				cases += 1
	observations.wallnut = {"painted_cases":cases,"max_opaque_foot_gap_pixels":maximum_gap,"damage_states":3,"depths":3,"animation_phases":5}
