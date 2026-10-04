extends SceneTree
## Deterministic gameplay checks: projectile position owns impact time.
const Sim = preload("res://scripts/combat_simulation.gd")
const Skills = preload("res://scripts/hero_signature_skills.gd")
var checks := 0
var failures := 0
var sim

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + message)

func setup(character: String = "hero_13") -> Dictionary:
	sim = Sim.new(93013, true)
	var squad: Array[String] = [character, "traveler"]
	sim.reset_stage("stage_02", squad, 93013)
	sim.start()
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	sim.terrain_features.clear()
	sim.pending_impacts.clear()
	sim.skill_effects.clear()
	sim.events.clear()
	var hero: Dictionary = sim.heroes[0]
	hero.pos = Vector2(330, 350)
	hero.target = hero.pos
	hero.deployed = true
	hero.energy = hero.max_energy
	return hero

func target(point: Vector2) -> Dictionary:
	var enemy: Dictionary = sim.spawn_enemy(point, "grunt")
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	enemy.armor = 0.0
	enemy.shield = 0.0
	return enemy

func begin(hero: Dictionary) -> Dictionary:
	Skills.start(sim, hero, hero.ultimate, Vector2(950,350), 100.0, 620.0)
	return sim.skill_effects.back()

func advance(seconds: float, dt: float = 1.0 / 120.0) -> void:
	var remaining := seconds
	while remaining > 0.00001:
		var step := minf(dt, remaining)
		sim.elapsed += step
		sim._skill_effect_tick(step)
		remaining -= step

func _initialize() -> void:
	var hero := setup()
	var near := target(Vector2(620,350))
	var far := target(Vector2(845,350))
	var side := target(Vector2(700,410))
	var behind := target(Vector2(260,350))
	var zone := begin(hero)
	check(near.hp == 100000.0, "Creating needle cast does not apply invisible immediate damage")
	advance(0.20)
	check(near.hp == 100000.0 and int(zone.released) == 1, "First single needle travels before contact")
	check(not zone.shots.is_empty() and Vector2(zone.shots[0].pos).x > hero.pos.x and Vector2(zone.shots[0].pos).x < near.pos.x, "Live shot state lies between caster and target")
	advance(0.32)
	check(is_equal_approx(100000.0-float(near.hp),100.0), "First volley deals exactly one needle before second volley")
	advance(0.35)
	check(int(zone.released) == 4, "Second volley brings total to one plus three")
	advance(0.65)
	check(int(zone.released) == 9, "Final volley brings total to one plus three plus five")
	advance(1.7)
	check(is_equal_approx(100000.0-float(near.hp),900.0) and is_equal_approx(100000.0-float(far.hp),900.0), "Each of nine piercing needles hits each enemy once")
	check(side.hp == 100000.0 and behind.hp == 100000.0, "Needles do not splash sideways or hit behind caster")
	check(sim.skill_effects.is_empty(), "Needle state expires after final travelling tail")
	var volleys: Array = sim.events.filter(func(e: Dictionary) -> bool: return str(e.kind) == "signature_needle_volley")
	check(volleys.size() == 3 and volleys.map(func(e: Dictionary): return int(e.get("count",0))) == [1,3,5], "Audio and VFX report the real escalating volley counts")

	hero = setup()
	near = target(Vector2(620,350))
	zone = begin(hero)
	advance(0.18)
	near.pos = Vector2(620,440)
	advance(3.0)
	check(near.hp == 100000.0, "Enemy leaving the flight path before contact dodges every needle")

	hero = setup()
	near = target(Vector2(800,350))
	zone = begin(hero)
	advance(0.15)
	hero.deployed = false
	advance(3.0)
	check(near.hp == 100000.0 and sim.skill_effects.is_empty(), "Recalling owner cancels in-flight needles and pending volleys")

	hero = setup()
	near = target(Vector2(800,350))
	zone = begin(hero)
	advance(0.15)
	hero.hp = 0.0
	advance(3.0)
	check(near.hp == 100000.0 and sim.skill_effects.is_empty(), "Fallen owner cancels all needle damage")

	hero = setup()
	var other: Dictionary = sim.heroes[1]
	sim.heroes[0] = other
	sim.heroes[1] = hero
	hero.id = 1
	other.id = 0
	near = target(Vector2(620,350))
	begin(hero)
	advance(3.0)
	check(is_equal_approx(float(hero.damage_done),900.0) and float(other.damage_done)==0.0, "Needle damage is credited to actual caster even in second squad slot")

	hero = setup("hero_03")
	near = target(Vector2(500,350))
	hero.deployed = false
	Skills.start(sim,hero,hero.ultimate,hero.pos,100.0,340.0)
	check(near.hp == 100000.0 and sim.skill_effects.is_empty(), "Recalled caster cannot create Fanfare initial damage or a new zone")

	hero = setup()
	near = target(Vector2(620,350))
	zone = begin(hero)
	advance(3.2, 0.41)
	check(is_equal_approx(100000.0-float(near.hp),900.0), "Swept collision neither tunnels nor duplicates at coarse frame steps")

	hero = setup()
	sim.endless_mode = true
	sim.active_view_rect = Rect2(250,200,420,320)
	far = target(Vector2(825,350))
	zone = begin(hero)
	advance(3.0)
	check(far.hp == 100000.0, "Needles respect endless visible-target damage boundary")

	hero = setup("hero_06")
	near = target(Vector2(610,350))
	var outside := target(Vector2(610,490))
	Skills.start(sim, hero, hero.active_skill, Vector2(610,350),100.0,210.0)
	advance(0.1)
	check(near.hp == 100000.0, "Amiya black crystals must reach targets before dealing damage")
	advance(2.5)
	check(int(near.get("amiya_marks",0)) == 3, "Amiya crystals keep capped black marks")
	Skills.start(sim, hero, hero.ultimate,Vector2(950,350),100.0,250.0)
	var before := float(outside.hp)
	advance(2.8)
	check(outside.hp == before, "Chimera only damages its narrow committed line")
	check(sim.events.any(func(e: Dictionary) -> bool: return str(e.kind)=="signature_chimera_pulse" and e.has("geometry")), "Chimera visual pulses receive exact damage geometry")
	print("V93 SIGNATURES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
