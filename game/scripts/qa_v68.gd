extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
    checks += 1
    if ok:
        print("V68 PASS: " + message)
    else:
        failures += 1
        push_error("V68 FAIL: " + message)

func run(game) -> void:
    var sim = game.sim
    var squad: Array[String] = ["hero_13", "hero_04", "hero_10"]
    sim.reset_stage("stage_02", squad, 6802)
    sim.start()
    expect(sim.database.errors.is_empty(), "new content validates")
    expect(sim.heroes.size() == 3, "three new characters load")
    var expected_sizes := {"rift_bat":75.0,"originium_bug":75.0,"troop_melee":75.0,"troop_ranged":75.0,"troop_cannon":120.0,"hilichurl_brute":375.0}
    for id: String in expected_sizes:
        expect(is_equal_approx(float(sim.database.enemy_visuals[id].display_size), expected_sizes[id]), id + " proportional display size")
    var slime_sizes := {"flyer":64.4,"healer":65.8,"warder":70.0,"boss_02":117.6,"slime_pyro":67.2,"slime_electro":67.2,"slime_anemo":67.2,"slime_hydro":67.2,"slime_cryo":67.2}
    for id: String in slime_sizes:
        expect(is_equal_approx(float(sim.database.enemy_visuals[id].display_size), slime_sizes[id]), id + " slime sprite is 70 percent")
    var before: int = sim.enemies.size()
    sim._spawn_troop_group_on_route("main", 0)
    sim._troop_spawn_tick(1.0)
    var kinds: Array[String] = []
    for enemy: Dictionary in sim.enemies.slice(before):
        kinds.append(str(enemy.kind))
    expect(kinds == ["troop_cannon","troop_melee","troop_melee","troop_melee","troop_ranged","troop_ranged","troop_ranged"], "convoy spawns in seven-member order")
    var hero: Dictionary = sim.heroes[0]
    hero.deployed = true
    hero.pos = Vector2(500, 380)
    hero.hp = hero.max_hp
    var brute: Dictionary = sim.spawn_enemy(hero.pos + Vector2(90, 0), "hilichurl_brute")
    var speed := float(brute.speed)
    brute.pos = hero.pos + Vector2(301, 0)
    sim._enemy_tick(0.0)
    expect(is_equal_approx(float(brute.speed), speed), "brute keeps normal speed outside 300 range")
    brute.pos = hero.pos + Vector2(299, 0)
    sim._enemy_tick(0.0)
    expect(is_equal_approx(float(brute.speed), speed * 2.0) and bool(brute.attack_stance), "brute enters stance and doubles speed within 300 range")
    sim._begin_enemy_warning(brute, hero)
    expect(is_equal_approx(float(brute.speed), speed * 2.0), "brute speed doubles only once")
    sim._execute_ability_impact(hero, hero.active_skill, hero.pos, false)
    expect(float(hero.get("invulnerable_timer", 0.0)) >= 5.0, "Gwen shelters allies for five seconds")
    var hp := float(hero.hp)
    sim.damage_hero(0, 100.0)
    expect(is_equal_approx(float(hero.hp), hp), "sheltered ally takes no damage")
    var ranged: Dictionary = sim.spawn_enemy(hero.pos + Vector2(100, 0), "troop_ranged")
    sim._begin_enemy_warning(ranged, hero)
    sim._resolve_enemy_warning(ranged)
    expect(sim.enemy_projectiles.size() == 1, "ranged soldier fires a tracking orb")
    if not sim.enemy_projectiles.is_empty():
        var start: Vector2 = sim.enemy_projectiles[0].pos
        hero.pos += Vector2(0, 80)
        sim._enemy_projectile_tick(0.1)
        expect(sim.enemy_projectiles.size() == 1 and Vector2(sim.enemy_projectiles[0].pos).distance_to(hero.pos) < start.distance_to(hero.pos), "orb follows moving hero")
    var roxy: Dictionary = sim.heroes[1]
    roxy.deployed = true
    roxy.pos = hero.pos
    hero.hp = hero.max_hp - 200.0
    sim._execute_ability_impact(roxy, roxy.active_skill, hero.pos, false)
    expect(float(hero.hp) > float(hero.max_hp) - 200.0, "Roxy Q heals allies")
    var feng: Dictionary = sim.heroes[2]
    feng.deployed = true
    feng.pos = hero.pos
    hero.hp = hero.max_hp - 200.0
    sim._execute_ability_impact(feng, feng.ultimate, hero.pos, true)
    sim._skill_effect_tick(0.1)
    expect(float(hero.hp) > float(hero.max_hp) - 200.0, "Fengjin E applies periodic healing")
    var count_before: int = sim.skill_effects.size()
    sim._execute_ability_impact(hero, hero.ultimate, brute.pos, true)
    expect(sim.skill_effects.size() > count_before and sim.skill_effects[-1].kind == "needle_barrage", "Gwen E starts needle barrage")
    sim.supports = {"support_barrage":{"stacks":1,"timer":4.0,"power":20,"interval":5.0},"support_crossfire":{"stacks":1,"timer":4.0,"power":20,"interval":5.0},"support_heal":{"stacks":1,"timer":4.0,"power":20,"interval":5.0},"support_finale":{"stacks":1,"timer":4.0,"power":20,"interval":5.0}}
    game.hud.refresh_supports(sim)
    expect(not game.hud.support_labels[3].text.is_empty() and not game.hud.support_details[3].is_empty(), "fourth support fills second column and has details")
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    game.hud._support_label_input(click, 3)
    expect(game.hud.info_popover.visible and not game.hud.info_body.text.is_empty(), "support entry opens effect popover")
    game.hud.dismiss_info_popover()
    var recruit_squad: Array[String] = ["traveler", "hero_13", "hero_04"]
    sim.reset_stage("stage_02", recruit_squad, 6901)
    sim.start()
    sim.run_state.crystal_level = 3
    game._begin_recruitment(1, Vector2(620, 400))
    game.apply_dialogue_choice({"recruit_success":true})
    game.story.skip()
    game.end_dialogue()
    await game.get_tree().create_timer(1.8).timeout
    expect(game.recruitment_transition_active and game.dialogue.animation_waiting, "recruitment remains paused until success animation is acknowledged")
    var frozen_time: float = sim.elapsed
    game._physics_process(1.0)
    expect(is_equal_approx(sim.elapsed, frozen_time) and sim.state == "running", "battle cannot advance before Gwen deployment")
    game.dialogue.acknowledge_animation()
    await game.get_tree().create_timer(0.25).timeout
    expect(bool(sim.heroes[1].deployed) and Vector2(sim.heroes[1].pos).distance_to(Vector2(620, 400)) < 60.0 and not game.recruitment_transition_active, "Gwen appears on the field after correct choice and click")
    print("V68 QA COMPLETE: %d checks, %d failures" % [checks, failures])
    game.audio_director.music_player.stop()
    await game.get_tree().process_frame
    game.get_tree().quit(failures)
