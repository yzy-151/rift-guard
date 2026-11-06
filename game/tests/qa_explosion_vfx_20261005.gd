extends SceneTree
const Blast = preload("res://scripts/explosion_vfx_20261005.gd")
var checks := 0
var failures: Array[String] = []

class AreaProbe extends RefCounted:
	var enemies: Array = []
	func ability_area_screen_radii(_world: Vector2,radius: float) -> Vector2: return Vector2(radius,radius*.48)

class DrawProbe extends RefCounted:
	var sim = AreaProbe.new()
	var reduced_effects := false
	var depth := 1.0
	var calls: Array[Dictionary] = []
	var lights: Array[Dictionary] = []
	func world_to_screen(point: Vector2) -> Vector2: return point+Vector2(23,11)
	func world_depth_scale(_point: Vector2) -> float: return depth
	func draw_colored_polygon(points: PackedVector2Array,color: Color) -> void: calls.append({"kind":"polygon","points":points,"color":color})
	func draw_texture_rect_region(texture: Texture2D,rect: Rect2,region: Rect2,color: Color) -> void: calls.append({"kind":"sheet","points":[rect.position,rect.end],"texture":texture,"region":region,"color":color})
	func draw_texture_rect(texture: Texture2D,rect: Rect2,_tile: bool,color: Color) -> void: calls.append({"kind":"texture","points":[rect.position,rect.end],"texture":texture,"color":color})
	func emit_glow(_texture: Texture2D,point: Vector2,size: Vector2,color: Color,alpha: float) -> void: lights.append({"point":point,"size":size,"color":color,"alpha":alpha})
	func reset() -> void: calls.clear();lights.clear()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)

func valid_geometry(probe) -> bool:
	for call: Dictionary in probe.calls:
		for point: Vector2 in call.points:
			if not point.is_finite(): return false
		if call.kind=="polygon" and Geometry2D.triangulate_polygon(call.points).is_empty(): return false
		if call.color.a<0.0 or call.color.a>1.0: return false
		if call.kind=="sheet":
			var region: Rect2=call.region
			if region.position.x<0 or region.position.y<0 or region.end.x>call.texture.get_width()+.01 or region.end.y>call.texture.get_height()+.01: return false
	for light: Dictionary in probe.lights:
		if not Vector2(light.point).is_finite() or not Vector2(light.size).is_finite() or minf(light.size.x,light.size.y)<=0 or light.alpha<0.0 or light.alpha>1.0: return false
	return true

