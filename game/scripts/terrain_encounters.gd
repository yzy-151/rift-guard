extends RefCounted
## Additive encounters and obstacles with full clearance around every road.
const Terrain = preload("res://scripts/functional_terrain.gd")

static func features(stage_id: String, layout_id: String = "blood_gate") -> Array[Dictionary]:
	var rows: Array = []
	match stage_id:
		"stage_01": rows = [["relay", Rect2(580,384,64,64)]]
		"stage_02": rows = [["relay",Rect2(605,325,64,64)], ["spring",Rect2(385,435,64,64)]]
		"stage_03": rows = [["relay",Rect2(450,265,64,64)], ["spring",Rect2(350,425,64,64)], ["wind_lane",Rect2(460,510,410,40)]]
		"stage_04": rows = [["wind_lane",Rect2(700,270,350,42)], ["spring",Rect2(355,425,64,64)], ["relay",Rect2(500,440,64,64)]]
		"stage_05": rows = [["hazard_lane",Rect2(570,300,480,42)], ["spring",Rect2(450,450,64,64)], ["relay",Rect2(420,190,64,64)], ["wind_lane",Rect2(660,395,380,42)]]
		"stage_06": rows = [["relay",Rect2(625,190,64,64),Vector2.RIGHT,240.0], ["spring",Rect2(360,300,64,64)], ["wind_lane",Rect2(560,395,350,40)], ["hazard_lane",Rect2(645,490,380,42)]]
		"stage_07": rows = [["relay",Rect2(440,295,64,64)], ["spring",Rect2(350,435,64,64)], ["wind_lane",Rect2(630,225,400,40)], ["hazard_lane",Rect2(690,435,360,42)]]
		"stage_08": rows = [["relay",Rect2(410,220,64,64)], ["spring",Rect2(350,430,64,64)], ["wind_lane",Rect2(490,490,390,40)], ["hazard_lane",Rect2(570,285,405,42)]]
		"stage_endless":
			match layout_id:
				"frost_isles": rows = [["relay",Rect2(1130,590,64,64)], ["spring",Rect2(1110,850,64,64)], ["wind_lane",Rect2(720,480,480,70)], ["wind_lane",Rect2(1450,540,540,70),Vector2.LEFT], ["hazard_lane",Rect2(1490,870,500,60)]]
				"wind_cross": rows = [["relay",Rect2(1160,630,64,64)], ["spring",Rect2(1490,630,64,64)], ["wind_lane",Rect2(700,790,480,65)], ["wind_lane",Rect2(1510,580,510,65),Vector2.LEFT], ["hazard_lane",Rect2(820,1080,480,60)]]
				_: rows = [["relay",Rect2(930,555,64,64)], ["spring",Rect2(1520,850,64,64)], ["wind_lane",Rect2(950,920,560,60)], ["wind_lane",Rect2(1040,440,560,60),Vector2.LEFT], ["hazard_lane",Rect2(1420,645,400,60)]]
	var result: Array[Dictionary] = []
	for index in rows.size():
		var row: Array = rows[index]
		var direction: Vector2 = row[2] if row.size() > 2 else Vector2.RIGHT
		var options := {"length":float(row[3])} if row.size() > 3 else {}
		var id := "%s_%s_%s_%d" % [stage_id, layout_id if stage_id == "stage_endless" else "encounter", str(row[0]), index]
		result.append(Terrain.create(str(row[0]), id, Rect2(row[1]), direction, options))
	return result

static func obstacles(sim) -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if sim.endless_mode:return result
	var candidates:Array[Rect2]=[]
	for y in range(148,533,24):
		for x in range(64,1168,36):candidates.append(Rect2(x,y,72,48))
	var stage:=int(str(sim.current_stage_id).trim_prefix("stage_"))
	var anchor:=Vector2(520+stage*23,300+posmod(stage,3)*50)
	candidates.sort_custom(func(a:Rect2,b:Rect2)->bool:return a.get_center().distance_squared_to(anchor)<b.get_center().distance_squared_to(anchor))
	for area:Rect2 in candidates:
		var clear:=true
		for route:Array in sim.stage_routes().values():
			for i in range(1,route.size()):
				if sim._segment_hits_rect(route[i-1],route[i],area.grow(48)):clear=false;break
			if not clear:break
		if not clear:continue
		for feature:Dictionary in sim.terrain_features+result:
			if str(feature.get("type",""))=="weather":continue
			if area.grow(16).intersects(feature.area):clear=false;break
			if feature.has("effect_area") and area.grow(16).intersects(feature.effect_area):clear=false;break
		if not clear:continue
		result.append({"id":"v93_obstacle_%s_%d"%[sim.current_stage_id,result.size()],"type":"blocked","label":"断墙废墟" if result.size()%2 else "路侧岩垒","appearance":"ruin" if result.size()%2 else "stone","area":area,"base_area":area,"clock":0.0,"timer":0.0,"hp":0.0,"max_hp":0.0,"collision_scale":[1.0,1.0]})
		if result.size()>=3:break
	return result
