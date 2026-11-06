extends SceneTree
var app
var failures: Array[String] = []
var checks := 0
var out := "C:/Users/23081/Desktop/codex/rift-guard/qa/devices-release-20261005"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): out=arg.trim_prefix("--qa-output=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func mouse(point: Vector2, down: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var move := InputEventMouseMotion.new()
	move.position=point; move.global_position=point
	root.push_input(move, true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position=point; event.global_position=point; event.button_index=button; event.pressed=down
	root.push_input(event, true)
	await process_frame

func click(point: Vector2) -> void:
	await mouse(point,true)
	await mouse(point,false)

func run() -> void:
	app=load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame; await process_frame
	app.test_mode=true
	app.set_process(false);app.set_physics_process(false)
	app.mode_select_panel.close();app.stage_select_panel.close();app.squad_panel.root.hide();app.dialogue.hide();app.home_panel.close()
	app.hud.get_child(0).show()
	var sim=app.sim
	var squad: Array[String]=["traveler","hero_03"]
	sim.reset_stage("stage_01",squad,41055)
	sim.start()
	app.refresh()
	await process_frame
	check(sim.device_shop.enabled and sim.device_shop.gold==120 and sim.device_shop.limit==6,"first campaign battle enables 120 gold and six slots")
	var shop=app.hud.device_shop_ui
	await click(shop.buttons.power.get_global_rect().get_center())
	check(sim.battle_devices.selected_kind=="power","actual HUD click selects attack pad")
	check(sim.battle_devices.placed.is_empty() and sim.battle_devices.gold==120,"shop click consumes no coin and does not deploy at UI coordinates")
	var build_point:=Vector2.ZERO
	for y in range(180,540,40):
		for x in range(280,1100,60):
			if sim.battle_devices.placement_error(sim,Vector2(x,y)).is_empty(): build_point=Vector2(x,y);break
		if build_point!=Vector2.ZERO:break
	check(build_point!=Vector2.ZERO,"actual first-stage terrain has a valid purchasable floor cell")
	await click(app.battle.world_to_screen(build_point))
	check(sim.battle_devices.placed.size()==1 and sim.battle_devices.gold==20,"actual floor click places exactly one device and deducts exact price")
	check(sim.battle_devices.selected_kind.is_empty(),"successful placement ends mode")
	sim.battle_devices.gold=500
	app.refresh();await process_frame
	await click(shop.buttons.range.get_global_rect().get_center())
	await mouse(app.battle.world_to_screen(build_point),true,MOUSE_BUTTON_RIGHT)
	await mouse(app.battle.world_to_screen(build_point),false,MOUSE_BUTTON_RIGHT)
	check(sim.battle_devices.selected_kind.is_empty() and sim.battle_devices.gold==500,"right-click cancel keeps gold")
	await click(shop.buttons.range.get_global_rect().get_center())
	var cancel:=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.pressed=true
	root.push_input(cancel, true);await process_frame
	check(sim.battle_devices.selected_kind.is_empty() and sim.state=="running","Esc cancels deployment without opening pause")
	if sim.battle_devices.placed.is_empty():
		print("Stopping after failed GUI placement fixture")
		app.queue_free();await process_frame;quit(1);return
	var hero: Dictionary=sim.heroes[0]
	hero.deployed=true
	hero.pos=sim.battle_devices.placed[0].pos;hero.target=hero.pos
	check(is_equal_approx(sim.displayed_attack_damage(hero),float(hero.damage)*1.35),"HUD attack stat reads placed pad's real multiplier")
	app.refresh()
	var batch: Array[Dictionary]=[{"kind":"device_explosion","pos":build_point,"radius":150.0},{"kind":"device_place","pos":build_point}]
	app.battle.accept_events(batch)
	check(app.battle.effects.any(func(e):return e.kind=="device_explosion"),"device explosion enters actual battle rendering queue")
	var enemy: Dictionary=sim.spawn_enemy(Vector2(980,340),"ranged")
	sim._begin_enemy_warning(enemy,hero)
	var origin: Vector2=enemy.warning_origin
	var direction: Vector2=enemy.warning_direction
	hero.pos+=Vector2(0,90);hero.target=hero.pos
	sim._resolve_enemy_warning(enemy)
	check(not sim.enemy_projectiles.is_empty() and Vector2(sim.enemy_projectiles[-1].pos)==origin and Vector2(sim.enemy_projectiles[-1].direction)==direction,"advertised ranged line is the real frozen projectile origin and direction")
	if "--capture-devices" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless": await capture()
	DirAccess.make_dir_recursive_absolute(out)
	var report:=FileAccess.open(out+"/main-input-validation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));report.close()
	print("DEVICE MAIN INPUT QA: %d checks, %d failures" %[checks,failures.size()])
	app.queue_free();await process_frame;await process_frame
	await create_timer(.25).timeout
	quit(0 if failures.is_empty() else 1)

func capture() -> void:
	var sim=app.sim
	var squad: Array[String]=["traveler","hero_03"]
	sim.reset_stage("stage_01",squad,41055);sim.start()
	sim.pending_stage_spawns.clear();sim.enemies.clear();sim.enemy_lookup.clear();sim.events.clear()
	sim.stage_runtime.definition=sim.stage_runtime.definition.duplicate(true)
	sim.stage_runtime.definition.waves=[]
	sim.battle_devices.gold=2000
	sim.wave_timer=999.0
	var chosen: Array[Vector2]=[]
	for kind: String in ["power","range","barricade","pea","mine"]:
		sim.battle_devices.select(sim,kind)
		var point:=Vector2.ZERO
		var preferred := {"power":Vector2(490,440),"range":Vector2(430,280),"barricade":Vector2(730,400),"pea":Vector2(430,360),"mine":Vector2(850,440)}
		if sim.battle_devices.placement_error(sim,preferred[kind]).is_empty(): point=preferred[kind]
		else:
			for y in range(260,500,40):
				for x in range(400,1000,60):
					if sim.battle_devices.placement_error(sim,Vector2(x,y)).is_empty(): point=Vector2(x,y);break
				if point!=Vector2.ZERO:break
		sim.battle_devices.place(sim,point)
		chosen.append(sim.battle_devices.placed[-1].pos)
	for i in sim.heroes.size():
		var h: Dictionary=sim.heroes[i]
		h.deployed=true;h.pos=[chosen[0],chosen[1],Vector2(540,360)][i];h.target=h.pos
		h.hp=10000.0;h.max_hp=10000.0;h.energy=h.max_energy;h.attack_timer=0.1;h.crit_chance=.25
	for index in 18:
		var kind := "ranged" if index%3==0 else "buffer" if index%3==1 else "grunt"
		var e: Dictionary=sim.spawn_enemy(Vector2(820+(index%4)*70,260+(index/4)*48),kind)
		e.hp=6000.0;e.max_hp=6000.0;e.xp=0;e.speed=7.0;e.attack_range=600.0 if kind!="grunt" else 50.0;e.rate=1.0;e.attack_timer=float(index%4)*.3
	app.battle.reset_transients();app.battle.selected_id=0
	sim.drain_events()
	DirAccess.make_dir_recursive_absolute(out+"/frames")
	var counts: Dictionary={}
	for frame in 288:
		var dt:=1.0/24.0
		if frame==15: check(sim.activate_hero_skill(1,Vector2(850,330)),"demo real Furina Q accepted")
		if frame==35: check(sim.activate_hero_ultimate(1,sim.heroes[1].pos),"demo real Furina E accepted")
		if frame==65: check(sim.activate_hero_skill(2,sim.heroes[2].pos),"demo real Gwen Q accepted")
		if frame==90: check(sim.activate_hero_ultimate(2,Vector2(980,360)),"demo real Gwen E accepted")
		if frame==130:
			sim.heroes[0].element="pyro";sim.heroes[0].skill_cooldown=0.0;sim.heroes[0].energy=sim.heroes[0].max_energy
			check(sim.activate_hero_ultimate(0,Vector2(870,350)),"demo real Traveler fire E accepted")
		if frame==160:
			var trigger: Dictionary=sim.spawn_enemy(chosen[4],"grunt");trigger.hp=220.0;trigger.max_hp=220.0;trigger.xp=0;trigger.speed=0.0
		if frame==195:
			sim.heroes[0].element="cryo";sim.heroes[0].skill_cooldown=0.0
			check(sim.activate_hero_skill(0,Vector2(880,350)),"demo real Traveler ice Q accepted")
		if frame==235:
			sim.heroes[0].element="electro";sim.heroes[0].skill_cooldown=0.0;sim.heroes[0].ultimate_cooldown=0.0;sim.heroes[0].energy=sim.heroes[0].max_energy
			check(sim.activate_hero_ultimate(0,Vector2(860,350)),"demo real Traveler lightning E accepted")
		sim.tick(dt)
		var events: Array[Dictionary]=sim.drain_events()
		for e: Dictionary in events: counts[e.kind]=int(counts.get(e.kind,0))+1
		app.battle.accept_events(events);app.fx.accept(events);app.combat_audio.accept(events,sim,app.battle.visible_world_rect())
		app.battle.advance(dt);app.fx.advance(dt);app.refresh()
		await RenderingServer.frame_post_draw
		var picture: Image=root.get_texture().get_image();picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
		picture.save_png(out+"/frames/frame-%04d.png"%frame)
		if frame in [25,55,98,165,205,245]: picture.save_png(out+"/battle-%03d.png"%frame)
	check(int(counts.get("device_pea_cast",0))>0,"real demo emits row pea shots")
	check(int(counts.get("device_explosion",0))>0,"real demo triggers explosion with live enemy")
	var report:=FileAccess.open(out+"/capture-events.json",FileAccess.WRITE);report.store_string(JSON.stringify(counts,"\t"));report.close()
	await capture_wallnut_states()

func capture_wallnut_states() -> void:
	var sim=app.sim
	var squad: Array[String]=["traveler"]
	sim.reset_stage("stage_01",squad,41055);sim.start()
	sim.enemies.clear();sim.enemy_lookup.clear();sim.events.clear()
	sim.battle_devices.select(sim,"barricade")
	var point:=Vector2(730,400)
	check(sim.battle_devices.placement_error(sim,point).is_empty(),"Wall-nut demonstration uses a real buildable cell")
	sim.battle_devices.place(sim,point)
	if sim.battle_devices.placed.is_empty(): return
	var nut: Dictionary=sim.battle_devices.placed[0]
	app.battle.reset_transients();app.battle.selected_id=-1
	for h: Dictionary in sim.heroes:
		h.deployed=true;h.pos=Vector2(360+int(h.id)*90,360);h.target=h.pos
	sim.drain_events()
	DirAccess.make_dir_recursive_absolute(out+"/nut-frames")
	for stage in 3:
		if stage>0: sim.damage_construct(int(nut.id),float(nut.max_hp)*(.40 if stage==1 else .35))
		check(is_equal_approx(float(nut.hp)/float(nut.max_hp),[1.0,.60,.25][stage]),"Wall-nut real construct damage selects stage %d"%stage)
		app.battle.accept_events(sim.drain_events())
		for frame in 24:
			app.battle.advance(1.0/24.0);app.refresh()
			await RenderingServer.frame_post_draw
			var picture: Image=root.get_texture().get_image();picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
			picture.save_png(out+"/nut-frames/frame-%04d.png"%(stage*24+frame))
			if frame==18: picture.save_png(out+"/wallnut-%d.png"%stage)
