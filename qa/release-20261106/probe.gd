extends SceneTree
const Policy=preload("play_policy.gd")
const Sim=preload("res://scripts/combat_simulation.gd")
func _initialize()->void:run.call_deferred()
func play(stage:String,seed_value:int,carry:Dictionary={})->Dictionary:
	seed(seed_value+20261006)
	var sim=Sim.new(seed_value,true)
	var squad:Array[String]=["traveler","hero_03"]
	if stage!="stage_01":squad.append("hero_13")
	if not carry.is_empty():squad.assign(carry.squad)
	sim.reset_stage(stage,squad,seed_value)
	if not carry.is_empty():sim.import_run_snapshot(carry)
	if sim.endless_mode:sim.set_formation_mode("follow");sim.set_follow_leader(0)
	sim.start()
	var policy=Policy.new();policy.initialize(sim,seed_value)
	var stats:Array[Dictionary]=[]
	var event_counts:Dictionary={}
	var boss_events:Array[Dictionary]=[]
	var last_kills:=0
	for tick_id in 30*650:
		while sim.state=="reward":
			if not policy.take_reward():break
		if sim.state in ["won","lost"] or sim.elapsed>640:break
		policy.controls()
		sim.tick(Policy.STEP)
		for event:Dictionary in sim.drain_events():
			var kind:=str(event.get("kind",""))
			event_counts[kind]=int(event_counts.get(kind,0))+1
			if kind.begins_with("slime_") or kind.begins_with("rift_"):boss_events.append({"time":sim.elapsed,"kind":kind})
		if tick_id%150==0:
			stats.append({"time":snappedf(sim.elapsed,.01),"kills":sim.kills,"kills5":sim.kills-last_kills,"enemies":sim.enemies.size(),"projectiles":sim.projectiles.size(),"level":sim.run_state.crystal_level,"hp":sim.base_hp})
			last_kills=sim.kills
	var result:={"stage":stage,"seed":seed_value,"state":sim.state,"time":sim.elapsed,"kills":sim.kills,"level":sim.run_state.crystal_level,"choices":policy.choices,"casts":policy.casts,"purchases":policy.purchases,"stats":stats,"event_counts":event_counts,"boss_events":boss_events}
	if sim.state=="won":result["carry"]=sim.export_run_snapshot()
	print("PLAY ",stage," ",seed_value," ",sim.state," time=",sim.elapsed," kills=",sim.kills," level=",sim.run_state.crystal_level)
	return result
