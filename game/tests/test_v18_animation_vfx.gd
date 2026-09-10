extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("V18 PASS: " if ok else "V18 FAIL: ") + message)

func load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _initialize() -> void:
	var traveler_meta := load_json("res://assets/characters/traveler_v18/animation.json")
	var monster_meta := load_json("res://assets/enemies/hilichurl_v18/animation.json")
	check(traveler_meta.get("clips", {}).size() == 4, "traveler publishes idle, run, attack and death clips")
	for clip in ["idle", "run", "attack", "death"]:
		check(int(traveler_meta.get("clips", {}).get(clip, {}).get("frames", 0)) == 48, "%s clip keeps forty-eight stabilized frames" % clip)
	check(int(traveler_meta.get("clips", {}).get("attack", {}).get("release_frame", -1)) == 18, "traveler attack exposes a projectile release marker")
	check(int(monster_meta.get("clips", {}).get("run", {}).get("frames", 0)) == 30, "monster run keeps all thirty supplied frames")

	for path in [
		"res://assets/characters/traveler_v18/idle.png",
		"res://assets/characters/traveler_v18/run.png",
		"res://assets/characters/traveler_v18/attack.png",
		"res://assets/characters/traveler_v18/death.png",
		"res://assets/enemies/hilichurl_v18/run.png",
	]:
		var texture: Texture2D = load(path)
		check(texture != null and texture.get_width() >= 1536 and texture.get_height() >= 1280, path.get_file() + " atlas imports at production resolution")

	var sim = Sim.new(1801, true)
	sim.reset_stage("stage_01", ["traveler"], 1801)
	sim.start()
	sim.enemies.clear()
	sim.events.clear()
	sim.heroes[0].block = 0
	sim.heroes[0].range = 900.0
	sim.heroes[0].element = "pyro"
	var enemy: Dictionary = sim.spawn_enemy(sim.heroes[0].pos + Vector2(95, 0), "grunt")
	sim._hero_tick()
	check(sim.projectiles.size() == 1 and sim.projectiles[0].has("visual_id"), "new projectiles carry stable visual identities")
	var first_id := int(sim.projectiles[0].visual_id) if not sim.projectiles.is_empty() else -1
	sim.heroes[0].attack_timer = 0.0
	sim._hero_tick()
	check(sim.projectiles.size() == 2 and int(sim.projectiles[1].visual_id) > first_id, "projectile visual identities increase without collisions")
	sim.events.clear()
	sim.apply_hit(enemy, 1.0, "hydro")
	check(sim.events.any(func(event: Dictionary) -> bool: return event.kind == "hit" and event.get("element", "") == "hydro"), "hit events preserve their element for matching impact effects")

	print("V18 ANIMATION AND VFX TESTS: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
