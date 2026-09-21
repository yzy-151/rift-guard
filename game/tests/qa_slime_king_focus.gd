extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const StageProjection = preload("res://scripts/stage_projection.gd")

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
    checks += 1
    if value:
        print("SLIME KING PASS: " + message)
    else:
        failures += 1
        push_error("SLIME KING FAIL: " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var sim = Sim.new(9201, true)
    sim.reset_stage("stage_01", ["traveler", "hero_01", "hero_04"], 9201)
    check(sim.database.errors.is_empty(), "content database accepts Slime King two-phase contract")
    check(is_equal_approx(float(sim.database.enemy_visuals["boss_02"].display_size), 235.2), "Slime King render size is exactly doubled")
    sim.state = "running"
    for index in sim.heroes.size():
        var hero: Dictionary = sim.heroes[index]
        hero.deployed = true
        hero.pos = [Vector2(460, 300), Vector2(520, 390), Vector2(610, 340)][index]
        hero.target = hero.pos
        hero.max_hp = 10000.0
        hero.hp = 10000.0
    var boss: Dictionary = sim.spawn_enemy(Vector2(900, 360), "boss_02")
    var pattern: Dictionary = sim.database.boss_patterns.get("boss_02", {})
    var phases: Array = pattern.get("phases", [])
    check(phases.size() == 2, "Slime King has exactly two phases")
    var expected_moves := ["slime_bounce", "slime_burst", "slime_reflux", "slime_court"]
    check(not phases.is_empty() and Array(phases[0].get("moves", [])) == expected_moves, "phase one cycles four bespoke skills")
    check(phases.size() >= 2 and Array(phases[1].get("moves", [])) == expected_moves, "phase two upgrades the same four skills")
    boss.boss_phase = 1
    boss.hp = boss.max_hp * 0.55
    sim._update_boss_phase(boss)
    check(int(boss.boss_phase) == 1, "Slime King remains phase one above fifty percent")
    boss.hp = boss.max_hp * 0.50
    sim._update_boss_phase(boss)
    check(int(boss.boss_phase) == 2, "Slime King enters phase two at fifty percent")
    boss.hp = boss.max_hp * 0.10
    sim._update_boss_phase(boss)
    check(int(boss.boss_phase) == 2, "Slime King never enters phase three")
    check(sim.has_method("_start_slime_warning") and sim.has_method("_execute_slime_special"), "custom Slime King skill methods exist")
    boss.boss_phase = 1
    for move in expected_moves:
        sim.enemy_projectiles.clear()
        sim.enemy_hazards.clear()
        sim.drain_events()
        sim._start_slime_warning(boss, move)
        var warning_points: Array = boss.get("special_warning_positions", [])
        var expected_count := 1 if move == "slime_reflux" else (3 if move == "slime_bounce" else 5)
        check(warning_points.size() == expected_count, "phase one warning count for " + move)
        if move == "slime_reflux":
            sim.heroes[0].pos = Vector2(boss.pos) + Vector2(-80, 0)
            sim.heroes[0].target = sim.heroes[0].pos
            boss.shield = 0.0
            var hp_before: float = float(sim.heroes[0].hp)
            sim._execute_slime_special(boss, move)
            check(float(sim.heroes[0].hp) < hp_before and float(boss.shield) > 0.0, "reflux pulls, damages, and restores shield")
        else:
            sim._execute_slime_special(boss, move)
            if move == "slime_bounce":
                check(sim.enemy_hazards.size() == 3, "bounce schedules three sequential landings")
            elif move == "slime_burst":
                check(sim.enemy_projectiles.size() == 5, "burst launches five elemental globs")
                for tick in 150:
                    sim._enemy_projectile_tick(0.02)
                check(sim.enemy_hazards.any(func(hazard: Dictionary) -> bool: return str(hazard.kind) == "slime_pool"), "burst impacts leave slowing slime pools")
            elif move == "slime_court":
                check(sim.enemy_projectiles.size() == 5, "court launches five slime images")
    boss.boss_phase = 2
    sim.enemy_projectiles.clear()
    sim.enemy_hazards.clear()
    sim._start_slime_warning(boss, "slime_bounce")
    check(Array(boss.special_warning_positions).size() == 5, "phase two bounce gains five landings")
    sim._start_slime_warning(boss, "slime_burst")
    sim._execute_slime_special(boss, "slime_burst")
    check(sim.enemy_projectiles.size() == 10, "phase two burst doubles to ten globs")
    sim.enemy_projectiles.clear()
    sim.enemy_hazards.clear()
    sim._start_slime_warning(boss, "slime_court")
    sim._execute_slime_special(boss, "slime_court")
    check(sim.enemy_projectiles.size() == 10 and sim.enemy_hazards.any(func(hazard: Dictionary) -> bool: return str(hazard.kind) == "slime_court_final"), "phase two court adds ten charges and a crown detonation")
    for sound_id in expected_moves:
        check(load("res://assets/sfx/boss/%s.wav" % sound_id) != null, "dedicated sound loads for " + sound_id)
    check(load("res://assets/sfx/boss/slime_attack.wav") != null, "Slime King normal attack sound loads")
    check(load("res://assets/sfx/boss/boss_warning_eva.wav") != null, "EVA boss warning sound loads")
    sim.drain_events()
    boss.pos = Vector2(sim.heroes[0].pos) + Vector2(45, 0)
    boss.warning_victim = 0
    boss.warning_pos = sim.heroes[0].pos
    boss.warning_radius = 90.0
    boss.attack_range = 120.0
    sim._resolve_enemy_warning(boss)
    check(sim.drain_events().any(func(event: Dictionary) -> bool: return str(event.kind) == "slime_attack"), "Slime King normal hit emits bespoke attack cue")
    var rift: Dictionary = sim.spawn_enemy(Vector2(940, 360), "boss_01")
    rift.boss_phase = 3
    sim._start_rift_warning(rift, "rift_laser")
    sim._execute_rift_special(rift, "rift_laser")
    var laser_events: Array = sim.drain_events().filter(func(event: Dictionary) -> bool: return str(event.kind) == "rift_laser")
    var targets: Array = laser_events.back().get("targets", []) if not laser_events.is_empty() else []
    check(targets.size() == 3, "enraged Rift laser exposes three shared-origin targets")
    if targets.size() == 3:
        var source_screen := StageProjection.project(Vector2(rift.pos))
        var center_dir := (StageProjection.project(Vector2(targets[1])) - source_screen).normalized()
        var left_dir := (StageProjection.project(Vector2(targets[0])) - source_screen).normalized()
        var right_dir := (StageProjection.project(Vector2(targets[2])) - source_screen).normalized()
        check(absf(center_dir.dot(left_dir) - 0.5) < 0.02 and absf(center_dir.dot(right_dir) - 0.5) < 0.02, "side lasers are visually sixty degrees from center after stage projection")
    print("SLIME KING COMPLETE: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
