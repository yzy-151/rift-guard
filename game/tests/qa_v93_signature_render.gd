extends SceneTree
## Native frame evidence using the exact Main -> BattleView -> signature route.
const MainScene = preload("res://main.tscn")
var game
var destination := "C:/Users/yzy/Desktop/codex/rift-guard/v93-2026-10-04/signatures/native"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): destination = arg.trim_prefix("--qa-output=")
	call_deferred("run")

func setup(character: String) -> Dictionary:
	var squad: Array[String] = [character,"traveler"]
	game.sim.reset_stage("stage_02",squad,93013)
	game.sim.start()
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	game.sim.terrain_features.clear()
	game.sim.pending_impacts.clear()
	game.sim.skill_effects.clear()
	game.battle.effects.clear()
	game.battle.selected_id = -1
	var hero: Dictionary = game.sim.heroes[0]
	hero.deployed = true
	hero.pos = Vector2(345,350)
	hero.target = hero.pos
	hero.energy = hero.max_energy
	var ally: Dictionary = game.sim.heroes[1]
	ally.pos = Vector2(415,420)
	ally.target = ally.pos
	ally.deployed = true
	ally.hp = ally.max_hp*0.4
	for point in [Vector2(610,350),Vector2(820,350),Vector2(690,435)]:
		var enemy: Dictionary = game.sim.spawn_enemy(point,"grunt")
		enemy.hp = 100000.0
		enemy.max_hp = enemy.hp
		enemy.armor = 0.0
	game.sim.events.clear()
	game.selected_id = -1
	game.refresh()
	return hero

func advance(seconds: float) -> void:
	for i in ceili(seconds*60.0):
		game.sim.elapsed += 1.0/60.0
		game.sim._pending_impact_tick(1.0/60.0)
		game.sim._skill_effect_tick(1.0/60.0)
		game.battle.accept_events(game.sim.drain_events())
		game.battle.advance(1.0/60.0)
	game.refresh()

func capture(label: String) -> void:
	game.battle.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = game.get_viewport().get_texture().get_image()
	frame.save_png(destination.path_join(label+".png"))
	print("NATIVE " + label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(destination)
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
	game.story.active = false
	setup("hero_13")
	game.sim.activate_hero_ultimate(0,Vector2(960,350))
	advance(0.92)
	await capture("gwen-1-first-flight")
	advance(0.64)
	await capture("gwen-3-second-flight")
	advance(0.53)
	await capture("gwen-5-third-flight")
	game.battle.reduced_effects = true
	await capture("gwen-5-low-effects")
	game.battle.reduced_effects = false
	setup("hero_06")
	game.sim.activate_hero_skill(0,Vector2(730,350))
	advance(0.7)
	await capture("amiya-black-crystals")
	advance(2.5)
	game.sim.activate_hero_ultimate(0,Vector2(930,350))
	advance(1.88)
	await capture("amiya-chimera-line")
	setup("hero_03")
	game.sim.activate_hero_skill(0,Vector2(715,350))
	advance(1.6)
	await capture("furina-three-guests")
	game.sim.activate_hero_ultimate(0,Vector2(345,350))
	advance(1.2)
	await capture("furina-fanfare")
	game.queue_free()
	await process_frame
	quit(0)
