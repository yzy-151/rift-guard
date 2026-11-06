extends SceneTree
const Sim = preload("res://qa/crowded_20261005/profiled_sim.gd")
const Devices = preload("res://qa/crowded_20261005/profiled_devices.gd")
var report := {"schema":1,"dt":1.0/60.0,"frames":180,"repeats":3,"fixture":"200 enemies, 25 plants, 240 hero bolts + 120 plant shots, pierce 6, chain 2, splash; 3 live heroes; native fixed-step gameplay wall-clock CPU timings","modes":{}}

static func fixture(endless: bool, sim_type=null, enemy_count: int=200):
	var sim = Sim.new(410205, true) if sim_type==null else sim_type.new(410205,true)
	var squad: Array[String] = ["traveler","hero_01","hero_04"]
	sim.reset_stage("stage_02", squad, 410205)
	sim.enemies.clear(); sim.enemy_lookup.clear(); sim.events.clear()
	sim.formation_mode = "hold"
	sim.state = "running"
	sim.stage_runtime.all_spawns_emitted = true
	sim.stage_runtime.time_complete = false
	sim.pending_stage_spawns.clear(); sim.pending_troop_spawns.clear()
	for h in sim.heroes:
		h.deployed=true; h.hp=1e9; h.max_hp=1e9; h.damage=1.0; h.range=850.0; h.rate=8.0; h.block=0; h.projectile_count=4; h.pierce=6; h.chain_count=2; h.blast_radius=65.0
		h.pos=Vector2(250,260+int(h.id)*100); h.target=h.pos
	sim.battle_devices = Devices.new()
	sim.battle_devices.reset(sim)
	sim.battle_devices.gold=100000
	for row in range(1,10):
		for col in range(4,12):
			if sim.battle_devices.placed.size() >= 25: break
			sim.battle_devices.selected_kind="pea" if col%3 else "snowpea"
			sim.battle_devices.place(sim, sim.GRID_ORIGIN+Vector2(col+.5,row+.5)*sim.GRID_CELL_SIZE)
	assert(sim.battle_devices.placed.size()==25)
	sim.run_state.buff_levels.device_gatling=1
	sim.battle_devices.sync_modifiers(sim)
	if endless:
		sim.endless_mode=true
		sim.active_view_rect=Rect2(0,0,1280,720)
		sim.endless_spawn_timer=9999.0; sim.endless_next_boss_at=9999.0; sim.troop_convoy_timer=9999.0
		sim.expedition.next_tasks_at=9999.0
	# Force plants on for the stress-only endless fixture, where the normal shop is disabled.
	for i in enemy_count:
		var kind: String = ["hilichurl_brute","ranged","buffer","rift_bat","armored"][i%5]
		var enemy: Dictionary = sim.spawn_enemy(Vector2(770+(i%10)*36,180+(i/10)*19),kind)
		enemy.hp=1e9; enemy.max_hp=1e9; enemy.speed=6.0; enemy.damage=1.0; enemy.armor=0; enemy.affixes=[]
		enemy.spawn_timer=0.0; enemy.spawn_phase="ground" # Steady-state benchmark excludes one-time entrance work.
		enemy.route_points=[Vector2(1100,enemy.pos.y),Vector2(200,enemy.pos.y)]; enemy.route_index=1
	sim.events.clear()
	return sim

static func top_up(sim, frame: int, hero_shots: int=240, plant_shots: int=120) -> void:
	while sim.projectiles.size()<hero_shots:
		var i: int = sim.next_projectile_id
		var pos:=Vector2(650+(i%7)*10,180+(i%20)*19-12)
		sim.projectiles.append({"visual_id":i,"pos":pos,"previous_pos":pos,"direction":Vector2.RIGHT,"speed":720.0,"life":4.5,"hit_ids":[],"can_hit_air":true,"damage":1.0,"element":"","source_id":i%3,"splash":true,"slow":false,"pierce":6,"chain_count":2,"blast_radius":65.0,"echo_ratio":0.0,"critical":false,"ballistic":true,"style":"standard"})
		sim.next_projectile_id+=1
	while sim.battle_devices.shots.size()<plant_shots:
		var device: Dictionary = sim.battle_devices.placed[(sim.battle_devices.shots.size()+frame)%25]
		sim.battle_devices._release(sim,device,0)
	for device in sim.battle_devices.placed: device.hp=device.max_hp

func _init() -> void:
	for endless in [false,true]:
		var mode: String = "endless" if endless else "campaign"
		var combined: Dictionary = {}
		var damage_sum:=0.0
		var contacts:=0
		for trial in 3:
			var sim = fixture(endless)
			for frame in 180:
				top_up(sim,frame)
				sim.state="running"; sim.run_state.pending_level_ups=0
				sim.tick(1.0/60.0)
				for event in sim.events:
					if event.kind=="projectile_impact": contacts+=1
				sim.events.clear()
			for key in sim.timings:
				if not combined.has(key): combined[key]=[]
				combined[key].append_array(sim.timings[key])
			for enemy in sim.enemies: damage_sum+=float(enemy.max_hp)-float(enemy.hp)
		var phases: Dictionary={}
		for key in combined:
			var values: Array=combined[key]; values.sort()
			var sum:=0.0
			for value in values: sum+=float(value)
			phases[key]={"p50_ms":values[values.size()/2],"p95_ms":values[floori(values.size()*.95)],"mean_ms":sum/values.size(),"samples":values.size()}
		report.modes[mode]={"phases":phases,"damage":damage_sum,"projectile_contacts":contacts}
	var path: String = "user://crowded-benchmark.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-report="): path=argument.trim_prefix("--qa-report=")
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report))
	quit()


