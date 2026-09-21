extends SceneTree
const MainScene = preload("res://main.tscn")
const OUT := "res://../outputs/boss-ui-warning-v2/"

func _initialize() -> void:
    call_deferred("_run")

func capture(game: Node, name: String) -> bool:
    game.battle.queue_redraw()
    RenderingServer.force_draw()
    await process_frame
    var image := game.get_viewport().get_texture().get_image()
    var folder := ProjectSettings.globalize_path(OUT)
    DirAccess.make_dir_recursive_absolute(folder)
    return image != null and image.save_png(folder.path_join(name + ".png")) == OK

func setup(game: Node, stage_id: String, boss_id: String, boss_pos: Vector2) -> Dictionary:
    var squad: Array[String] = ["traveler", "hero_01", "hero_04"]
    game.sim.reset_stage(stage_id, squad, 7731)
    game.sim.start()
    game.sim.terrain_features.clear()
    game.sim.enemies.clear()
    game.sim.enemy_lookup.clear()
    var positions := [Vector2(430, 350), Vector2(560, 285), Vector2(625, 430)]
    for index in game.sim.heroes.size():
        var hero: Dictionary = game.sim.heroes[index]
        hero.deployed = true
        hero.pos = positions[index]
        hero.target = hero.pos
        hero.hp = 10000.0
        hero.max_hp = 10000.0
    var boss: Dictionary = game.sim.spawn_enemy(boss_pos, boss_id)
    boss.hp = float(boss.max_hp) * 0.66
    boss.shield = float(boss.max_hp) * 0.18
    boss.max_shield = boss.shield
    boss.boss_phase = 2
    boss.attack_timer = 999.0
    boss.special_timer = 999.0
    game.sim.drain_events()
    return boss

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

    var slime := setup(game, "stage_01", "boss_02", Vector2(930, 355))
    game.sim._start_slime_warning(slime, "slime_burst")
    slime.special_pending = true
    slime.special_move = "slime_burst"
    game.hud.announce_boss_skill_warning(str(slime.special_move_name), float(slime.special_warning_total), 2)
    game.refresh()
    for tick in 7:
        game.battle.advance(1.0 / 24.0)
        await process_frame
    if not await capture(game, "slime-king-eva-warning"):
        quit(1)
        return

    var rift := setup(game, "stage_02", "boss_01", Vector2(965, 355))
    rift.boss_phase = 3
    game.sim._start_rift_warning(rift, "rift_laser")
    rift.special_pending = true
    rift.special_move = "rift_laser"
    game.hud.announce_boss_skill_warning(str(rift.special_move_name), float(rift.special_warning_total), 3)
    game.refresh()
    for tick in 7:
        game.battle.advance(1.0 / 24.0)
        await process_frame
    if not await capture(game, "rift-laser-screen-60deg"):
        quit(1)
        return
    print("BOSS UI PREVIEW COMPLETE")
    quit(0)
