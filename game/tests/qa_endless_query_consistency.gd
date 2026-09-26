extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
const Reference=preload("res://tests/endless_reference_sim.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func prepare(sim,seed_value: int) -> void:
	var squad: Array[String]=["traveler","hero_06","hero_03"]
	sim.reset_stage("stage_endless",squad,seed_value)
	sim.start()
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	sim.terrain_features.clear()
	sim.endless_spawn_timer=99999
	sim.endless_next_boss_at=99999
	for h: Dictionary in sim.heroes:
		h.pos=Vector2(600+int(h.id)*35,350)
		h.target=h.pos
		h.deployed=true
		h.range=500.0
		h.rate=8.0
		h.damage=140.0
		h.element="pyro"
		h.projectile_count=10
		h.pierce=4
		h.chain_count=3
		h.splash=true
		h.blast_radius=100
	for i in 48:
		var e: Dictionary=sim.spawn_enemy(Vector2(720+(i%8)*34,280+(i/8)*30),"splitter" if i%7==0 else "grunt")
		e.hp=2400.0
		e.max_hp=e.hp
		e.aura="electro"
		e.aura_timer=10.0
		e.speed=0.0
		e.damage=0.0
	sim.drain_events()
func equivalent(a,b) -> bool:
	if a.kills!=b.kills or a.team_xp!=b.team_xp or a.reactions!=b.reactions or a.enemies.size()!=b.enemies.size(): return false
	for i in a.enemies.size():
		var x: Dictionary=a.enemies[i]
		var y: Dictionary=b.enemies[i]
		if x.id!=y.id or not is_equal_approx(float(x.hp),float(y.hp)) or x.pos!=y.pos or x.aura!=y.aura: return false
	return true
func run() -> void:
	for seed_value in [271,92427,555]:
		var a=Sim.new(seed_value,true)
		var b=Reference.new(seed_value,true)
		prepare(a,seed_value)
		prepare(b,seed_value)
		for frame in 120:
			a.elapsed+=1.0/60.0
			b.elapsed=a.elapsed
			for sim in [a,b]:
				seed(seed_value*1000+frame)
				for h: Dictionary in sim.heroes: h.attack_timer=maxf(0.0,float(h.attack_timer)-1.0/60.0)
				if frame%9==0: sim._hero_tick()
				sim._projectile_tick(1.0/60.0)
				sim.drain_events()
			if not equivalent(a,b):
				failures+=1
				push_error("Optimized/reference mismatch seed=%s frame=%s" % [seed_value,frame])
				break
		print("QUERY CONSISTENCY seed=",seed_value," kills=",a.kills," reactions=",a.reactions)
	var sim=Sim.new(111,true)
	var batch: Array[Dictionary]=[]
	for i in 1000: batch.append({"kind":"hit","pos":Vector2(100,100),"value":2,"element":"hydro"})
	for kind in ["death","level_up","reward","boss_enter","skill_cast"]: batch.append({"kind":kind,"pos":Vector2.ZERO})
	var compacted: Array[Dictionary]=sim._compact_cosmetic_events(batch)
	if compacted.size()!=6 or int(compacted[0].value)!=2000:
		failures+=1
		push_error("Cosmetic batching lost damage text sum or gameplay events")
	print("COSMETIC BATCH: 1005 events -> ",compacted.size(),"; damage sum=",compacted[0].value)
	print("QUERY CONSISTENCY failures=",failures)
	quit(1 if failures else 0)
