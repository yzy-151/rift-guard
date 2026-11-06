extends SceneTree
const Bench=preload("res://qa/crowded_20261005/benchmark.gd")
const Hot=preload("res://qa/crowded_20261005/hot_sim.gd")
func _init() -> void:
	var report: Dictionary={}
	for endless in [false,true]:
		var sim=Bench.fixture(endless,Hot)
		for frame in 60:
			Bench.top_up(sim,frame); sim.state="running"; sim.tick(1.0/60.0); sim.drain_events()
		report["endless" if endless else "campaign"]=sim.hotspots
	print(JSON.stringify(report)); quit()
