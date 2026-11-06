extends SceneTree
const Bench = preload("res://qa/crowded_20261005/benchmark.gd")
const Battle = preload("res://scripts/battle_view.gd")
func _initialize() -> void:
	call_deferred("_run")
func stats(values: Array) -> Dictionary:
	values.sort()
	return {"p50_ms":values[values.size()/2],"p95_ms":values[floori(values.size()*.95)],"samples":values.size()}
func _run() -> void:
	var destination: String = "user://crowded-native"
	var light := OS.get_cmdline_user_args().has("--qa-light")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): destination=argument.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(destination)
	root.size=Vector2i(1280,720)
	var report: Dictionary={"modes":{},"rendering_method":RenderingServer.get_current_rendering_method(),"fixture":"80 mixed enemies / 25 plants / 120 friendly shots" if light else "200 mixed enemies / 25 plants / 360 friendly shots; shared deterministic normal-map geometry, endless stress mode forces plants on"}
	for endless in [false,true]:
		var sim=Bench.fixture(endless,null,80 if light else 200)
		if light:
			for hero in sim.heroes:
				hero.rate=minf(5.0,float(hero.base_rate)*1.5); hero.range=600.0; hero.projectile_count=3; hero.pierce=3
			for i in sim.enemies.size():
				sim.enemies[i].pos.y=180+(i/10)*47.5; sim.enemies[i].route_points[0].y=sim.enemies[i].pos.y; sim.enemies[i].route_points[1].y=sim.enemies[i].pos.y
		var view=Battle.new()
		view.sim=sim
		view.process_mode=Node.PROCESS_MODE_DISABLED
		root.add_child(view)
		await process_frame
		var frames: Array=[]; var advances: Array=[]; var ticks: Array=[]
		for frame in 200:
			Bench.top_up(sim,frame,90 if light else 240,30 if light else 120)
			sim.state="running"; sim.run_state.pending_level_ups=0
			var started:=Time.get_ticks_usec()
			sim.tick(1.0/60.0)
			var after_tick:=Time.get_ticks_usec()
			view.accept_events(sim.drain_events()); view.advance(1.0/60.0); view.queue_redraw()
			var after_advance:=Time.get_ticks_usec()
			await process_frame
			await RenderingServer.frame_post_draw
			if frame>=20:
				ticks.append((after_tick-started)/1000.0)
				advances.append((after_advance-after_tick)/1000.0)
				frames.append((Time.get_ticks_usec()-started)/1000.0)
			if frame==40: root.get_texture().get_image().save_png(destination+("/endless.png" if endless else "/campaign.png"))
		var mode: String="endless" if endless else "campaign"
		report.modes[mode]={"tick":stats(ticks),"visual_advance":stats(advances),"wall_frame":stats(frames)}
		view.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(destination+"/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report)); quit()
