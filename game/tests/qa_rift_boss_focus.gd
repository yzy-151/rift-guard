extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")
const Sequences = preload("res://scripts/enemy_sequence_library.gd")
const MainScene = preload("res://main.tscn")

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
    checks += 1
    if value:
        print("RIFT PASS: " + message)
    else:
        failures += 1
        push_error("RIFT FAIL: " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var sim = Sim.new(801, true)
    sim.reset_stage("stage_01", ["traveler", "hero_01"], 801)
    check(str(sim.stage_runtime.definition.get("boss_id", "")) == "boss_02", "first stage is Slime King")
    sim.reset_stage("stage_02", ["traveler", "hero_01"], 802)
    check(str(sim.stage_runtime.definition.get("boss_id", "")) == "boss_01", "second stage is Rift Commander")
    for hero: Dictionary in sim.heroes:
        hero.deployed = true
    sim.heroes[0].pos = Vector2(380, 240)
    sim.heroes[1].pos = Vector2(650, 420)
    sim.heroes[1].hp = 0.0
    sim.heroes[1].animation_state = "down"
    sim._trigger_support("support_heal", {"power": 95.0, "stacks": 1})
    check(sim.heroes[1].hp > 0.0 and sim.heroes[1].animation_state == "idle", "tidal heal revives downed hero")
    var sequences = Sequences.new()
    check(sequences.has_enemy("boss_01"), "Rift Commander atlas registered")
    for state in ["run", "attack", "down", "skill1", "skill2", "skill3", "skill4"]:
        check(sequences.frame_count("boss_01", state) >= 27 and sequences.texture("boss_01", state) != null, "atlas state " + state)
        check(is_equal_approx(float(sequences.state_definition("boss_01", state).get("fps", 0)), 24.0), "24 FPS " + state)
    var boss: Dictionary = sim.spawn_enemy(Vector2(930, 360), "boss_01")
    boss.damage = 70.0
    for move in ["rift_laser", "rift_orbs", "rift_overhead", "rift_storm"]:
        sim.enemy_projectiles.clear()
        sim.drain_events()
        sim._start_rift_warning(boss, move)
        check(float(boss.special_warning_total) >= 1.1, "cast warning " + move)
        for hero: Dictionary in sim.heroes:
            hero.hp = hero.max_hp
            hero.invulnerable_timer = 0.0
        var before: float = float(sim.heroes[1].hp)
        sim._execute_rift_special(boss, move)
        var events: Array[Dictionary] = sim.drain_events()
        check(events.any(func(event: Dictionary) -> bool: return str(event.kind) == move), "damage event " + move)
        if move == "rift_orbs":
            check(sim.enemy_projectiles.size() == 10, "ten tracking orbs")
            for tick in 110:
                sim._enemy_projectile_tick(0.05)
            check(float(sim.heroes[1].hp) < before, "homing orbs damage character")
        else:
            check(float(sim.heroes[1].hp) < before, "area damages warned character " + move)
    boss.boss_phase = 3
    sim._start_rift_warning(boss, "rift_laser")
    sim._execute_rift_special(boss, "rift_laser")
    var rage_laser: Dictionary = sim.drain_events().filter(func(event: Dictionary) -> bool: return str(event.kind) == "rift_laser").back()
    check(Array(rage_laser.get("targets", [])).size() == 3, "low-health laser fans into three shared-origin rays")
    sim.enemy_projectiles.clear()
    sim._start_rift_warning(boss, "rift_orbs")
    sim._execute_rift_special(boss, "rift_orbs")
    check(sim.enemy_projectiles.size() == 18 and sim.enemy_projectiles.all(func(projectile: Dictionary) -> bool: return bool(projectile.get("enraged", false))), "low-health orbs are larger red eighteen-shot volley")
    sim._start_rift_warning(boss, "rift_overhead")
    check(float(boss.special_warning_radius) >= 140.0, "low-health overhead beam widens")
    sim._start_rift_warning(boss, "rift_storm")
    check(Vector2(boss.special_warning_positions[0]) == Vector2(boss.pos) and float(boss.special_warning_radius) >= 680.0, "storm is self-centered and expands farther at low health")
    boss.boss_phase = 1
    sim.enemies.clear()
    sim.enemies.append(boss)
    sim.terrain_features.clear()
    boss.attack_timer = 999.0
    boss.special_timer = 0.0
    boss.special_pending = false
    boss.boss_cast_index = 0
    for hero: Dictionary in sim.heroes:
        hero.hp = 10000.0
        hero.max_hp = 10000.0
    sim.drain_events()
    sim._enemy_tick(0.02)
    check(bool(boss.special_pending) and str(boss.special_move) == "rift_laser", "live boss enters first special")
    var warning_events: Array[Dictionary] = sim.drain_events()
    check(warning_events.any(func(event: Dictionary) -> bool: return str(event.kind) == "boss_warning" and "紫电贯穿" in str(event.get("name", ""))), "live boss emits named EVA warning event")
    for tick in 110:
        sim._enemy_tick(0.02)
    check(sim.drain_events().any(func(event: Dictionary) -> bool: return str(event.kind) == "rift_laser"), "live boss resolves laser after 24 FPS cast")
    boss.special_timer = 999.0
    boss.special_pending = false
    boss.pos = Vector2(sim.heroes[1].pos) + Vector2(20, 0)
    sim._begin_enemy_warning(boss, sim.heroes[1])
    check(is_equal_approx(float(boss.warning_timer), 47.0 / 24.0), "normal attack uses 47 frames at 24 FPS")
    sim.drain_events()
    sim._resolve_enemy_warning(boss)
    check(sim.drain_events().any(func(event: Dictionary) -> bool: return str(event.kind) == "rift_arc"), "normal attack emits electric arc")
    var endless = Sim.new(803, true)
    endless.reset_stage("stage_endless", ["traveler", "hero_01"], 803)
    for hero: Dictionary in endless.heroes:
        hero.deployed = true
    endless.heroes[0].pos = Vector2(250, 300)
    endless.heroes[1].pos = Vector2(900, 600)
    check(int(endless._nearest_live_hero(Vector2(880, 600)).id) == 1, "endless targets nearest living hero")
    endless.terrain_features.clear()
    var flyer: Dictionary = endless.spawn_enemy(Vector2(1100, 600), "flyer")
    flyer.special_timer = 999.0
    var flyer_x := float(flyer.pos.x)
    endless._enemy_tick(0.2)
    check(float(flyer.pos.x) < flyer_x, "endless flyer moves toward closest character")
    var inside := sim.spawn_enemy(Vector2(580, 360), "grunt")
    var outside := sim.spawn_enemy(Vector2(580, 510), "grunt")
    var a := float(inside.hp)
    var b := float(outside.hp)
    sim._trigger_support("support_crossfire", {"power": 160.0, "lane_y": 360.0, "stacks": 1})
    check(float(inside.hp) < a and is_equal_approx(float(outside.hp), b), "crossfire damages only visual lane")
    sim.enemies.clear()
    sim.enemy_lookup.clear()
    var moon_near := sim.spawn_enemy(Vector2(600, 360), "grunt")
    var moon_far := sim.spawn_enemy(Vector2(900, 540), "grunt")
    moon_near.hp = 10000.0
    moon_near.max_hp = 10000.0
    var far_hp := float(moon_far.hp)
    sim._trigger_support("support_barrage", {"power": 175.0, "radius": 130.0, "stacks": 1})
    check(float(moon_near.hp) < 10000.0 and is_equal_approx(float(moon_far.hp), far_hp), "red moon damages only ellipse")
    var anchor := sim.spawn_enemy(Vector2(600, 360), "grunt")
    anchor.hp = 900.0
    anchor.max_hp = 900.0
    moon_near.hp = 10000.0
    sim.supports.clear()
    sim.supports["support_barrage"] = {"timer": 1.36, "interval": 8.0, "power": 175.0, "radius": 130.0, "stacks": 1}
    sim._support_tick(0.02)
    var locked: Vector2 = sim.supports["support_barrage"].get("target_point", Vector2.ZERO)
    moon_near.pos = Vector2(1000, 540)
    var anchor_hp := float(anchor.hp)
    sim._support_tick(1.35)
    check(locked == Vector2(600, 360) and anchor.hp < anchor_hp and is_equal_approx(float(moon_near.hp), 10000.0), "red moon impact stays inside locked warning")
    if DisplayServer.get_name() == "headless":
        print("RIFT COMPLETE: %d checks, %d failures" % [checks, failures])
        quit(0 if failures == 0 else 1)
        return
    var game = MainScene.instantiate()
    root.add_child(game)
    await process_frame
    check(game.battle._rift_boss_sequence_state("rift_orbs") == "skill4" and game.battle._rift_boss_sequence_state("rift_storm") == "skill2", "second and fourth skill actions are swapped")
    check(["rift_laser", "rift_orbs", "rift_overhead", "rift_storm"].all(func(skill_id: String) -> bool: return game.boss_skill_sounds.has(skill_id) and game.boss_skill_sounds[skill_id].stream != null), "four Rift Commander skills have dedicated audio")
    game.test_mode = true
    game.set_process(false)
    game.set_physics_process(false)
    game.mode_select_panel.close()
    game.stage_select_panel.close()
    game.squad_panel.root.hide()
    game.dialogue.hide()
    game.hud.get_child(0).show()
    check(game.hud.skill_button.get_global_rect().encloses(game.hud.skill_icon.get_global_rect()), "Q icon stays in button")
    check(game.hud.ultimate_button.get_global_rect().encloses(game.hud.ultimate_icon.get_global_rect()), "E icon stays in button")
    check(game.hud.skill_button.get_global_rect().encloses(game.hud.skill_key_label.get_global_rect()), "Q label stays in button")
    check(game.hud.ultimate_button.get_global_rect().encloses(game.hud.ultimate_key_label.get_global_rect()), "E label stays in button")
    for formation: Button in game.hud.formation_buttons.values():
        check(game.hud.action_rail.get_global_rect().encloses(formation.get_global_rect()), "formation button stays in action rail")
        check(not game.hud.skill_button.get_global_rect().intersects(formation.get_global_rect()) and not game.hud.ultimate_button.get_global_rect().intersects(formation.get_global_rect()), "formation button clears skill icons")
    var squad: Array[String] = ["traveler", "hero_01"]
    game.sim.reset_stage("stage_02", squad, 804)
    game.sim.start()
    for hero: Dictionary in game.sim.heroes:
        hero.deployed = true
    game.sim.heroes[0].pos = Vector2(390, 400)
    game.sim.heroes[1].pos = Vector2(550, 330)
    game.sim.terrain_features.clear()
    var preview_boss: Dictionary = game.sim.spawn_enemy(Vector2(950, 330), "boss_01")
    game.sim._start_rift_warning(preview_boss, "rift_laser")
    preview_boss.special_pending = true
    preview_boss.special_move = "rift_laser"
    game.battle.advance(0.1)
    game.refresh()
    game.battle.queue_redraw()
    RenderingServer.force_draw()
    await process_frame
    var folder := ProjectSettings.globalize_path("res://../outputs/rift-boss-focus")
    DirAccess.make_dir_recursive_absolute(folder)
    var image: Image = game.get_viewport().get_texture().get_image()
    if image != null:
        image.save_png(folder.path_join("rift-laser-warning.png"))
    if DisplayServer.get_name() != "headless":
        check(image != null, "boss warning screenshot")
        for move in ["rift_laser", "rift_orbs", "rift_overhead", "rift_storm"]:
            game.battle.effects.clear()
            for hero: Dictionary in game.sim.heroes:
                hero.max_hp = 10000.0
                hero.hp = 10000.0
            game.sim._start_rift_warning(preview_boss, move)
            preview_boss.special_pending = true
            preview_boss.special_move = move
            preview_boss.special_warning = float(preview_boss.special_warning_total) * 0.48
            game.battle.advance(0.1)
            game.refresh()
            RenderingServer.force_draw()
            await process_frame
            game.get_viewport().get_texture().get_image().save_png(folder.path_join(move + "-warning.png"))
            preview_boss.special_pending = false
            game.sim._execute_rift_special(preview_boss, move)
            game.battle.accept_events(game.sim.drain_events())
            game.battle.advance(0.08)
            game.refresh()
            RenderingServer.force_draw()
            await process_frame
            game.get_viewport().get_texture().get_image().save_png(folder.path_join(move + "-impact.png"))
    print("RIFT COMPLETE: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
