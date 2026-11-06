extends SceneTree
const PLANTS = preload("res://scripts/pvz_plant_visual.gd")
const VFX = preload("res://scripts/battle_device_vfx.gd")
const SIM = preload("res://scripts/combat_simulation.gd")
var checks := 0
var failures: Array[String] = []
var max_old_root_drift := 0.0
var max_root_drift := 0.0

class PaintProbe:
	extends RefCounted
	var regions: Array = []
	var shadows: Array = []
	var transforms: Array[Vector2] = []
	func world_to_screen(p: Vector2) -> Vector2: return p*Vector2(1.2,.7)+Vector2(10,20)
	func world_depth_scale(_p: Vector2) -> float: return 1.3
	func draw_ellipse_shadow(p: Vector2, r: float, color: Color) -> void: shadows.append([p,r,color])
	func draw_texture_rect_region(tex: Texture2D, dst: Rect2, src: Rect2) -> void: regions.append([tex,dst,src])
	func draw_texture_rect(_tex: Texture2D, _dst: Rect2, _tile: bool) -> void: pass
	func draw_set_transform(p: Vector2, _rotation: float = 0.0) -> void: transforms.append(p)
	func draw_circle(_p: Vector2, _r: float, _color: Color) -> void: pass

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func point(data: Array) -> Vector2: return Vector2(float(data[0]),float(data[1]))

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://qa/crowded_20261005/melon_anchor_reference.json"))
	check(FileAccess.get_sha256("res://../research/pvz-original-20261005/melon-native/Melonpult.reanim") == reference.source_sha256,"independent authored track reference matches original source")
	for key: String in ["melon","melon_shoot"]:
		check(FileAccess.get_sha256("res://assets/world/pvz_botany_20261005/"+key+".png") == reference.atlas_sha256[key],key+" source sprite pixels unchanged")
		var info: Dictionary = PLANTS.metadata(key)
		check((point(info.foot)+point(info.source_crop)).is_equal_approx(point(reference.source_foot)),key+" crop restores shared original root")
	var idle_reference: Dictionary = reference.animations.melon
	var base_source := point(idle_reference.leaf_landmarks[0])+point(idle_reference.source_crop)
	var probe := PaintProbe.new()
	var origin := Vector2(650,450)
	var unit := float(PLANTS.metadata("melon").unit)*probe.world_depth_scale(origin)
	var baseline := probe.world_to_screen(origin)+PLANTS.GROUND*probe.world_depth_scale(origin)+(base_source-point(reference.source_foot))*unit
	var shadow := probe.world_to_screen(origin)+PLANTS.GROUND*probe.world_depth_scale(origin)-Vector2(0,9)
	# Two complete attacks: idle, throw, return to idle, then throw and return again.
	for step in 261:
		var elapsed := float(step)*.025
		var phase := fposmod(elapsed,2.6)
		var age := phase-.35 if phase>=.35 else 999.0
		var device := {"kind":"melon","visual_variant":"melon","pos":origin,"cell":Rect2(origin-Vector2(30,20),Vector2(60,40)),"visual_time":elapsed,"shoot_age":age,"hp":100,"max_hp":100}
		var before: Dictionary = device.duplicate(true)
		probe.regions.clear(); probe.shadows.clear()
		PLANTS.draw(probe,device)
		var key := "melon_shoot" if age<.70 else "melon"
		var time := PLANTS.melon_shoot_time(age) if age<.70 else elapsed
		var frame := PLANTS.frame_at(key,time)
		var authored: Dictionary = reference.animations[key]
		var leaf_in_atlas := point(authored.leaf_landmarks[frame])
		var painted_leaf := Rect2(probe.regions[0][1]).position+leaf_in_atlas*unit
		var expected := probe.world_to_screen(origin)+PLANTS.GROUND*probe.world_depth_scale(origin)+(leaf_in_atlas+point(authored.source_crop)-point(reference.source_foot))*unit
		check(painted_leaf.distance_to(expected)<.0001,"original painted leaf correspondence through full attack "+str(step))
		max_root_drift=maxf(max_root_drift,painted_leaf.distance_to(baseline))
		var old_leaf := probe.world_to_screen(origin)+PLANTS.GROUND*probe.world_depth_scale(origin)+(leaf_in_atlas-point(reference.before[key].foot))*unit
		max_old_root_drift=maxf(max_old_root_drift,old_leaf.distance_to(baseline))
		check(painted_leaf.distance_to(baseline)<1.0,"only original subpixel rooted sway remains "+str(step))
		check(Vector2(probe.shadows[0][0]).distance_to(shadow)<.0001,"stationary original shadow across attack "+str(step))
		check(device==before,"drawing leaves collision position and placement cell untouched "+str(step))
	check(max_old_root_drift>40.0,"same authored landmark reproduces old >40 pixel slide")
	var info: Dictionary = PLANTS.metadata("melon_shoot")
	var release_leaf: Vector2 = probe.world_to_screen(origin)+PLANTS.GROUND*probe.world_depth_scale(origin)+(point(reference.animations.melon_shoot.mouths[int(info.release_frame)][0])-point(info.foot))*unit
	check(PLANTS.melon_release_screen(probe,origin).distance_to(release_leaf)<.0001,"release starts at the authored melon center of the actual throw frame")
	var shot := {"kind":"melon","pos":origin+Vector2(14,0),"visual_origin":origin,"model_origin":origin+Vector2(14,0),"target":origin+Vector2(300,0),"flight_time":0.0,"flight_total":.715,"arc_height":85.0,"visual_time":1.8}
	for progress: float in [0.0,.25,.5,.75,1.0]:
		shot.flight_time=progress*float(shot.flight_total)
		var before: Dictionary=shot.duplicate(true)
		probe.transforms.clear()
		VFX._melon_shot(probe,shot)
		var expected: Vector2=release_leaf.lerp(probe.world_to_screen(shot.target),progress)-Vector2(0,sin(progress*PI)*85.0)
		check(probe.transforms[0].distance_to(expected)<.0001,"fixed original release follows same arc and landing "+str(progress))
		check(shot==before,"visual arc never changes collision origin, target or flight timer "+str(progress))
	var sim=SIM.new(71005,true)
	var squad: Array[String]=["traveler","hero_03","hero_13"]
	sim.reset_stage("stage_02",squad,71005)
	sim.enemies.clear(); sim.enemy_lookup.clear(); sim.events.clear(); sim.terrain_features.clear()
	sim.state="running"; sim.run_state.crystal_level=5; sim.team_level=5
	sim.battle_devices.gold=5000
	check(sim.battle_devices.select(sim,"melon") and sim.battle_devices.place(sim,origin),"deploy real level5 melon for collision regression")
	var plant: Dictionary=sim.battle_devices.placed[0]
	var fixed_pos: Vector2=plant.pos
	var fixed_cell: Rect2=plant.cell
	var enemy: Dictionary=sim.spawn_enemy(fixed_pos+Vector2(320,0),"grunt")
	enemy.hp=100000.0; enemy.max_hp=enemy.hp; enemy.armor=0.0; enemy.affixes=[]
	var hp_before: float=enemy.hp
	for step in 140:
		sim.battle_devices.tick(sim,.05)
		check(Vector2(plant.pos)==fixed_pos and Rect2(plant.cell)==fixed_cell,"real consecutive attacks keep identical construct collision "+str(step))
	var hits := 0
	for event: Dictionary in sim.events:
		if event.kind=="device_melon_hit":
			hits+=1
			check(Vector2(event.pos)==Vector2(enemy.pos),"real fixed landing point unchanged")
	check(hits>=2,"real plant completes multiple unchanged attack cycles")
	check(is_equal_approx(hp_before-float(enemy.hp),185.0*hits),"real melon cadence and 185 splash damage unchanged")
	var report := {"checks":checks,"failures":failures,"before_root_drift_screen_pixels":max_old_root_drift,"after_root_drift_screen_pixels":max_root_drift,"two_complete_visual_cycles":true,"real_melon_hits":hits,"sprite_pixels_changed":false}
	var file := FileAccess.open("res://../qa/melon-alignment-20261005.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
