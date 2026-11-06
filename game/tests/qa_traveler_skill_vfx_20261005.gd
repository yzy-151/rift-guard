extends SceneTree
## Deterministic gameplay snapshots exclude cosmetic events and visual fields.
const Sim = preload("res://scripts/combat_simulation.gd")
const OUT = "res://../outputs/traveler_skill_vfx_20261005/"
var checks := 0
var failures: Array[String] = []

class DrawProbe extends RefCounted:
	var sim = Sim.new(71,true)
	var reduced_effects := false
	var calls: Array[Dictionary] = []
	func world_to_screen(point: Vector2) -> Vector2: return point
	func world_depth_scale(_point: Vector2) -> float: return 1.0
	func draw_line(a: Vector2,b: Vector2,color: Color,width: float,_aa: bool=true) -> void:
		calls.append({"kind":"line","points":[a,b],"color":color,"width":width})
	func draw_polyline(points: PackedVector2Array,color: Color,width: float,_aa: bool=true) -> void:
		calls.append({"kind":"polyline","points":points,"color":color,"width":width})
	func draw_colored_polygon(points: PackedVector2Array,color: Color,uv: PackedVector2Array=PackedVector2Array(),texture: Texture2D=null) -> void:
		calls.append({"kind":"polygon" if texture==null else "texture_polygon","points":points,"color":color,"uv":uv,"texture":texture})
	func draw_circle(point: Vector2,radius: float,color: Color) -> void:
		calls.append({"kind":"circle","points":[point],"radius":radius,"color":color})
	func draw_texture_rect(_texture: Texture2D,rect: Rect2,_tile: bool,color: Color) -> void:
		calls.append({"kind":"texture","points":[rect.position,rect.end],"color":color})
	func draw_rect(rect: Rect2,color: Color) -> void:
		calls.append({"kind":"rect","points":[rect.position,rect.end],"color":color})
	func _draw_dedicated_arc(c: Vector2,r: Vector2,a: float,b: float,color: Color,width: float) -> void:
		calls.append({"kind":"ellipse","points":[c],"radii":r,"start":a,"end":b,"color":color,"width":width})

class GlowProbe extends DrawProbe:
	var emissions: Array[Dictionary] = []
	func emit_glow(_texture: Texture2D,point: Vector2,size: Vector2,color: Color,alpha: float) -> void:
		emissions.append({"point":point,"size":size,"color":color,"alpha":alpha})

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func _initialize() -> void: call_deferred("run")

func fixture(element: String, ultimate: bool) -> Dictionary:
	var sim = Sim.new(71305, true)
	var squad: Array[String] = ["traveler", "hero_03"]
	sim.reset_stage("stage_02", squad, 71305)
	sim.start()
	sim.enemies.clear(); sim.enemy_lookup.clear(); sim.terrain_features.clear()
	var hero: Dictionary = sim.heroes[0]
	hero.element = "" if element == "none" else element
	hero.pos = Vector2(350,360); hero.target = hero.pos; hero.deployed = true; hero.energy = hero.max_energy
	var ally: Dictionary = sim.heroes[1]
	ally.pos = Vector2(680,360); ally.target = ally.pos; ally.deployed = true; ally.hp = 100
	for point in [Vector2(520,360),Vector2(680,360),Vector2(790,360),Vector2(885,385),Vector2(1150,560)]:
		var enemy: Dictionary = sim.spawn_enemy(point,"grunt")
		enemy.hp=100000; enemy.max_hp=100000; enemy.armor=0; enemy.shield=0
	sim.events.clear()
	var accepted: bool = sim.activate_hero_ultimate(0,Vector2(720,360)) if ultimate else sim.activate_hero_skill(0,Vector2(720,360))
	var snapshots: Array[Dictionary] = []
	var damage_events: Array[Dictionary] = []
	var cosmetic_kinds: Array[String] = []
	for frame in range(481):
		if frame > 0:
			sim.elapsed += 1.0/60.0
			sim._pending_impact_tick(1.0/60.0)
			sim._skill_effect_tick(1.0/60.0)
		for event: Dictionary in sim.drain_events():
			if str(event.kind) in ["hit","hurt","heal","crystal_guard"]:
				damage_events.append({"frame":frame,"kind":event.kind,"value":event.get("value",0),"enemy_id":event.get("enemy_id",-1),"hero_id":event.get("hero_id",-1)})
			if str(event.kind).begins_with("traveler_fx_") or str(event.kind) in ["skill_anemo","skill_none"]:
				if not str(event.kind) in cosmetic_kinds: cosmetic_kinds.append(str(event.kind))
		if frame in [0,6,24,48,108,264,468,480]:
			var enemies: Array[Dictionary] = []
			for enemy: Dictionary in sim.enemies:
				enemies.append({"id":enemy.id,"hp":snappedf(enemy.hp,.001),"x":snappedf(enemy.pos.x,.001),"y":snappedf(enemy.pos.y,.001),"frozen":snappedf(enemy.frozen_timer,.001),"slow":snappedf(enemy.slow_timer,.001)})
			snapshots.append({"frame":frame,"enemies":enemies,"ally_hp":snappedf(ally.hp,.001),"shield":snappedf(sim.crystal_shield,.001),"zones":sim.skill_effects.size(),"constructs":sim.geo_constructs.size()})
	return {"accepted":accepted,"snapshots":snapshots,"damage_events":damage_events,"cosmetic_kinds":cosmetic_kinds}

