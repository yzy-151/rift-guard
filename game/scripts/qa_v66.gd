extends RefCounted
var checks := 0
var failures := 0
func expect(ok: bool, message: String) -> void:
    checks += 1
    if ok:
        print("V66 PASS: " + message)
    else:
        failures += 1
        push_error("V66 FAIL: " + message)
func run(game) -> void:
    var squad: Array[String] = ["traveler", "hero_01", "hero_07"]
    var sim = game.sim
    sim.reset_stage("stage_02", squad, 6602)
    sim.start()
    game.refresh()
    expect(sim.base_hp == 12 and sim.base_max_hp == 12, "base begins at 12 HP")
    expect(game.squad_panel.card_click_sound.stream == preload("res://assets/helltaker/audio/button_menu_confirm_01.wav") and game.squad_panel.confirm_sound.stream == preload("res://assets/helltaker/audio/button_dialogue_confirm_01.wav"), "selection and confirmation sounds swapped")
    expect(sim.deployment_slot_unlocked(0) and not sim.deployment_slot_unlocked(1) and not sim.deployment_slot_unlocked(2), "only first slot unlocked at level 1")
    expect(not sim.deploy_hero(1, Vector2(620, 410)), "locked hero cannot deploy")
    expect(game.hud.hero_buttons[1].disabled and game.hud.hero_lock_labels[1].visible, "locked card displays lock")
    sim.run_state.crystal_level = 3
    game.refresh()
    expect(sim.deployment_slot_unlocked(1) and not sim.deployment_slot_unlocked(2), "second slot unlocks at level 3")
    sim.run_state.crystal_level = 10
    game.refresh()
    expect(sim.deployment_slot_unlocked(2), "third slot unlocks at level 10")
    var ground: Dictionary = sim.spawn_enemy(Vector2(800, 390), "grunt")
    var flyer: Dictionary = sim.spawn_enemy(Vector2(800, 390), "flyer")
    var heavy: Dictionary = sim.spawn_enemy(Vector2(800, 390), "shielded")
    expect(is_equal_approx(float(ground.max_hp), 1.4 * 3.0 * float(preload("res://scripts/combat_catalog.gd").ENEMIES.grunt.hp) * float(sim.stage_runtime.definition.get("enemy_health_multiplier", 1.0))), "ground enemy health exactly triples")
    expect(is_equal_approx(float(heavy.damage), 354.0 * float(sim.stage_runtime.definition.get("enemy_damage_multiplier", 1.0))), "heavy enemy attack triples after stage scaling")
    var terrain_ok := true
    for stage_id in range(1, 9):
        var definition: Dictionary = sim.database.stages["stage_%02d" % stage_id]
        var features: Array = definition.get("terrain", [])
        var high := 0
        var attack := 0
        for item: Dictionary in features:
            if item.get("type", "") == "high_ground": high += 1
            if item.get("type", "") == "attack_ground": attack += 1
        terrain_ok = terrain_ok and high >= 1 and attack >= 2
    expect(terrain_ok, "eight stages include range and multiple attack tiles")
    sim.heroes[0].skill_cooldown = 8.0
    game.hud.refresh_skill(sim, 0)
    expect(not game.hud.skill_button.disabled, "Q info available during cooldown")
    game.hud._show_ability_info(false)
    expect(game.hud.info_popover.visible and not game.hud.info_body.text.is_empty(), "Q displays effect and numbers")
    game.hud.dismiss_info_popover()
    expect(not game.hud.info_popover.visible, "popover can be dismissed")
    var card: Dictionary = sim.database.cards[0]
    sim.run_state.buff_levels[str(card.id)] = 2
    game.hud.refresh_buffs(sim)
    expect(not game.hud.buff_details[0].is_empty() and "Lv.2" in str(game.hud.buff_details[0].title), "buff icon has effect and level")
    expect(ResourceLoader.exists("res://assets/helltaker/dialogue_success/success0009.png") and ResourceLoader.exists("res://assets/helltaker/audio/player_death_01.wav"), "success frames and death audio import")
    game.dialogue.play_death_transition()
    await game.get_tree().create_timer(1.75).timeout
    expect(game.dialogue.animation_waiting and game.dialogue.death_overlay.visible, "death animation waits for click")
    game.dialogue.acknowledge_animation()
    await game.get_tree().create_timer(0.3).timeout
    expect(not game.dialogue.death_playing and not game.dialogue.death_overlay.visible, "death animation releases overlay after click")
    await game.dialogue.play_stage_transition()
    expect(not game.dialogue.transition_texture.visible, "stage transition releases overlay")
    sim.reset_stage("stage_01", squad, 6603)
    sim.start()
    sim.run_state.crystal_level = 3
    game.pending_recruitment = {"hero_id": 1, "point": Vector2(620, 410), "success": true}
    game._resolve_recruitment()
    await game.get_tree().create_timer(1.2).timeout
    expect(game.dialogue.animation_waiting and not bool(sim.heroes[1].deployed), "success holds deployment until click")
    game.dialogue.acknowledge_animation()
    await game.get_tree().create_timer(0.2).timeout
    expect(bool(sim.heroes[1].deployed) and game.recruited_heroes.has(1), "correct choice deploys character")
    sim.reset_stage("stage_01", squad, 6604)
    sim.start()
    sim.run_state.crystal_level = 3
    game.pending_recruitment = {"hero_id": 1, "point": Vector2(620, 410), "success": false}
    game._resolve_recruitment()
    await game.get_tree().create_timer(0.25).timeout
    expect(not game.battle.departing_recruit.is_empty() and game.battle.departing_recruit.pos.x < 620.0, "wrong choice runs from drop point toward base")
    await game.get_tree().create_timer(1.3).timeout
    expect(sim.rejected_recruits.has(1) and not bool(sim.heroes[1].deployed) and game.battle.departing_recruit.is_empty(), "wrong choice removes hero at base")
    sim.reset_stage("stage_01", squad, 6605)
    sim.start()
    game.dragging_hero_id = 0
    game._finish_deploy_drag(game.battle.to_global(game.battle.world_to_screen(Vector2(600, 360))))
    expect(bool(sim.heroes[0].deployed) and game.pending_recruitment.is_empty(), "traveler deploys without recruitment")
    sim.run_state.crystal_level = 3
    game.audio_director.set_scene("battle")
    game._begin_recruitment(1, Vector2(700, 380))
    expect(game.audio_director.current_scene == "battle", "recruit dialogue preserves battle BGM")
    game.story.reset()
    game.dialogue.root.hide()
    game.hud.get_child(0).show()
    game.pending_recruitment.clear()
    sim.state = "lost"
    game.test_mode = false
    game._play_loss_transition()
    await game.get_tree().create_timer(1.75).timeout
    expect(game.dialogue.animation_waiting and not game.mode_select_panel.is_open(), "battle loss waits on death frame")
    game.dialogue.acknowledge_animation()
    await game.get_tree().create_timer(0.35).timeout
    expect(game.mode_select_panel.is_open() and sim.state == "ready", "battle loss returns to main menu")
    game.test_mode = true
    print("V66 QA COMPLETE: %d checks, %d failures" % [checks, failures])
    for child in game.dialogue.get_children():
        if child is AudioStreamPlayer:
            child.stop()
    game.audio_director.music_player.stop()
    game.audio_director.music_player.stream = null
    await game.get_tree().process_frame
    await game.get_tree().process_frame
    game.get_tree().quit(failures)
