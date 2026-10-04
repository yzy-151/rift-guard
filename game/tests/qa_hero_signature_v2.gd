extends SceneTree
const MainScene = preload("res://main.tscn")
const Skills = preload("res://scripts/hero_signature_skills.gd")
var failures := 0
var checks := 0
var game
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS "+message)
func setup(id: String):
	var squad: Array[String] = [id,"hero_03" if id=="traveler" else "traveler"]
	game.sim.reset_stage("stage_02",squad,92426)
	game.sim.start()
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	game.sim.terrain_features.clear()
	game.sim.pending_impacts.clear()
	game.sim.skill_effects.clear()
	var h: Dictionary = game.sim.heroes[0]
	h.deployed = true
	h.pos = Vector2(370,360)
	h.target = h.pos
	h.energy = h.max_energy
	return h
func enemy(pos: Vector2):
	var e: Dictionary = game.sim.spawn_enemy(pos,"grunt")
	e.hp = 100000.0
	e.max_hp = 100000.0
	e.armor = 0.0
	e.shield = 0.0
	return e
func advance(seconds: float) -> void:
	for i in ceili(seconds*60.0):
		game.sim.elapsed += 1.0/60.0
		game.sim._pending_impact_tick(1.0/60.0)
		game.sim._skill_effect_tick(1.0/60.0)
func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.set_process(false)
	game.set_physics_process(false)
	var h: Dictionary = setup("hero_13")
	var a: Dictionary = enemy(Vector2(610,360))
	var b: Dictionary = enemy(Vector2(850,360))
	var outside: Dictionary = enemy(Vector2(700,435))
	var behind: Dictionary = enemy(Vector2(280,360))
	check(game.sim.activate_hero_ultimate(0,Vector2(930,360)),"Gwen direction cast accepted")
	advance(4.0)
	var power: float = (150.0+float(h.damage)*1.25)*(1.0+game.sim.skill_power_bonus)
	check(is_equal_approx(100000.0-float(a.hp),power*9.0),"Gwen all nine needles hit first enemy exactly once")
	check(is_equal_approx(100000.0-float(b.hp),power*9.0),"Gwen pierces to second enemy with no hidden splash")
	check(outside.hp==100000.0 and behind.hp==100000.0,"Gwen excludes side and rear enemies")
	check(game.sim.skill_effects.is_empty(),"Needles clean up after tail")
	h = setup("hero_06")
	a = enemy(Vector2(680,360))
	b = enemy(Vector2(725,370))
	outside = enemy(Vector2(1040,540))
	check(game.sim.activate_hero_skill(0,Vector2(700,365)),"Amiya Q targets area")
	advance(2.8)
	check(int(a.get("amiya_marks",0))==3 and int(b.get("amiya_marks",0))==3,"Six shards distribute and stack three marks per target")
	check(outside.hp==100000.0,"Amiya Q cannot select outside area")
	var hp_before: float = h.hp
	var attack_before: float = h.damage
	var target_hp: float = a.hp
	check(game.sim.activate_hero_ultimate(0,Vector2(700,365)),"Amiya E cast")
	advance(3.5)
	var expected: float = (300.0+float(h.damage)*2.5)*(1.0+game.sim.skill_power_bonus)*(0.7+1.2*1.9)
	check(absf((target_hp-float(a.hp))-expected)<0.1,"Chimera final burst consumes three marks for 90 percent bonus")
	check(int(a.amiya_marks)==0 and h.hp<hp_before and h.hp>=1.0 and h.damage==attack_before,"Chimera self-cost and no permanent stat leakage")
	h = setup("hero_03")
	a = enemy(Vector2(690,360))
	outside = enemy(Vector2(1050,530))
	game.sim.activate_hero_skill(0,Vector2(700,360))
	advance(3.0)
	check(a.hp<100000.0 and outside.hp==100000.0,"Salon projectiles hit only visible salon area")
	check(game.sim.orbitals.is_empty(),"Salon is independent summons rather than orbiting player damage")
	var ally: Dictionary = game.sim.heroes[1]
	ally.deployed = true
	ally.pos = Vector2(390,370)
	ally.hp = 100.0
	game.sim.activate_hero_ultimate(0,Vector2(1100,530))
	advance(1.0)
	check(is_equal_approx(Skills.outgoing_multiplier(game.sim,1),1.25) and ally.hp>100.0,"Fanfare first effective heal raises local damage bonus from 20 to 25 percent")
	ally.pos = Vector2(1100,530)
	check(Skills.outgoing_multiplier(game.sim,1)==1.0,"Fanfare has no invisible global buff")
	advance(13.0)
	check(game.sim.skill_effects.is_empty() and Skills.outgoing_multiplier(game.sim,0)==1.0,"Summons and fanfare expire without permanent stat leakage")
	check(game.HeroSignatureAudio.SOUNDS.all(func(key: String) -> bool: return game.boss_skill_sounds.has(key) and game.boss_skill_sounds[key].stream!=null),"All dedicated sound streams imported")
	h = setup("hero_03")
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.story.active = false
	game.selected_id = 0
	game.ultimate_aiming = false
	game.activate_selected_ultimate()
	check(not game.ultimate_aiming and h.energy==0.0 and not game.sim.pending_impacts.is_empty(),"Furina E is one-press cast through actual input handler")
	advance(1.0)
	h.hp = 0.0
	advance(0.5)
	check(Skills.outgoing_multiplier(game.sim,0)==1.0 and game.sim.skill_effects.is_empty(),"Fanfare cancels cleanly when caster falls")
	h=setup("hero_04")
	a=enemy(Vector2(730,360))
	outside=enemy(Vector2(1180,560))
	game.sim.drain_events()
	game.sim.activate_hero_ultimate(0,Vector2(740,360))
	advance(1.1)
	check(a.hp<100000 and outside.hp==100000,"Roxy thunder damages storm area, excludes far target")
	var storm_events: Array[Dictionary]=game.sim.drain_events()
	check(storm_events.any(func(e:Dictionary)->bool:return str(e.kind)=="roxy_thunder" and not e.targets.is_empty()),"Roxy lightning uses actual hit positions")
	advance(10.0)
	check(game.sim.skill_effects.is_empty(),"Roxy cloud expires with its damage field")
	h=setup("traveler")
	h.element=""
	a=enemy(Vector2(730,360))
	outside=enemy(Vector2(1180,560))
	game.sim.drain_events()
	game.sim.activate_hero_skill(0,Vector2(730,360))
	advance(1.0)
	check(a.hp<100000 and outside.hp==100000,"Neutral sword hit keeps original area")
	var neutral_events: Array[Dictionary]=game.sim.drain_events()
	check(neutral_events.any(func(e:Dictionary)->bool:return game.HeroSignatureAudio.describe(e).get("key","")=="neutral_slash"),"Neutral Q has dedicated impact sound")
	game.sim.activate_hero_ultimate(0,Vector2(740,360))
	advance(1.4)
	neutral_events=game.sim.drain_events()
	check(neutral_events.any(func(e:Dictionary)->bool:return game.HeroSignatureAudio.describe(e).get("key","")=="neutral_starfall"),"Neutral E has dedicated impact sound")
	check(outside.hp==100000,"Neutral E excludes far target")
	print("HERO SIGNATURE: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
