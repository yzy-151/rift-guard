extends SceneTree
const Art=preload("res://scripts/battle_environment_art.gd")
const Flat=preload("res://scripts/flat_stage_art.gd")
const Sim=preload("res://scripts/combat_simulation.gd")
var checks:=0
var failures:=0
class DrawSpy extends RefCounted:
	var sim
	var commands: Array=[]
	var regions: Array[Rect2]=[]
	func draw_rect(a,b,c=true,d=-1.0): commands.append(["rect",a,b,c,d])
	func draw_set_transform(a,b=0.0): commands.append(["transform",a,b])
	func draw_texture_rect_region(a,b,c,d=Color.WHITE):
		commands.append(["sprite",b,c,d,a.get_size()])
		regions.append(b)
	func draw_line(a,b,c,d=1.0,e=false): commands.append(["line",a,b,c,d,e])
	func draw_circle(a,b,c): commands.append(["circle",a,b,c])
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+label)
func _initialize() -> void:
	var sim=Sim.new()
	var squad: Array[String]=["traveler"]
	for i in 11:
		if i>=8: sim.select_endless_layout(["blood_gate","frost_isles","wind_cross"][i-8])
		sim.reset_stage("stage_%02d"%(i+1) if i<8 else "stage_endless",squad,91092)
		for feature: Dictionary in sim.terrain_features:
			var cells:=Flat.feature_rects(feature)
			var merged:=Art.merge_cells(cells)
			for cell: Rect2 in cells:
				for offset: Vector2 in [Vector2(0.05,0.05),Vector2(0.5,0.5),Vector2(0.95,0.95)]:
					var point:=cell.position+cell.size*offset
					check(merged.any(func(r:Rect2)->bool:return r.has_point(point)),"all occupied ground remains drawn")
			for patch: Rect2 in merged:
				for x in range(1,10):
					for y in range(1,10):
						var point:=patch.position+patch.size*Vector2(x/10.0,y/10.0)
						check(cells.any(func(r:Rect2)->bool:return r.has_point(point)),"merged art never fills a collision hole")
	var hole: Array[Rect2]=[Rect2(0,0,40,40),Rect2(40,0,40,40),Rect2(0,40,40,40)]
	check(not Art.merge_cells(hole).any(func(r:Rect2)->bool:return r.has_point(Vector2(60,60))),"L-shaped terrain keeps its hole")
	for theme: String in ["crimson","frost","wind","meadow"]:
		check(Art.texture(theme)!=null,"painted ground imports "+theme)
	check(ResourceLoader.exists("res://assets/world/v92/terrain-atlas.png"),"terrain sprites import")
	var intact:=DrawSpy.new()
	var damaged:=DrawSpy.new()
	Art.gate(intact,Rect2(0,0,160,70),{"type":"door","hp":720,"max_hp":720},Art.PALETTES.crimson)
	Art.gate(damaged,Rect2(0,0,160,70),{"type":"door","hp":90,"max_hp":720},Art.PALETTES.crimson)
	check(intact.commands!=damaged.commands,"textured gate still displays health loss")
	check(damaged.commands.size()>intact.commands.size(),"damaged gate adds its shared health indicator after the sprite")
	var ground:=DrawSpy.new()
	ground.sim=sim
	Art.ground(ground,sim.ENDLESS_ARENA,"crimson")
	check(ground.regions.size()>=4,"ground draws all four perimeter strips")
	for border: Rect2 in ground.regions.slice(-4):
		check(not border.intersects(sim._movement_bounds()),"painted perimeter does not enter the actual movement bounds")
	print("V91 ENVIRONMENT: %d checks / %d failures; 8 stages, 3 arenas, exact terrain union, painted textures"%[checks,failures])
	quit(0 if failures==0 else 1)
