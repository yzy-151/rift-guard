extends "probe.gd"
func run()->void:
	var result:Array[Dictionary]=[]
	for stage:String in ["stage_01","stage_02","stage_03"]:
		result.append(play(stage,6121))
	var f:=FileAccess.open(get_script().resource_path.get_base_dir().path_join("three-stage-playthrough.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"\t"));f.close()
	quit(0 if result.all(func(r:Dictionary):return r.state=="won") else 1)
