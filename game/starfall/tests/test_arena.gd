extends SceneTree

const Simulation = preload("res://starfall/simulation.gd")
const Arena = preload("res://starfall/arena.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena = Arena.new()
	root.add_child(arena)
	arena.set_process(false)
	check(arena.has_method("windup_cue"),"enemy aim follows live windup state")
	if arena.has_method("windup_cue"):
		for kind in ["ranged","boss_01"]:
			var sim = Simulation.new()
			sim.start("endless",["traveler","hero_03","hero_08"],1234)
			sim.spawn_timer = 999
			for hero in sim.heroes: hero.pos = Vector2(300,200)
			var enemy = sim.spawn_enemy(kind,Vector2(1200,600))
			enemy.pattern = 1
			sim._begin_enemy_attack(enemy,Vector2(960,600))
			var before: Dictionary = arena.windup_cue(enemy)
			check(not before.is_empty(),kind+" windup shows an aim cue")
			enemy.freeze = 2.0
			for i in range(90):
				sim.step(1.0/60.0,Vector2.ZERO,Vector2(960,600))
				arena._process(1.0/60.0)
			var frozen: Dictionary = arena.windup_cue(enemy)
			check(not frozen.is_empty(),kind+" aim remains beyond original duration while frozen")
			if not frozen.is_empty():
				check(is_equal_approx(frozen.life,before.life),kind+" warning progress is frozen with attack")
				enemy.pos += Vector2(0,80)
				check(arena.windup_cue(enemy).dir==enemy.locked_dir,kind+" knockback preserves actual firing direction")
			for i in range(180): sim.step(1.0/60.0,Vector2.ZERO,Vector2(960,600))
			check(enemy.state!="windup" and arena.windup_cue(enemy).is_empty(),kind+" aim ends when the cast resolves")
			enemy.hp = 0
			enemy.state = "windup"
			check(arena.windup_cue(enemy).is_empty(),kind+" dead caster has no aim cue")
	arena.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS: live ranged and boss aim cues survive freeze and follow cast lifecycle")
	quit(0 if failures.is_empty() else 1)
