extends RefCounted
## Existing arena coordinates and navigation grid; each choice has real terrain.
const OPTIONS := [
	{"id":"blood_gate","name":"血门回廊","description":"四方血门与环墙，破门制造逃生通道。","theme_id":"crimson"},
	{"id":"frost_isles","name":"霜汐群岛","description":"错落冰岛与滞缓浅滩，宽阔走廊适合贯穿法术。","theme_id":"frost"},
	{"id":"wind_cross","name":"风蚀交叉庭","description":"十字断墙与四角高台，交替转移避开夹击。","theme_id":"wind"}
]

static func valid(id: String) -> bool:
	return OPTIONS.any(func(row: Dictionary)->bool: return str(row.id)==id)

static func definition(base: Dictionary, id: String) -> Dictionary:
	var result := base.duplicate(true)
	for option: Dictionary in OPTIONS:
		if str(option.id)==id:
			result.layout_id=id
			result.layout_name=option.name
			result.theme_id=option.theme_id
	if id=="blood_gate": return result
	var terrain: Array[Dictionary] = []
	if id=="frost_isles":
		for position: Vector2 in [Vector2(480,300),Vector2(1020,200),Vector2(1660,340),Vector2(660,940),Vector2(1430,1020),Vector2(2070,900)]:
			terrain.append(feature("blocked",Rect2(position,Vector2(210,150)),"霜岩岛"))
		for position: Vector2 in [Vector2(580,560),Vector2(1540,730)]:
			var water := feature("low_ground",Rect2(position,Vector2(430,100)),"寒潮浅滩")
			water.speed_scale=0.62
			terrain.append(water)
	else:
		for area: Rect2 in [Rect2(1090,170,75,340),Rect2(1390,910,75,340),Rect2(350,610,530,65),Rect2(1710,770,530,65)]:
			terrain.append(feature("blocked",area,"风蚀断墙"))
		for position: Vector2 in [Vector2(760,350),Vector2(1560,350),Vector2(760,920),Vector2(1560,920)]:
			var platform := feature("high_ground",Rect2(position,Vector2(210,120)),"回风高台")
			platform.attack_bonus=0.16
			platform.range_bonus=1.0
			terrain.append(platform)
	result.terrain=terrain
	return result

static func feature(type: String, area: Rect2, label: String) -> Dictionary:
	return {"id":"%s_%d_%d" % [type,area.position.x,area.position.y],"type":type,"rect":[area.position.x,area.position.y,area.size.x,area.size.y],"label":label}
