extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
    checks += 1
    if ok:
        print("V70 PASS: " + message)
    else:
        failures += 1
        push_error("V70 FAIL: " + message)

func run(game) -> void:
    var sim = game.sim
    var squad: Array[String] = ["traveler", "hero_13", "hero_04"]
    sim.reset_stage("stage_03", squad, 7003)
    sim.start()
    sim.run_state.crystal_level = 10
    sim.heroes[2].deployed = false
    sim.state = "reward"
    var drop_point := Vector2(760, 420)
    expect(not sim.deploy_hero(2, drop_point), "ordinary deployment remains blocked by reward modal")
    expect(sim.deploy_hero(2, drop_point, true), "accepted recruitment deploys while a card choice is pending")
    expect(bool(sim.heroes[2].deployed) and Vector2(sim.heroes[2].pos).distance_to(drop_point) < 70.0, "third hero appears at the stage-three drop point")

    sim.state = "running"
    sim.enemies.clear()
    sim.enemy_lookup.clear()
    var grunt: Dictionary = sim.spawn_enemy(Vector2(600, 360), "grunt")
    expect(str(grunt.aura).is_empty(), "ordinary enemy spawns without an element")
    sim.terrain_features.clear()
    sim.terrain_features.append({"type":"weather","area":Rect2(520,300,180,120),"timer":0.0,"pulse_interval":8.0,"element":"anemo","clock":0.0})
    sim._terrain_tick(0.1)
    expect(str(grunt.aura).is_empty(), "weather visuals do not inject an element aura")
    sim.apply_hit(grunt, 1.0, "pyro")
    expect(str(grunt.aura) == "pyro", "ordinary enemy gains aura only after an elemental hit")
    var slime: Dictionary = sim.spawn_enemy(Vector2(720, 360), "slime_hydro")
    expect(str(slime.aura) == "hydro" and str(slime.intrinsic_element) == "hydro", "slime keeps its innate element")

    for stage_id: String in ["stage_01","stage_02","stage_03","stage_04","stage_05","stage_06","stage_07","stage_08"]:
        var stage: Dictionary = sim.database.stages[stage_id]
        var route_boosts := 0
        for feature: Dictionary in stage.get("terrain", []):
            if str(feature.get("id", "")).contains("_attack_route_"):
                route_boosts += 1
        expect(route_boosts >= 3, stage_id + " has additional route boost tiles")

    game.fx.active.clear()
    var vapor_batch: Array[Dictionary] = [{"kind":"vaporize","pos":Vector2(600,360)}]
    game.fx.accept(vapor_batch)
    expect(game.fx.active.is_empty(), "legacy vaporize sheet effect is removed")

    game.battle.effects.clear()
    for i in 80:
        game.battle.effects.append({"kind":"hit","pos":Vector2(600 + i % 3,360),"life":0.2,"total":0.2,"merge_group":"impact","value":1})
    expect(game.battle._try_merge_dense_vfx({"kind":"hit","pos":Vector2(600,360),"value":2}), "normal mode merges dense combat effects")

    print("V70 QA COMPLETE: %d checks, %d failures" % [checks, failures])
    game.audio_director.music_player.stop()
    await game.get_tree().process_frame
    game.get_tree().quit(failures)
