extends Node
## Renders a complete ordinary-stat campaign while a deterministic bot uses public controls.
## Three 60Hz simulation steps per rendered frame keep this visual check reasonably short.
## Works with source and release EXE: -- --starfall-qa=campaign --capture-dir=ABSOLUTE_PATH
var game
var frame := 0
var elapsed_frames: Array[float] = []
var last_tick := 0
var ending := 0
var capture_dir := ""
var steps := 0
var captured: Dictionary = {}
var peaks := {"enemies":0,"projectiles":0,"particles":0}

func _ready() -> void:
	call_deferred("boot")

func boot() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	game = get_parent()
	game.set_physics_process(false)
	game.set_process(false)
	await game.start_run({"mode":"campaign","squad":["traveler","hero_03","hero_08"]})
	game.sim.start("campaign",["traveler","hero_03","hero_08"],22)
	last_tick = Time.get_ticks_usec()
	get_tree().process_frame.connect(advance)

func advance() -> void:
	frame += 1
	var now := Time.get_ticks_usec()
	if frame>120: elapsed_frames.append((now-last_tick)/1000.0)
	last_tick = now
	var sim = game.sim
	if sim.phase in ["won","lost"]:
		ending += 1
		if ending==15: capture("campaign-result")
		if ending>=45: finish()
		return
	for substep in range(3):
		if sim.phase=="upgrade":
			var choice: String = sim.upgrade_choices[0].id
			for pref in ["multishot","power","haste","magnet","core_repair","lifesteal","regen"]:
				var found := false
				for option in sim.upgrade_choices:
					if option.id==pref:
						choice = option.id
						found = true
						break
				if found: break
			game._on_action("upgrade",choice)
		if sim.phase!="battle": break
		var hero: Dictionary = sim.heroes[sim.selected]
		var target: Vector2 = sim.CORE
		var nearest := INF
		for enemy in sim.enemies:
			var score: float = enemy.pos.distance_to(hero.pos)*(0.4 if enemy.kind=="boss_01" else 1.0)
			if score<nearest:
				nearest = score
				target = enemy.pos
		var walk_to: Vector2 = sim.CORE+Vector2.RIGHT.rotated(sim.time*0.18)*220
		for p in sim.pickups:
			if p.pos.distance_to(hero.pos)<230:
				walk_to = p.pos
				break
		if steps%180==0: sim.select_hero((sim.selected+1)%3)
		sim.cast("q",target)
		sim.cast("e",target)
		for hazard in sim.hazards:
			if hazard.owner=="enemy" and hazard.remaining<0.25 and hazard.pos.distance_to(hero.pos)<hazard.radius+45:
				sim.dash((hero.pos-hazard.pos).normalized())
		sim.step(1.0/60.0,(walk_to-hero.pos).normalized(),target)
		steps += 1
		game.arena.accept(sim.drain_events())
		game.ui.update_hud(sim)
		game._sync_phase()
	peaks.enemies = maxi(peaks.enemies,sim.enemies.size())
	peaks.projectiles = maxi(peaks.projectiles,sim.projectiles.size())
	peaks.particles = maxi(peaks.particles,game.arena.particles.size())
	if sim.wave in [2,3,5,6,8,9] and sim.wave_time>12 and not captured.has(sim.wave):
		captured[sim.wave] = true
		capture("combat-wave-%02d" % sim.wave)
	if steps>28000:
		printerr("FAIL: Render campaign exceeded time budget")
		get_tree().quit(1)

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
	print("RENDER_CAPTURE ",name)

func finish() -> void:
	get_tree().process_frame.disconnect(advance)
	elapsed_frames.sort()
	var mean := 0.0
	for value in elapsed_frames: mean += value
	mean /= maxf(1,elapsed_frames.size())
	print("RENDER_CAMPAIGN phase=%s time=%.1f wave=%d kills=%d frame_ms_mean=%.2f p95=%.2f peaks=%s" % [game.sim.phase,game.sim.time,game.sim.wave,game.sim.kills,mean,elapsed_frames[int(elapsed_frames.size()*0.95)],JSON.stringify(peaks)])
	var success: bool = game.sim.phase=="won"
	game.music.stop()
	for voice in game.voices: voice.stop()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if success else 1)
