extends SceneTree
const TravelerQA = preload("res://tests/qa_traveler_skill_vfx_20261005.gd")
const Wind = preload("res://scripts/wind_skill_vfx_20261005.gd")
const TravelerVfx = preload("res://scripts/traveler_skill_vfx_20261005.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func geometry(probe) -> bool:
	for call: Dictionary in probe.calls:
		if call.kind in ["polygon","texture_polygon"]:
			if Geometry2D.triangulate_polygon(PackedVector2Array(call.points)).is_empty():
				push_warning("Invalid wind face " + str(call.points))
				return false
		for point: Vector2 in call.points:
			if not point.is_finite(): return false
	return true
func _initialize() -> void:
	var probe=TravelerQA.GlowProbe.new()
	var valid := true
	var faces := 0
	var maximum := Vector2.ZERO
	for frame in range(1,102):
		probe.calls.clear();probe.emissions.clear()
		Wind.anemo_tornado(probe,{"kind":"anemo_tornado","pos":Vector2(720,360),"total_life":4.2,"life":4.2-float(frame)/24,"area":1.0})
		valid=valid and geometry(probe)
		var bounds := Rect2()
		var first := true
		for call: Dictionary in probe.calls:
			if call.kind not in ["polygon","texture_polygon"]: continue
			faces+=1
			for point: Vector2 in call.points:
				if first: bounds=Rect2(point,Vector2.ZERO);first=false
				else: bounds=bounds.expand(point)
		maximum.x=maxf(maximum.x,bounds.size.x);maximum.y=maxf(maximum.y,bounds.size.y)
	check(valid,"solid wind-cloud body and flying blade faces triangulate at every real 24-FPS capture time")
	check(faces>100 and maximum.x<132 and maximum.y<165,"tornado cloud remains a compact body around 122 by 154 pixels")
	probe.calls.clear()
	Wind.anemo_tornado(probe,{"kind":"anemo_tornado","pos":Vector2(720,360),"total_life":4.2,"life":3.0,"area":1.0})
	check(probe.calls.filter(func(call: Dictionary):return call.kind=="texture_polygon").size()==1,"tornado uses exactly one opaque cloud body without stacked spring coils")
	probe.calls.clear();probe.reduced_effects=true
	Wind.anemo_tornado(probe,{"kind":"anemo_tornado","pos":Vector2(720,360),"total_life":4.2,"life":3.0,"area":1.0})
	check(probe.calls.size()==2 and probe.calls[0].kind=="texture_polygon","low-effects mode keeps one clear cheap cloud draw and only the ground ellipse")
	probe.calls.clear();probe.reduced_effects=false
	var fallback_valid := true
	for frame in range(1,102):
		probe.calls.clear()
		Wind.anemo_tornado_fallback(probe,{"kind":"anemo_tornado","pos":Vector2(720,360),"total_life":4.2,"life":4.2-float(frame)/24,"area":1.0})
		fallback_valid=fallback_valid and geometry(probe)
	check(fallback_valid,"unused procedural fallback also uses valid split faces at every real capture phase")
	probe.calls.clear()
	Wind._quad(probe,Vector2(0,0),Vector2(10,10),Vector2(0,10),Vector2(10,0),Color.WHITE)
	check(probe.calls.size()==2 and geometry(probe),"a folded bow-tie quad becomes two valid actual ribbon faces")
	probe.calls.clear()
	Wind._quad(probe,Vector2.ZERO,Vector2(10,0),Vector2(20,0),Vector2(30,0),Color.WHITE)
	check(probe.calls.is_empty(),"zero-area ribbon faces are skipped without triangulation errors")
	for heading in 12:
		probe.calls.clear();probe.emissions.clear()
		Wind.crescent(probe,Vector2.ZERO,Vector2.from_angle(float(heading)*TAU/12),Vector2(37,55),Color("#65dfff"),1,true)
		check(geometry(probe),"crescent blade and short tail triangulate at heading %d" % heading)
		check(probe.calls.any(func(call: Dictionary):return call.kind=="polygon") and not probe.calls.any(func(call: Dictionary):return call.kind in ["line","polyline"]),"crescent is a filled blade surface instead of an empty arc at heading %d" % heading)
	for key: String in ["none_q","anemo_e","hydro_e"]:
		probe.calls.clear()
		TravelerVfx.event(probe,{"kind":"traveler_fx_hit","skill":key,"element":key.get_slice("_",0),"pos":Vector2(720,360),"source":Vector2(350,360),"radius":165,"total":.48,"life":.38,"step":6})
		check(geometry(probe),key+" replacement impact triangulates")
		if key!="none_q":
			probe.calls.clear()
			TravelerVfx.zone(probe,{"kind":key,"element":key.get_slice("_",0),"pos":Vector2(720,360),"source":Vector2(350,360),"direction":Vector2.RIGHT,"radius":200,"elapsed":1.0,"life":2.0,"step":3})
			check(geometry(probe),key+" moving sword-wind zone triangulates")
	probe.calls.clear()
	Wind.anemo_tornado(probe,{"kind":"anemo_tornado","pos":Vector2.ZERO,"total_life":4.2,"life":0,"area":1.0})
	check(probe.calls.is_empty(),"expired wind column leaves no cosmetic geometry")
	probe=null
	var path := ProjectSettings.globalize_path("res://../qa/wind_skill_vfx_20261005/validation.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"tornado_extent":maximum,"ribbon_faces_checked":faces},"\t"));file.close()
	print("WIND SOLID GEOMETRY QA: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
