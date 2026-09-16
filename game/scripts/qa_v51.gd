extends RefCounted

const CharacterSequenceLibrary = preload("res://scripts/character_sequence_library.gd")
const EnemySequenceLibrary = preload("res://scripts/enemy_sequence_library.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")
const StageProjection = preload("res://scripts/stage_projection.gd")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V51 PASS: " + message)
	else:
		failures += 1
		push_error("V51 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	game.refresh()
	game.battle.advance(0.0)
	await game.get_tree().create_timer(0.55).timeout
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	if image == null:
		expect(false, "capture image is available")
		return
	if image.get_size() != Vector2i(1920, 1080):
		image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	var directory := ProjectSettings.globalize_path("res://../docs/v51-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	expect(image.save_png(directory.path_join(name + ".png")) == OK, "1920x1080 validation capture written: " + name)

func run(game) -> void:
	var character_sequences = CharacterSequenceLibrary.new()
	var enemy_sequences = EnemySequenceLibrary.new()
	var character_counts := {
		"hero_03": {"idle":26, "run":37, "attack":23, "down":48},
		"hero_07": {"idle":24, "run":27, "attack":23, "down":37},
		"hero_08": {"idle":30, "run":21, "attack":31, "down":36},
	}
	for character_id: String in character_counts:
		expect(character_sequences.has_character(character_id), character_id + " sequence profile exists")
		for state: String in ["idle", "run", "attack", "down"]:
			var expected_count: int = int(character_counts[character_id][state])
			var definition: Dictionary = character_sequences.state_definition(character_id, state)
			expect(character_sequences.frame_count(character_id, state) == expected_count, "%s %s uses every supplied frame" % [character_id, state])
			expect(is_equal_approx(float(definition.get("fps", 0.0)), 24.0), "%s %s plays at 24 FPS" % [character_id, state])
			expect(character_sequences.texture(character_id, state) != null, "%s %s atlas loads" % [character_id, state])
		expect(character_sequences.frame_at_time(character_id, "down", 999.0) == int(character_counts[character_id].down) - 1, character_id + " death holds the last frame")
	expect(is_equal_approx(character_sequences.display_size("hero_02"), 150.0), "希露菲 is restored to original size")
	expect(is_equal_approx(character_sequences.display_size("traveler"), 159.0), "traveler is scaled to 106 percent")
	expect(is_equal_approx(character_sequences.display_size("hero_03"), 159.0), "Furina is scaled to 106 percent")
	var database = game.sim.database
	expect(str(database.characters.hero_03.element) == "hydro" and str(database.characters.hero_03.role) == "水系法师", "芙宁娜 is a hydro mage")
	expect(str(database.characters.hero_07.element) == "anemo" and "乐律" in str(database.characters.hero_07.role), "丰川祥子 is an anemo music mage")
	expect(str(database.characters.hero_08.element) == "cryo" and str(database.characters.hero_08.role) == "冰系法师", "艾米莉亚 is a cryo mage")

	var enemy_counts := {
		"grunt": {"run":19, "attack":19, "down":21},
		"runner": {"run":19, "attack":22, "down":44},
		"armored": {"run":60, "attack":25, "down":61},
		"ranged": {"run":43, "attack":53, "down":25},
		"buffer": {"run":29, "attack":41, "down":31},
		"charger": {"run":25, "attack":25, "down":25},
		"shielded": {"run":51, "attack":44, "down":31},
		"splitter": {"run":1, "attack":1, "down":39},
	}
	for enemy_id: String in enemy_counts:
		expect(enemy_sequences.has_enemy(enemy_id), enemy_id + " sequence profile exists")
		for state: String in ["run", "attack", "down"]:
			var expected_count: int = int(enemy_counts[enemy_id][state])
			var definition: Dictionary = enemy_sequences.state_definition(enemy_id, state)
			expect(enemy_sequences.frame_count(enemy_id, state) == expected_count, "%s %s uses every supplied frame" % [enemy_id, state])
			expect(is_equal_approx(float(definition.get("fps", 0.0)), 24.0), "%s %s plays at 24 FPS" % [enemy_id, state])
			expect(enemy_sequences.texture(enemy_id, state) != null, "%s %s atlas loads" % [enemy_id, state])
		expect(enemy_sequences.frame_at_time(enemy_id, "down", 999.0) == int(enemy_counts[enemy_id].down) - 1, enemy_id + " death holds the last frame")

	expect(str(Catalog.ENEMIES.ranged.name) == "丘丘弓箭手" and str(Catalog.ENEMIES.ranged.projectile_style) == "arrow", "丘丘弓箭手 uses ranged arrow projectiles")
	expect(str(Catalog.ENEMIES.buffer.name) == "丘丘萨满" and str(Catalog.ENEMIES.buffer.projectile_style) == "anemo_orb", "丘丘萨满 uses ranged spell projectiles")
	expect(str(Catalog.ENEMIES.shielded.name) == "皮卡超人" and is_equal_approx(float(Catalog.ENEMIES.shielded.large_scale), 3.75), "皮卡超人 is configured as a 3.75x large enemy")
	expect(is_equal_approx(float(Catalog.ENEMIES.shielded.speed), 20.0) and enemy_sequences.display_size("shielded") >= 345.0, "皮卡超人 is slower and visibly larger")
	expect(str(Catalog.ENEMIES.splitter.name) == "哥布林茅房" and bool(Catalog.ENEMIES.splitter.spawner), "哥布林茅房 is a stationary spawner")
	expect(enemy_sequences.procedural("splitter") == "spawner_stretch", "哥布林茅房 uses procedural spawn stretch")
	var slime_names := {"slime_pyro":"火史莱姆", "slime_electro":"雷史莱姆", "slime_anemo":"风史莱姆", "slime_hydro":"水史莱姆", "slime_cryo":"冰史莱姆"}
	for slime_id: String in slime_names:
		expect(Catalog.ENEMIES.has(slime_id) and str(Catalog.ENEMIES[slime_id].name) == str(slime_names[slime_id]), str(slime_names[slime_id]) + " is registered")
		expect(database.enemy_visuals.has(slime_id) and ResourceLoader.exists(str(database.enemy_visuals[slime_id].sprite)), str(slime_names[slime_id]) + " has a replaceable compendium portrait")
	expect(str(Catalog.ENEMIES.boss_02.name) == "史莱姆王", "slime boss is named 史莱姆王")

	var squad: Array[String] = ["hero_03", "hero_07", "hero_08"]
	game.sim.reset_stage("stage_01", squad, 5101)
	game.sim.start()
	game.sim.enemies.clear()
	game.sim.events.clear()
	var hut: Dictionary = game.sim.spawn_enemy(Vector2(980, 360), "splitter")
	hut.route_points = [Vector2(980, 360), Vector2(120, 360)]
	hut.route_index = 1
	hut.route_id = "center"
	hut.special_timer = 0.0
	game.sim._enemy_tick(0.016)
	var children: Array = game.sim.enemies.filter(func(enemy: Dictionary) -> bool: return str(enemy.get("spawned_by", "")) == str(hut.id))
	expect(children.size() == 1 and children.all(func(enemy: Dictionary) -> bool: return str(enemy.kind) == "runner"), "哥布林茅房 spawns one goblin per cycle")
	expect(game.sim.events.any(func(event: Dictionary) -> bool: return str(event.kind) == "goblin_spawn" and int(event.value) == 1), "goblin spawn event drives stretch and VFX")
	expect(children.all(func(enemy: Dictionary) -> bool: return str(enemy.route_id) == "center"), "spawned goblins inherit the hut route")
	for child_index in range(1, 5):
		var child: Dictionary = game.sim.spawn_enemy(Vector2(980 + child_index * 5, 360), "runner")
		child.spawned_by = hut.id
	var before_limit: int = game.sim.enemies.size()
	hut.special_timer = 0.0
	game.sim._enemy_tick(0.016)
	expect(game.sim.enemies.size() == before_limit, "哥布林茅房 respects the five-goblin live cap")

	var hero: Dictionary = game.sim.heroes[0]
	var radii: Vector2 = game.sim.attack_range_screen_radii(hero)
	expect(radii.x >= 170.0 and is_equal_approx(radii.y / radii.x, 0.40), "initial attack range is larger with a 40 percent vertical radius")
	var range_center: Vector2 = StageProjection.project(hero.pos) + Vector2(0, 8)
	var inside_point := StageProjection.unproject(range_center + Vector2(0, radii.y * 0.92))
	var outside_point := StageProjection.unproject(range_center + Vector2(0, radii.y * 1.08))
	expect(game.sim.is_in_attack_range(hero, inside_point) and not game.sim.is_in_attack_range(hero, outside_point), "attack range ellipse matches actual vertical hit testing")
	var left := StageProjection.project(Vector2(60, 360))
	var right := StageProjection.project(Vector2(1220, 360))
	expect(right.x - left.x > 960.0, "normal map projection is widened horizontally")
	expect(StageProjection.unproject(StageProjection.project(Vector2(177, 433))).distance_to(Vector2(177, 433)) < 0.01, "wider projection keeps input coordinates aligned")

	game.sim.enemies.clear()
	game.sim.events.clear()
	var hero_positions := [Vector2(270, 330), Vector2(390, 450), Vector2(500, 270)]
	for hero_index in game.sim.heroes.size():
		game.sim.heroes[hero_index].deployed = true
		game.sim.heroes[hero_index].moving = false
		game.sim.heroes[hero_index].pos = hero_positions[hero_index]
		game.sim.heroes[hero_index].target = hero_positions[hero_index]
	game.selected_id = 0
	var showcase := [
		["grunt", Vector2(700, 230)], ["runner", Vector2(825, 350)], ["ranged", Vector2(950, 205)],
		["buffer", Vector2(1070, 325)], ["charger", Vector2(700, 500)], ["armored", Vector2(850, 500)],
		["shielded", Vector2(1110, 490)], ["splitter", Vector2(1140, 190)]
	]
	for row: Array in showcase:
		var enemy: Dictionary = game.sim.spawn_enemy(row[1], row[0])
		enemy.attack_pending = str(row[0]) in ["ranged", "buffer"]
		enemy.warning_timer = 0.42
	var showcase_events: Array[Dictionary] = [
		{"kind":"enemy_shot", "pos":Vector2(1010,245), "target":Vector2(600,330), "enemy_kind":"ranged", "value":21},
		{"kind":"enemy_shot", "pos":Vector2(1140,370), "target":Vector2(560,390), "enemy_kind":"buffer", "value":18},
		{"kind":"goblin_spawn", "pos":Vector2(1080,250), "value":1},
	]
	game.battle.accept_events(showcase_events)
	await capture(game, "new-characters-and-monsters")
	for enemy_id: String in enemy_counts:
		game.compendium.encountered_enemies[enemy_id] = true
	for slime_id: String in slime_names:
		game.compendium.encountered_enemies[slime_id] = true
	game.compendium.encountered_enemies["boss_02"] = true
	game.compendium_panel.open("enemies")
	await capture(game, "monster-compendium")
	game.compendium_panel.close()
	print("V51 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