func gameplay(record: Dictionary) -> Dictionary:
	var value := record.duplicate(true)
	value.erase("cosmetic_kinds")
	return value

func run() -> void:
	var results: Dictionary = {}
	for element in ["none","anemo","electro","pyro","hydro","geo","cryo"]:
		for ultimate in [false,true]:
			var key: String = element + ("_e" if ultimate else "_q")
			results[key] = fixture(element,ultimate)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if "--write-baseline" in OS.get_cmdline_user_args():
		var file := FileAccess.open(OUT+"mechanics-baseline.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(results,"\t")); file.close()
		print("TRAVELER BASELINE: 14 Q/E fixtures written")
		quit(0); return
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"mechanics-baseline.json"))
	for key: String in results:
		check(results[key].accepted,key+" accepted")
		var normalized: Dictionary = JSON.parse_string(JSON.stringify(gameplay(results[key])))
		check(normalized == gameplay(baseline[key]),key+" gameplay unchanged")
	check(results.anemo_q.cosmetic_kinds == baseline.anemo_q.cosmetic_kinds,"wind Q events unchanged")
	check("skill_anemo" in results.anemo_q.cosmetic_kinds and not "traveler_fx_start" in results.anemo_q.cosmetic_kinds,"wind Q retains legacy tornado")
	var helper = load("res://scripts/traveler_skill_vfx_20261005.gd")
	for element in ["none","anemo","electro","pyro","hydro","geo","cryo"]:
		for ultimate in [false,true]:
			var key: String = element + ("_e" if ultimate else "_q")
			check(helper.supports(key) == (key != "anemo_q"),key+" explicit VFX coverage")
	var probe := DrawProbe.new()
	var draws: Dictionary = {}
	for key: String in helper.KEYS:
		probe.calls.clear()
		var event: Dictionary = {"kind":"traveler_fx_hit","skill":key,"element":key.get_slice("_",0),"pos":Vector2(720,360),"source":Vector2(350,360),"radius":170.0,"total":.5,"life":.4,"step":5}
		helper.event(probe,event)
		check(not probe.calls.is_empty(),key+" impact draws new VFX")
		draws[key] = probe.calls.size()
		var valid := true
		for draw: Dictionary in probe.calls:
			for point: Vector2 in draw.points:
				if not point.is_finite(): valid=false
			if draw.has("radii") and not Vector2(draw.radii).is_equal_approx(probe.sim.ability_area_screen_radii(event.pos,event.radius)*float(draw.radii.x/probe.sim.ability_area_screen_radii(event.pos,event.radius).x)): valid=false
		check(valid,key+" finite geometry and ground ellipses preserve aspect")
		probe.calls.clear();event.life=0
		helper.event(probe,event)
		check(probe.calls.is_empty(),key+" cosmetic tail expires within half a second")
		probe.calls.clear();event.kind="traveler_fx_cast";event.total=.34;event.life=.19
		helper.event(probe,event)
		check(not probe.calls.is_empty(),key+" cast draws new VFX")
		probe.calls.clear();event.kind="traveler_fx_arc";event.total=.25;event.life=.16
		event.targets=[Vector2(670,355),Vector2(810,370)]
		helper.event(probe,event)
		check(not probe.calls.is_empty(),key+" actual-target arc renderer reachable")
	for key in ["hydro_q","hydro_e","electro_e","cryo_q","cryo_e","anemo_e","pyro_e"]:
		probe.calls.clear()
		helper.zone(probe,{"kind":key,"element":str(key).get_slice("_",0),"pos":Vector2(720,360),"source":Vector2(350,360),"direction":Vector2.RIGHT,"radius":170.0,"elapsed":.1,"life":3.0,"step":0})
		check(not probe.calls.is_empty(),key+" continuing skill renderer reachable")
	probe.calls.clear()
	helper.event(probe,{"kind":"traveler_fx_hit","skill":"anemo_q"})
	check(probe.calls.is_empty(),"wind Q cannot enter replacement renderer")
	for kind in ["traveler_none_cast","traveler_none_impact","neutral_starfall_cast","neutral_starfall_impact"]:
		probe.calls.clear()
		check(helper.legacy_event(probe,{"kind":kind,"pos":Vector2(720,360),"radius":170.0,"total":.5,"life":.4}) and not probe.calls.is_empty(),kind+" legacy entry covered")
	probe.calls.clear()
	check(helper.legacy_event(probe,{"kind":"traveler_anemo_cast","pos":Vector2(720,360),"radius":135,"total":.34,"life":.15}) and not probe.calls.is_empty(),"wind Q cast now reaches its new sword-wind visual hook")
	probe.calls.clear()
	var density_event: Dictionary={"kind":"traveler_fx_hit","skill":"cryo_e","element":"cryo","pos":Vector2(720,360),"radius":315.0,"total":.48,"life":.35,"step":4}
	helper.event(probe,density_event)
	var full_count := probe.calls.size()
	probe.calls.clear();probe.reduced_effects=true
	helper.event(probe,density_event)
	check(probe.calls.size()<full_count,"low-effects mode reduces particle and glow draw count")
	probe.calls.clear();probe.reduced_effects=false
	helper.construct(probe,{"pos":Vector2(720,360),"hp":100,"max_hp":200})
	check(probe.calls.any(func(draw: Dictionary):return draw.kind=="polygon" and draw.points.size()==12),"Geo construct draws the rounded Starfell Sword shell from the in-game reference")
	probe.calls.clear()
	helper.construct(probe,{"pos":Vector2(720,360),"hp":100,"max_hp":200,"device":true})
	check(probe.calls.is_empty(),"Starfell Sword renderer excludes device barricade")
	var glow_probe := GlowProbe.new()
	helper.event(glow_probe,{"kind":"traveler_fx_hit","skill":"cryo_q","element":"cryo","pos":Vector2(720,360),"radius":165.0,"total":.36,"life":.35})
	check(not glow_probe.emissions.is_empty() and not glow_probe.calls.any(func(draw: Dictionary):return draw.kind=="texture"),"battle view glow API receives all halo textures without duplicate alpha-blended fallback")
	check(glow_probe.emissions.any(func(glow: Dictionary):return glow.alpha>=.90 and glow.size.x>=46),"impact peak requests a conspicuous additive white core or halo")
	glow_probe = null
	probe = null
	var report := {"checks":checks,"failures":failures,"fixtures":results,"draws":draws}
	var file := FileAccess.open(OUT+"validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("TRAVELER SKILL VFX QA: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
