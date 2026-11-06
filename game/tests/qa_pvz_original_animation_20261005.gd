extends SceneTree
const PLANTS=preload("res://scripts/pvz_plant_visual.gd")
var failures: Array[String]=[]
var checks:=0

class PaintProbe:
	extends RefCounted
	var regions: Array=[]
	var shadows: Array=[]
	func world_to_screen(point: Vector2)->Vector2: return point*Vector2(1.2,.7)+Vector2(10,20)
	func world_depth_scale(_point: Vector2)->float: return 1.3
	func draw_ellipse_shadow(point:Vector2,radius:float,color:Color)->void: shadows.append([point,radius,color])
	func draw_texture_rect_region(texture:Texture2D,destination:Rect2,source:Rect2)->void: regions.append([texture,destination,source])
	func draw_circle(_point:Vector2,_radius:float,_color:Color)->void: pass

func check(test:bool,message:String)->void:
	checks+=1
	if not test:failures.append(message)

func _initialize()->void:
	for key:String in PLANTS.TEXTURES:
		var info:Dictionary=PLANTS.metadata(key)
		var texture:Texture2D=PLANTS.TEXTURES[key]
		var cell:Vector2=Vector2(float(info.cell[0]),float(info.cell[1]))
		check(texture.get_size().is_equal_approx(Vector2(cell.x*int(info.columns),cell.y*int(info.rows))),key+" original atlas dimensions")
		check(texture.get_width()<=4096,key+" atlas within portable GPU limit")
		var elapsed:=0.0
		for i:int in int(info.frames):
			check(PLANTS.frame_at(key,elapsed+.001)==i,key+" preserves duration/frame "+str(i))
			elapsed+=float(info.duration_ms[i])*.001
		check(PLANTS.frame_at(key,elapsed+.001)==0,key+" seamless duration loop")
		var probe:=PaintProbe.new()
		var device:Dictionary={"pos":Vector2(450,400),"kind":key,"visual_variant":key,"visual_time":.46,"hp":100,"max_hp":100}
		PLANTS.draw(probe,device)
		check(probe.regions.size()==1,key+" exactly one original frame, no rotated still")
		check(probe.shadows.size()==2,key+" two grounded shadows")
		check(Rect2(probe.regions[0][2]).is_equal_approx(PLANTS.frame_region(key,.46)),key+" exact source frame crop")
		var first_shadow:Vector2=probe.shadows[0][0]
		device.visual_time+=.42
		PLANTS.draw(probe,device)
		check(Vector2(probe.shadows[2][0]).is_equal_approx(first_shadow),key+" feet/shadow stay fixed throughout original sway")
	for key:String in ["pea","repeater","snowpea","threepeater","gatling"]:
		var info:Dictionary=PLANTS.metadata(key)
		var mouths:Array=[]
		for i:int in int(info.frames):mouths.append(PLANTS.mouth_local(key,float(i)*float(info.duration_ms[0])*.001+.001))
		var variation:=0.0
		for mouth:Vector2 in mouths:variation=maxf(variation,mouth.distance_to(mouths[0]))
		check(variation>2.0,key+" original head moves >2 world pixels, not static rotation")
		for i:int in int(info.frames):
			var time:float=float(i)*float(info.duration_ms[0])*.001+.001
			for lane:int in ([-1,0,1] if key=="threepeater" else [0]):
				var probe:=PaintProbe.new()
				var origin:=Vector2(450,400)
				var start:=origin+Vector2(14,lane*40)
				var shot:Dictionary={"visual_origin":origin,"model_origin":start,"pos":start,"visual_variant":key,"visual_time":time,"muzzle_lane":lane}
				var mouth:Vector2=PLANTS.mouth_screen(probe,origin,key,time,lane)
				check(PLANTS.shot_screen(probe,shot).distance_to(mouth)<.001,key+" frame "+str(i)+" lane "+str(lane)+" exact muzzle release")
				shot.pos+=Vector2(100,0)
				if key!="threepeater":check(PLANTS.shot_screen(probe,shot).distance_to(mouth+probe.world_to_screen(shot.pos)-probe.world_to_screen(start))<.001,key+" released pea never follows later idle frame")
	var probe:=PaintProbe.new()
	var potato:Dictionary={"pos":Vector2(500,400),"kind":"mine","visual_variant":"potato_unarmed","visual_time":.5,"armed":false}
	PLANTS.draw(probe,potato)
	check(probe.regions[0][0]==PLANTS.TEXTURES.potato_unarmed,"unarmed potato stays buried")
	potato.armed=true;PLANTS.draw(probe,potato)
	check(probe.regions[1][0]==PLANTS.TEXTURES.potato_mine,"armed potato emerges from same spot")
	# Dummy renderer does not read GPU images: decode the untouched PNG for the same CPU material path.
	var original:=Image.new()
	original.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/world/pvz_botany_20261005/wallnut.png"))
	var silver:Image=PLANTS._metal_image(original)
	check(silver.get_size()==original.get_size(),"iron nut preserves every original frame")
	check(silver.get_pixel(0,0).a==original.get_pixel(0,0).a,"iron nut preserves transparent background")
	var found:=false
	for y in original.get_height():
		for x in 65:
			var gold:Color=original.get_pixel(x,y)
			if gold.a>.9 and gold.r>.3 and gold.r>gold.b+.15 and gold.g>gold.b+.10:
				var steel:Color=silver.get_pixel(x,y)
				check(steel.b>steel.r and steel.a==gold.a,"iron nut converts warm original pigment to cool silver preserving alpha")
				found=true
				break
		if found:break
	check(found,"original nut yellow pigment found")
	var result:Dictionary={"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://../qa/pvz-assets-20261005")
	var file:=FileAccess.open("res://../qa/pvz-assets-20261005/animation-checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
