extends SceneTree

const MainScene = preload("res://main.tscn")
const FPS := 24.0

func _initialize() -> void:
    call_deferred("_run")

func _capture(game: Node, folder: String, frame: int) -> bool:
    game.battle.queue_redraw()
    RenderingServer.force_draw()
    await process_frame
    var image: Image = game.get_viewport().get_texture().get_image()
    if image == null:
        return false
    var directory := ProjectSettings.globalize_path("res://../outputs/rift-boss-gifs/" + folder + "-frames")
    DirAccess.make_dir_recursive_absolute(directory)
    return image.save_png(directory.path_join("frame-%03d.png" % frame)) == OK

func _record_skill(game: Node, boss: Dictionary, move: String, tail: float) -> bool:
    game.battle.effects.clear()
    game.sim.enemy_projectiles.clear()
    game.sim.drain_events()
    for hero: Dictionary in game.sim.heroes:
        hero.hp = 10000.0
        hero.max_hp = 10000.0
        hero.invulnerable_timer = 0.0
    game.sim._start_rift_warning(boss, move)
    boss.special_pending = true
    boss.special_move = move
    var cast_time := float(boss.special_warning_total)
    var frames := ceili((cast_time + tail) * FPS)
    var resolved := false
    for frame in frames:
        var dt := 1.0 / FPS
        if bool(boss.special_pending):
            boss.special_warning = float(boss.special_warning) - dt
            if float(boss.special_warning) <= 0.0:
                boss.special_pending = false
                game.sim._execute_rift_special(boss, move)
                game.battle.accept_events(game.sim.drain_events())
                resolved = true
        elif move == "rift_orbs":
            game.sim._enemy_projectile_tick(dt)
            game.battle.accept_events(game.sim.drain_events())
        game.battle.advance(dt)
        game.refresh()
        if not await _capture(game, move, frame):
            return false
    print("RIFT GIF FRAMES: %s %d resolved=%s" % [move, frames, resolved])
    return resolved

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
    game.sim.reset_stage("stage_02", squad, 9132)
    game.sim.start()
    game.sim.terrain_features.clear()
    game.sim.enemies.clear()
    game.sim.enemy_lookup.clear()
    var hero_positions: Array[Vector2] = [Vector2(395, 355), Vector2(535, 280), Vector2(610, 435)]
    for index in game.sim.heroes.size():
        var hero: Dictionary = game.sim.heroes[index]
        hero.deployed = true
        hero.pos = hero_positions[index]
        hero.target = hero.pos
        hero.hp = 10000.0
        hero.max_hp = 10000.0
    var boss: Dictionary = game.sim.spawn_enemy(Vector2(965, 355), "boss_01")
    boss.hp = 12607.0
    boss.max_hp = 12607.0
    boss.damage = 120.0
    boss.boss_phase = 3
    boss.attack_timer = 999.0
    boss.special_timer = 999.0
    game.sim.drain_events()
    for spec in [["rift_laser", 0.75], ["rift_orbs", 2.9], ["rift_overhead", 0.85], ["rift_storm", 0.95]]:
        if not await _record_skill(game, boss, str(spec[0]), float(spec[1])):
            quit(1)
            return
    print("RIFT GIF CAPTURE COMPLETE")
    quit(0)
