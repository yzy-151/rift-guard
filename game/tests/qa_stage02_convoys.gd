extends SceneTree

const Database = preload("res://scripts/content/game_database.gd")
const StageRuntime = preload("res://scripts/stages/stage_runtime.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")
const Sim = preload("res://scripts/combat_simulation.gd")

var failures := 0

func check(value: bool, message: String) -> void:
    if value:
        print("CONVOY PASS: " + message)
    else:
        failures += 1
        push_error("CONVOY FAIL: " + message)

func _initialize() -> void:
    var database = Database.new()
    var stage: Dictionary = database.stages["stage_02"]
    var waves: Array = stage.waves
    var first: Dictionary = waves[0]
    check(str(first.enemy_id) == "troop_cannon" and int(first.count) == 2, "wave one has two complete troop groups")
    check(first.route_ids == ["upper", "lower"], "wave one uses upper and lower routes")
    var ninth: Dictionary = waves[8]
    check(str(ninth.enemy_id) == "troop_cannon" and int(ninth.count) == 6, "wave nine has six complete troop groups")
    check(ninth.route_ids == ["upper", "main", "lower"], "wave nine cycles all three routes")
    var runtime = StageRuntime.new(stage)
    var events: Array[Dictionary] = runtime.tick(float(ninth.at) + float(ninth.interval) * 5.0 + 0.01)
    var ninth_routes: Array[String] = []
    for event: Dictionary in events:
        if event.kind == "spawn" and int(event.wave) == 9:
            ninth_routes.append(str(event.route_id))
    check(ninth_routes == ["upper", "main", "lower", "upper", "main", "lower"], "wave nine emits two ordered three-route rounds")
    check(str(waves[9].enemy_id) != "troop_cannon", "other monsters follow wave nine")
    var speed := float(Catalog.ENEMIES["troop_cannon"].speed)
    check(is_equal_approx(float(Catalog.ENEMIES["troop_melee"].speed), speed), "melee speed matches cannon")
    check(is_equal_approx(float(Catalog.ENEMIES["troop_ranged"].speed), speed), "ranged speed matches cannon")
    var sim = Sim.new(9902, true)
    var squad: Array[String] = ["traveler"]
    sim.reset_stage("stage_02", squad, 9902)
    sim.enemies.clear()
    sim.enemy_lookup.clear()
    sim._spawn_troop_group_on_route("upper", 0)
    sim._troop_spawn_tick(1.2)
    var kinds: Array[String] = []
    for enemy: Dictionary in sim.enemies:
        kinds.append(str(enemy.kind))
    check(kinds.count("troop_cannon") == 1 and kinds.count("troop_melee") == 3 and kinds.count("troop_ranged") == 3, "each convoy is one cannon plus three melee and three ranged")
    print("CONVOY COMPLETE: %d failures" % failures)
    quit(0 if failures == 0 else 1)
