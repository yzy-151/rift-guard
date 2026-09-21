extends SceneTree

const MainScene = preload("res://main.tscn")
const FPS := 24.0

func _initialize() -> void:
    call_deferred("_run")

func _capture(game: Node, frame: int) -> bool:
    game.battle.queue_redraw()
    RenderingServer.force_draw()
    await process_frame
    var image: Image = game.get_viewport().get_texture().get_image()
    if image == null:
        return false
    var directory := ProjectSettings.globalize_path("res://../outputs/slime-king-gifs-v1/rift-laser-fan-phase3-frames")
    DirAccess.make_dir_recursive_absolute(directory)
    return image.save_png(directory.path_join("frame-%03d.png" % frame)) == OK

func _run() -> void:
    var game = MainScene.instantiate()
    root.add_child(game)
    await process_frame
    game.test_mode = true
    game.set_process(false)
    game.set_physics_process(false)
    game.mode_select_panel.close()
    game.stage_select_panel.close()
    game.squad_panel.root.hide()
    game.dialogue.hide()
    game.hud.get_child(0).show()
    var squad: Array[String] = ["traveler", "hero_01", "hero_04"]
    game.sim.reset_stage("stage_02", squad, 9203)
    game.sim.start()
    game.sim.terrain_features.clear()
    game.sim.enemies.clear()
    game.sim.enemy_lookup.clear()
    var positions: Array[Vector2] = [Vector2(420, 355), Vector2(530, 275), Vector2(610, 440)]
    for index in game.sim.heroes.size():
        var hero: Dictionary = game.sim.heroes[index]
        hero.deployed = true
        hero.pos = positions[index]
        hero.target = hero.pos
        hero.hp = 10000.0
        hero.max_hp = 10000.0
    var boss: Dictionary = game.sim.spawn_enemy(Vector2(930, 355), "boss_01")
    boss.boss_phase = 3
    boss.damage = 120.0
    game.sim._start_rift_warning(boss, "rift_laser")
    boss.special_pending = true
    boss.special_move = "rift_laser"
    var total_frames := ceili((float(boss.special_warning_total) + 0.82) * FPS)
    for frame in total_frames:
        var dt := 1.0 / FPS
        if bool(boss.special_pending):
            boss.special_warning = float(boss.special_warning) - dt
            if boss.special_warning <= 0.0:
                boss.special_pending = false
                game.sim._execute_rift_special(boss, "rift_laser")
                game.battle.accept_events(game.sim.drain_events())
        game.battle.advance(dt)
        game.refresh()
        if not await _capture(game, frame):
            quit(1)
            return
    print("RIFT FAN GIF CAPTURE COMPLETE")
    quit(0)
