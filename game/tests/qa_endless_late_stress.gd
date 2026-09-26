extends SceneTree
const ProfileSim=preload("res://tests/endless_profile_sim.gd")
var game
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode=true
	game.muted=true
	game.set_physics_process(false)
	game.set_process(false)
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.sim=ProfileSim.new(92427,true)
	game.battle.sim=game.sim
	var squad: Array[String]=["hero_06","hero_03","hero_04"]
	game.sim.reset_stage("stage_endless",squad,92427)
	game.sim.start()
	game.sim.state="running"
	game.sim.elapsed=1200.0
	game.sim.endless_spawn_timer=99999.0
	game.sim.endless_next_boss_at=99999.0
	game.sim.troop_convoy_timer=99999.0
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	var representative := "--representative" in OS.get_cmdline_user_args()
	var center: Vector2=game.sim.ENDLESS_ARENA.get_center()
	for i in 3:
		var h: Dictionary=game.sim.heroes[i]
		h.pos=center+Vector2(-130, float(i-1)*40)
		h.target=h.pos
		h.deployed=true
		h.invulnerable_timer=99999.0
		h.range=1600.0
		h.rate=6.0 if representative else 12.0
		h.projectile_count=8 if representative else 24
		h.pierce=3 if representative else 6
		h.chain_count=2 if representative else 4
		h.splash=true
		h.blast_radius=100.0
		h.damage=100.0
	for i in 96:
		var e: Dictionary=game.sim.spawn_enemy(center+Vector2(50+(i%12)*18,(i/12-4)*18),"armored")
		e.hp=1e15
		e.max_hp=e.hp
		e.damage=0.0
	game.battle.camera_center=center
	game.sim.set_active_view_rect(Rect2(center-Vector2(640,360),Vector2(1280,720)))
	var rows: Array[Dictionary]=[]
	for visible_case in [false,true]:
		game.battle.visible=visible_case
		game.sim.timings.clear()
		var sim_ms: Array[float]=[]
		var draw_ms: Array[float]=[]
		var event_ms: Array[float]=[]
		var wall: Array[float]=[]
		for i in 210:
			var begin:=Time.get_ticks_usec()
			game.sim.tick(1.0/60.0)
			var a:=Time.get_ticks_usec()
			game.process_events()
			game.hud.refresh(game.sim,0)
			var b:=Time.get_ticks_usec()
			game.battle.advance(1.0/60.0)
			await process_frame
			if i>=30:
				sim_ms.append(float(a-begin)/1000.0)
				event_ms.append(float(b-a)/1000.0)
				wall.append(float(Time.get_ticks_usec()-begin)/1000.0)
				draw_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		var row: Dictionary={"preset":"late" if representative else "saturation","visible":visible_case,"sim_mean_ms":mean(sim_ms),"events_hud_mean_ms":mean(event_ms),"wall_mean_ms":mean(wall),"wall_p95_ms":percentile(wall),"ram_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"vram_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"enemies":game.sim.enemies.size(),"projectiles":game.sim.projectiles.size(),"effects":game.battle.effects.size(),"timings_ms":{}}
		for key in game.sim.timings: row.timings_ms[key]=float(game.sim.timings[key])/210000.0
		rows.append(row)
		print(JSON.stringify(row))
	var output: String="res://../outputs/endless-late-before.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	game.queue_free()
	await process_frame
	quit()
func mean(values: Array[float]) -> float:
	var total:=0.0
	for value in values: total+=value
	return total/maxi(1,values.size())
func percentile(values: Array[float]) -> float:
	var sorted:=values.duplicate()
	sorted.sort()
	return sorted[int(sorted.size()*0.95)]
