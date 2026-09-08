extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("BOSS PHASE PASS: " if ok else "BOSS PHASE FAIL: ") + message)

func _initialize() -> void:
	var Sim = preload("res://scripts/combat_simulation.gd")
	var sim = Sim.new(1010, true)
	sim.reset_stage("stage_03", ["traveler", "hero_02", "hero_03"], 1010)
	sim.state = "running"
	var boss: Dictionary = sim.spawn_enemy(Vector2(900, 360), "boss_02")
	var initial_damage: float = boss.damage
	var initial_pulse: float = boss.boss_pulse
	boss.shield = 0.0
	boss.hp = boss.max_hp * 0.69
	sim._update_boss_phase(boss)
	check(boss.boss_phase == 2, "boss enters phase two below seventy percent health")
	check(boss.damage > initial_damage and boss.boss_pulse < initial_pulse, "phase two accelerates pressure")
	check(boss.shield > 0.0, "phase transition restores part of the boss shield")
	check(sim.events.any(func(event): return event.kind == "boss_phase" and int(event.value) == 2), "phase two emits a presentation event")
	var enemy_count: int = sim.enemies.size()
	boss.shield = 0.0
	boss.hp = boss.max_hp * 0.34
	sim._update_boss_phase(boss)
	check(boss.boss_phase == 3, "boss enters final phase below thirty-five percent health")
	check(sim.enemies.size() >= enemy_count + 3, "final phase summons reinforcements")
	check(sim.events.any(func(event): return event.kind == "boss_phase" and int(event.value) == 3), "final phase emits a presentation event")
	print("BOSS PHASE TESTS: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
