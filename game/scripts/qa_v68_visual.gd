extends RefCounted

func run(game) -> void:
    var squad: Array[String] = ["hero_13", "hero_04", "hero_10"]
    game.sim.reset_stage("stage_02", squad, 6808)
    game.sim.start()
    for index in game.sim.heroes.size():
        game.sim.heroes[index].deployed = true
        game.sim.heroes[index].pos = Vector2(270 + index * 95, 360 + index * 125)
        game.sim.heroes[index].target = game.sim.heroes[index].pos
    var kinds := ["troop_cannon","troop_melee","troop_ranged","hilichurl_brute","rift_bat","originium_bug"]
    for index in kinds.size():
        game.sim.spawn_enemy(Vector2(705 + (index % 3) * 190, 265 + (index / 3) * 275), kinds[index])
    game.sim.supports = {"support_barrage":{"stacks":1,"timer":4.0,"power":20,"interval":5.0},"support_crossfire":{"stacks":1,"timer":4.0,"power":20,"interval":5.0},"support_heal":{"stacks":1,"timer":4.0,"power":20,"interval":5.0},"support_finale":{"stacks":1,"timer":4.0,"power":20,"interval":5.0}}
    game.hud.overlay.hide()
    game.refresh()
    await game.get_tree().create_timer(0.25).timeout
    RenderingServer.force_draw()
    await game.get_tree().process_frame
    var image: Image = game.get_viewport().get_texture().get_image()
    var output := ProjectSettings.globalize_path("res://../docs/v68-validation/01-new-roster-and-enemies.png")
    DirAccess.make_dir_recursive_absolute(output.get_base_dir())
    var err := image.save_png(output)
    print("V68 VISUAL: " + ("saved" if err == OK else "failed"))
    game.get_tree().quit(0 if err == OK else 1)
