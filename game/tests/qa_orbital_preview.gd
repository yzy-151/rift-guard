extends SceneTree
const MainScene = preload("res://main.tscn")
const Audio = preload("res://scripts/hero_signature_audio.gd")
var game
var index := 0
var folder := ""
var ranges: Array[Dictionary] = []
var sounds: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func accept(time: float) -> void:
	var batch: Array[Dictionary] = game.sim.drain_events()
	for event: Dictionary in batch:
		var audio := Audio.describe(event)
		if not audio.is_empty():
			audio["time"] = time
			sounds.append(audio)
	game.battle.accept_events(batch)
func capture() -> bool:
	game.battle.queue_redraw()
	RenderingServer.force_draw()
	await process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	image.resize(1024,576,Image.INTERPOLATE_LANCZOS)
	var destination := ProjectSettings.globalize_path(folder+"frames")
	DirAccess.make_dir_recursive_absolute(destination)
	var ok := image.save_png(destination.path_join("frame-%04d.png" % index))==OK
	index += 1
	return ok
func record(hero: Dictionary, ultimate: bool, seconds: float) -> bool:
	var start := index
	var target := Vector2(760,360)
	var ability: Dictionary = hero.ultimate if ultimate else hero.active_skill
	if ultimate:
		hero.energy = hero.max_energy
		if not game.sim.activate_hero_ultimate(0,target): return false
	else:
		if not game.sim.activate_hero_skill(0,target): return false
	accept(float(start)/12.0)
	for frame in ceili(seconds*24.0):
		var dt := 1.0/24.0
		game.sim.elapsed += dt
		game.sim._pending_impact_tick(dt)
		game.sim._skill_effect_tick(dt)
		# Only the enemies for the homing demo move; other targets stay put for readability.
		if str(hero.character_id)=="hero_06" and not ultimate and frame<45:
			for enemy: Dictionary in game.sim.enemies:
				enemy.pos.y += sin(float(frame)*0.10)*0.7
		accept(float(start)/12.0+float(frame)/24.0)
		game.battle.advance(dt)
		game.refresh()
		if frame%2==0 and not await capture(): return false
	ranges.append({"id":str(ability.kind),"start":start,"end":index})
	return true
func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.set_process(false)
	game.set_physics_process(false)
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	for demo in ["blade","spell","storm"]:
		var character_id="traveler"
		index=0
		ranges.clear()
		sounds.clear()
		folder="res://../outputs/orbitals-v2/"+demo+"/"
		var squad: Array[String] = [character_id,"hero_03" if character_id=="traveler" else "traveler"]
		game.sim.reset_stage("stage_02",squad,92426)
		game.sim.start()
		game.sim.enemies.clear()
		game.sim.enemy_lookup.clear()
		game.sim.terrain_features.clear()
		game.sim.pending_impacts.clear()
		game.sim.skill_effects.clear()
		game.battle.effects.clear()
		var hero: Dictionary = game.sim.heroes[0]
		hero.deployed=true
		hero.pos=Vector2(650,360)
		hero.target=hero.pos
		var ally: Dictionary = game.sim.heroes[1]
		ally.deployed=true
		ally.pos=Vector2(420,420)
		ally.target=ally.pos
		ally.hp=ally.max_hp*0.4
		for pos in [Vector2(770,360),Vector2(800,360),Vector2(850,360),Vector2(705,390),Vector2(740,405),Vector2(1250,550)]:
			var enemy: Dictionary=game.sim.spawn_enemy(pos,"grunt")
			enemy.hp=100000.0
			enemy.max_hp=100000.0
			enemy.armor=0.0
		game.sim.drain_events()
		game.selected_id=0
		game.refresh()
		var orbital={"hero_id":0,"source_card":"orbit_arcane_blades" if demo!="spell" else "orbit_spell","level":9 if demo=="storm" else 1,"count":9 if demo=="storm" else 3,"damage":50.0,"radius":392.0 if demo=="storm" else 248.0,"timer":0.3,"interval":0.7,"life":5.5,"element":"","visual":"spell" if demo=="spell" else "blade","storm_timer":2.1}
		game.sim.orbitals.append(orbital)
		for frame in 144:
			game.sim.elapsed+=1.0/24.0
			game.sim._orbital_tick(1.0/24.0)
			accept(float(frame)/24.0)
			game.battle.advance(1.0/24.0)
			game.refresh()
			if frame%2==0: await capture()
		ranges.append({"id":demo,"start":0,"end":index})

		var file:=FileAccess.open(folder+"manifest.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(ranges))
		file.close()
		file=FileAccess.open(folder+"audio-events.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(sounds))
		file.close()
		print("CAPTURE "+character_id+" frames="+str(index))
	game.queue_free()
	await process_frame
	quit(0)