func _initialize() -> void:
	var probe := DrawProbe.new()
	var full_max := 0
	var lean_max := 0
	var polygon_count := 0
	for element: String in ["pyro","cryo","hydro","electro","anemo","geo","none"]:
		var full_valid := true
		var lean_valid := true
		for depth: float in [.5,1.0,1.4]:
			probe.depth=depth
			for radius: float in [1.0,60.0,150.0,1000.0]:
				for frame in 29:
					var age := float(frame)/60.0
					probe.reset();probe.reduced_effects=false
					Blast.draw(probe,Vector2(690,350),age,radius,element,.48,.71)
					full_valid=full_valid and valid_geometry(probe)
					full_max=maxi(full_max,probe.calls.size()+probe.lights.size())
					polygon_count+=probe.calls.filter(func(call: Dictionary):return call.kind=="polygon").size()
					probe.reset();probe.reduced_effects=true
					Blast.draw(probe,Vector2(690,350),age,radius,element,.48,.71)
					lean_valid=lean_valid and valid_geometry(probe)
					lean_max=maxi(lean_max,probe.calls.size()+probe.lights.size())
		check(full_valid,element+" fire / magic cloud geometry triangulates at 29 phases and 12 scale cases")
		check(lean_valid,element+" low-effects cloud geometry stays valid at every scale / frame")
	check(full_max<=Blast.MAX_DRAW_CALLS,"normal explosion has a strict per-effect draw budget")
	check(lean_max<=Blast.MAX_LEAN_DRAW_CALLS,"low-effects explosion keeps only cloud and compact grounded shadow")
	probe.depth=1.0;probe.reduced_effects=false
	for style: String in ["compact","ice"]:
		for heading in 12:
			var valid := true
			for frame in 61:
				probe.reset()
				Blast.impact(probe,Vector2.ZERO,Color("#a2eaff"),float(frame)/60.0,1.55,false,float(heading)/12.0,Vector2(540,230),style)
				valid=valid and valid_geometry(probe)
				full_max=maxi(full_max,probe.calls.size()+probe.lights.size())
			check(valid,style+" compact shield / hit geometry at heading "+str(heading))
	probe.reset()
	Blast.impact(probe,Vector2.ZERO,Color("#a2eaff"),.2,.68,false,.13)
	check(probe.lights.is_empty() and probe.calls.any(func(call:Dictionary):return call.kind=="texture"),"local impact never submits local ZERO as an absolute additive glow coordinate")
	probe.reset()
	Blast.impact(probe,Vector2.ZERO,Color("#a2eaff"),.2,.68,false,.13,Vector2(610,330))
	check(probe.lights.size()==1 and Vector2(probe.lights[0].point)==Vector2(610,330),"explicit screen-space glow center respects the parent transform")
	probe.reset();probe.reduced_effects=true
	Blast.impact(probe,Vector2.ZERO,Color("#a2eaff"),.2,.68,true,.13)
	check(probe.calls.size()<=Blast.MAX_LEAN_DRAW_CALLS and probe.lights.is_empty(),"normal hit stays small and cheap in low-effects mode")
	probe.reduced_effects=false
	for kind: String in Blast.KINDS:
		probe.reset()
		var event := {"kind":kind,"pos":Vector2(600,330),"radius":150,"total":.48,"life":.38,"enemy_id":7}
		var before := event.duplicate(true)
		check(Blast.event(probe,event) and not probe.calls.is_empty(),kind+" reaches filled replacement renderer")
		check(event==before and probe.sim.enemies.is_empty(),kind+" rendering leaves event / simulation unchanged")
		if kind in ["shield_hit","shield_break"]:
			check(probe.calls.any(func(call:Dictionary):return call.kind=="sheet" and float(call.region.position.y)>0),kind+" uses the ice cloud / crystal row")
		probe.reset();event.life=0
		check(Blast.event(probe,event) and probe.calls.is_empty(),kind+" expired effect leaves no draw commands")
	probe.reset()
	check(not Blast.event(probe,{"kind":"traveler_fx_hit","pos":Vector2.ZERO}),"custom Electro and Traveler skill events remain outside this helper")
	check(probe.calls.is_empty(),"unsupported events produce no fallback rings")
	for age: float in [-.1,.48,.8,NAN,INF]:
		probe.reset();Blast.draw(probe,Vector2.ZERO,age,150)
		check(probe.calls.is_empty() and probe.lights.is_empty(),"invalid / expired explosion age rejected: "+str(age))
	probe.reset();probe.sim.enemies.resize(101)
	Blast.draw(probe,Vector2(600,330),.1,150)
	check(probe.calls.size()<=Blast.MAX_LEAN_DRAW_CALLS and probe.lights.is_empty(),"dense 101-enemy battles use the same cheap cloud budget automatically")
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/vfx/explosions_20261005/cartoon_blast_fire_ice_v1.png"))
	check(not image.is_empty() and image.get_format()==Image.FORMAT_RGBA8 and image.get_pixel(0,0).a==0,"new cloud sheet preserves genuine RGBA transparency")
	var source := FileAccess.get_file_as_string("res://scripts/explosion_vfx_20261005.gd")
	check(not ".draw_arc(" in source and not ".draw_line(" in source and not ".draw_polyline(" in source,"replacement contains no hollow arcs or radial outline lines")
	probe=null
	var report := {"checks":checks,"failures":failures,"normal_max_draw_calls":full_max,"lean_max_draw_calls":lean_max,"polygons_triangulated":polygon_count,"sprite_sheet_size":Vector2(image.get_size())}
	var path := ProjectSettings.globalize_path("res://../qa/explosion_vfx_20261005/validation.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("FILLED EXPLOSION QA: %d checks, %d failures; %d polygons; full %d / lean %d" % [checks,failures.size(),polygon_count,full_max,lean_max])
	quit(0 if failures.is_empty() else 1)
