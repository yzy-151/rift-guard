extends RefCounted

func run(game) -> void:
	var squad: Array[String] = ["traveler", "hero_03", "hero_06"]
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	game.sim.reset_stage("stage_endless", squad, 5803)
	game.sim.start()
	var center: Vector2 = game.sim.ENDLESS_ARENA.get_center()
	var hero_offsets: Array[Vector2] = [Vector2(-150, 0), Vector2(-45, -90), Vector2(-45, 95)]
	for index in game.sim.heroes.size():
		var hero: Dictionary = game.sim.heroes[index]
		hero.pos = center + hero_offsets[index]
		hero.target = hero.pos
		hero.deployed = true
		hero.hp = hero.max_hp
	game.battle.camera_center = center
	game.sim.set_active_view_rect(Rect2(center - Vector2(624, 245), Vector2(1248, 490)))
	var targets: Array[Vector2] = [center + Vector2(210, -105), center + Vector2(285, 10), center + Vector2(220, 120)]
	for index in targets.size():
		var enemy: Dictionary = game.sim.spawn_enemy(targets[index], ["armored", "shielded", "charger"][index])
		enemy.hp = 99999.0
		enemy.max_hp = enemy.hp
		var hero: Dictionary = game.sim.heroes[index]
		game.sim.projectiles.append({"visual_id":9000+index,"pos":hero.pos.lerp(enemy.pos,0.58),"target_id":enemy.id,"damage":hero.damage,"element":hero.element,"source_id":hero.id,"critical":index==2,"style":hero.attack_style})
	var events: Array[Dictionary] = [
		{"kind":"slash","pos":targets[0],"source_pos":game.sim.heroes[0].pos,"angle":0.0,"element":"anemo","critical":true},
		{"kind":"hit","pos":targets[1],"value":268,"element":"hydro","style":"hydro_salon"},
		{"kind":"critical","pos":targets[2],"value":534,"element":"electro","style":"arcane_lance"},
		{"kind":"hit","pos":targets[2]+Vector2(80,-40),"value":186,"element":"cryo","style":"frost_bloom"},
	]
	game.battle.accept_events(events)
	game.refresh()
	game.battle.reduced_effects = false
	game.battle.advance(0.06)
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	await game.get_tree().create_timer(0.12).timeout
	RenderingServer.force_draw()
	var image: Image = game.get_viewport().get_texture().get_image()
	if image.get_size() != Vector2i(1920, 1080):
		image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	var directory := ProjectSettings.globalize_path("res://../docs/v58-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var result := image.save_png(directory.path_join("combat-effects.png"))
	print("V58 VISUAL QA: " + ("PASS" if result == OK else "FAIL") + " -> " + directory.path_join("combat-effects.png"))
	game.get_tree().quit(0 if result == OK else 1)
