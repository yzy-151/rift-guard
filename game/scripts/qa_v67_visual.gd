extends RefCounted

var output_dir := ""

func capture(game, name: String) -> void:
    RenderingServer.force_draw()
    await game.get_tree().process_frame
    await game.get_tree().create_timer(0.10).timeout
    var frame: Image = game.get_viewport().get_texture().get_image()
    if frame == null:
        push_error("V67 VISUAL: no frame for " + name)
        return
    if frame.get_size() != Vector2i(1920, 1080):
        frame.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
    var result := frame.save_png(output_dir.path_join(name + ".png"))
    print("V67 VISUAL %s: %s" % [name, "saved" if result == OK else "failed"])

func run(game) -> void:
    output_dir = ProjectSettings.globalize_path("res://../docs/v67-validation")
    DirAccess.make_dir_recursive_absolute(output_dir)
    var squad: Array[String] = ["traveler", "hero_01", "hero_07"]
    game.sim.reset_stage("stage_02", squad, 6702)
    game.sim.start()
    game.sim.heroes[0].deployed = true
    game.hud.overlay.hide()
    game.refresh()
    await capture(game, "01-battle")
    game.hud._show_ability_info(false)
    await capture(game, "02-skill-details")
    game.hud.dismiss_info_popover()
    game.dialogue.play_death_transition()
    await game.get_tree().create_timer(1.75).timeout
    await capture(game, "03-death-awaiting-click")
    game.dialogue.acknowledge_animation()
    await game.get_tree().create_timer(0.30).timeout
    game.sim.reset_stage("stage_02", squad, 6703)
    game.sim.start()
    game.sim.run_state.crystal_level = 3
    game._begin_recruitment(1, Vector2(700, 380))
    await game.get_tree().create_timer(0.45).timeout
    await capture(game, "04-recruit-dialogue")
    game.story.reset()
    game.dialogue.root.hide()
    game.hud.get_child(0).show()
    game.pending_recruitment.success = true
    game._resolve_recruitment()
    await game.get_tree().create_timer(1.20).timeout
    await capture(game, "05-success-awaiting-click")
    game.dialogue.acknowledge_animation()
    await game.get_tree().create_timer(0.25).timeout
    game.sim.reset_stage("stage_02", squad, 6704)
    game.sim.start()
    game.sim.run_state.crystal_level = 3
    game.pending_recruitment = {"hero_id": 1, "point": Vector2(700, 380), "success": false}
    game._resolve_recruitment()
    await game.get_tree().create_timer(0.65).timeout
    await capture(game, "06-recruit-departure")
    await game.get_tree().create_timer(0.80).timeout
    game.get_tree().quit()
