extends SceneTree

var game
var failures: Array[String] = []
var output := ""
var checks := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	if not output.is_absolute_path(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(90.0).timeout.connect(func(): printerr("FAIL: workshop QA timeout"); quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func click(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.test_mode = true
	if game.sim == null or game.settings_panel == null:
		printerr("FAIL: main scene failed to initialize"); quit(2); return
	for i in 5: await process_frame
	await key(KEY_F10)
	await create_timer(0.25).timeout
	check(game.settings_panel.is_open(), "F10 opens settings through real input")
	check(game.has_method("open_workshop"), "settings exposes independent workshop")
	if game.has_method("open_workshop"):
		await exercise_workshop()
	var report := {"checks":checks,"failures":failures,"renderer":DisplayServer.get_name()}
	var report_file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	print("V93 WORKSHOP: %d checks, %d failures" % [checks, failures.size()])
	await game._quit_after_audio_cleanup(0 if failures.is_empty() else 1)

func exercise_workshop() -> void:
	var initial_sim = game.sim
	var initial_hash := object_hash(game.sim)
	var storage := storage_hash(game.qa_storage_path)
	var initial_nodes := get_node_count()
	var initial_tweens := get_processed_tweens().size()
	await click(game.settings_panel.workshop_button.get_global_rect().get_center())
	check(game.workshop != null, "real settings button opens workshop")
	if game.workshop == null: return
	var workshop = game.workshop
	var workshop_weak: WeakRef = weakref(workshop)
	var session = workshop.session
	check(session.auto_attack and session.enemy_action, "workshop starts with autonomous hero and enemy combat enabled")
	check(session.sim != game.sim and workshop.battle.sim == session.sim, "independent real simulation and renderer")
	check(workshop.fx.battle_view == workshop.battle and workshop.audio != game.battle_audio, "independent effects and audio director")
	await key(KEY_SPACE)
	check(session.paused, "real space pauses workshop")
	var at_time: float = session.sim.elapsed
	var view_time: float = workshop.battle.clock
	await create_timer(0.10).timeout
	check(is_equal_approx(session.sim.elapsed, at_time) and is_equal_approx(workshop.battle.clock, view_time), "pause freezes simulation and rendered phase")
	await key(KEY_PERIOD)
	check(is_equal_approx(session.sim.elapsed, at_time + 1.0 / 60.0), "single step advances exactly one fixed frame")
	# Isolate the manual-skill checks below from the live defaults.
	await click(workshop.buttons.auto.get_global_rect().get_center())
	await click(workshop.buttons.enemy_action.get_global_rect().get_center())
	check(not session.auto_attack and not session.enemy_action, "manual skill fixture explicitly disables autonomous actions")
	# Every listed character, including explicitly unfinished entries, is placed
	# through the same button and real viewport mouse path as the player.
	var positions: Array[Vector2] = []
	for y in range(170, 551, 56):
		for x in range(480, 1191, 70):
			var point := Vector2(x, y)
			if session.legal(point): positions.append(point)
	var hero_ids: Array[String] = []
	for i in workshop.hero_picker.item_count:
		var id := str(workshop.hero_picker.get_item_metadata(i))
		hero_ids.append(id)
		workshop.hero_picker.select(i)
		await click(workshop.buttons.hero.get_global_rect().get_center())
		var point := positions[i]
		await click(workshop.battle.world_to_screen(point))
		check(session.selected_kind == "hero" and session.selected().get("character_id", "") == id, "place roster " + id)
		check(session.selected().get("pos", Vector2.ZERO).distance_to(point) < 0.1, "placement respects camera transform " + id)
	check(session.sim.run_state.squad.size() == session.sim.database.characters.size() and session.sim.heroes.size() > 3, "all catalog heroes coexist without squad slot limit")
	var enemy_point := Vector2(1000, 420)
	if not session.legal(enemy_point, 60.0):
		for point: Vector2 in positions:
			if point.x > 800 and point.y > 300 and session.legal(point, 60.0): enemy_point = point; break
	var previous_count: int = session.sim.enemies.size()
	for i in workshop.enemy_picker.item_count:
		workshop.enemy_picker.select(i)
		await click(workshop.buttons.enemy.get_global_rect().get_center())
		await click(workshop.battle.world_to_screen(enemy_point))
	check(session.sim.enemies.size() == previous_count + session.Catalog.ENEMIES.size(), "full monster and boss catalog places through input")
	await click(Vector2(1100, 500), MOUSE_BUTTON_RIGHT)
	var enemy_before: int = session.sim.enemies.size()
	await click(workshop.buttons.enemy.get_global_rect().get_center())
	await click(Vector2(5, 80))
	check(session.sim.enemies.size() == enemy_before, "illegal click outside board rejected")
	await click(Vector2(1100, 500), MOUSE_BUTTON_RIGHT)
	# Select a hero above the original three slots, aim Q/E through the controller.
	var gwen: Dictionary = {}
	for hero: Dictionary in session.sim.heroes:
		if str(hero.character_id) == "hero_13": gwen = hero
	await click(workshop.battle.world_to_screen(gwen.pos))
	check(session.selected_id == int(gwen.id) and session.selected_id > 2, "world selection retains stable expanded-roster hero id")
	var old_position: Vector2 = gwen.pos
	var moved_position: Vector2 = old_position + Vector2(15, 10)
	await click(workshop.battle.world_to_screen(moved_position), MOUSE_BUTTON_RIGHT)
	check(gwen.pos.is_equal_approx(old_position) and gwen.target.is_equal_approx(moved_position), "paused right click queues a walking goal without teleporting")
	await key(KEY_PERIOD)
	check(gwen.pos.distance_to(old_position)>0.01 and gwen.pos.distance_to(old_position)<old_position.distance_to(moved_position), "one frame moves selected hero partway toward the goal")
	for i in 120:
		if gwen.pos.distance_to(moved_position)<0.5: break
		await key(KEY_PERIOD)
	check(gwen.pos.is_equal_approx(moved_position), "walking reaches the selected goal")
	await click(workshop.battle.world_to_screen(old_position), MOUSE_BUTTON_RIGHT)
	for i in 120:
		if gwen.pos.distance_to(old_position)<0.5: break
		await key(KEY_PERIOD)
	await key(KEY_Q)
	await click(workshop.battle.world_to_screen(enemy_point))
	check(int(gwen.skill_uses) == 1, "Q belongs to selected expanded-roster hero")
	await key(KEY_E)
	await click(workshop.battle.world_to_screen(enemy_point))
	check(int(gwen.ultimate_uses) == 1, "E belongs to selected expanded-roster hero")
	await key(KEY_PERIOD)
	check(workshop.event_history.any(func(e: Dictionary): return str(e.get("kind", "")) == "ultimate_cast" and int(e.get("hero_id", -1)) == int(gwen.id)), "real effects receive selected hero skill batch")
	var range_card := -1
	for i in workshop.card_picker.item_count:
		if str(workshop.card_picker.get_item_metadata(i).get("effect", "")) == "range_flat": range_card = i; break
	check(range_card >= 0, "original range card available")
	if range_card >= 0:
		workshop.card_picker.select(range_card)
		var before: float = gwen.range
		var neighbor: float = session.sim.heroes[0].range
		await click(workshop.buttons.card.get_global_rect().get_center())
		check(gwen.range > before and is_equal_approx(session.sim.heroes[0].range, neighbor), "card applies to chosen hero only")
	var victim: Dictionary = session.sim.enemies[0]
	var enemy_position: Vector2 = victim.pos
	var health_before := 0.0
	for enemy: Dictionary in session.sim.enemies: health_before += float(enemy.hp) + float(enemy.shield)
	for i in 120: await key(KEY_PERIOD)
	var health_after := 0.0
	for enemy: Dictionary in session.sim.enemies: health_after += float(enemy.hp) + float(enemy.shield)
	check(health_after < health_before, "selected hero Q/E produce real enemy damage while auto attacks are off")
	check(session.sim.state == "running" and session.sim.run_state.crystal_xp == 0, "actual kills cannot trigger workshop XP or reward state")
	check(victim.pos.is_equal_approx(enemy_position), "enemy action off keeps enemy position fixed while skills progress")
	check(workshop.audio.played > 0, "real battle audio receives workshop events")
	var damage_probe: Dictionary = session.sim.heroes[0]
	var hp_before: float = damage_probe.hp
	session.sim.damage_hero(int(damage_probe.id), 100000.0)
	check(is_equal_approx(damage_probe.hp, hp_before), "invulnerability rejects real incoming damage")
	await click(workshop.buttons.invulnerable.get_global_rect().get_center())
	# Gwen's real Q grants nearby allies five seconds of separate skill immunity;
	# isolate the workshop switch from that already-verified ability.
	damage_probe.invulnerable_timer = 0.0
	session.sim.damage_hero(int(damage_probe.id), 100000.0)
	check(damage_probe.hp < hp_before, "invulnerability can be turned off through real control")
	await click(workshop.buttons.recover.get_global_rect().get_center())
	check(is_equal_approx(damage_probe.hp, damage_probe.max_hp), "recover restores fallen deployed hero")
	await click(workshop.buttons.invulnerable.get_global_rect().get_center())
	await click(workshop.buttons.clear_enemies.get_global_rect().get_center())
	workshop.enemy_picker.select(0)
	await click(workshop.buttons.enemy.get_global_rect().get_center())
	await click(workshop.battle.world_to_screen(enemy_point))
	await click(Vector2(1100, 500), MOUSE_BUTTON_RIGHT)
	await click(workshop.buttons.enemy_action.get_global_rect().get_center())
	var enemy_positions := {}
	for enemy: Dictionary in session.sim.enemies: enemy_positions[int(enemy.id)] = enemy.pos
	for i in 12: await key(KEY_PERIOD)
	check(session.sim.enemies.any(func(enemy: Dictionary): return enemy_positions.has(int(enemy.id)) and enemy.pos.distance_to(enemy_positions[int(enemy.id)]) > 0.01), "enemy action toggle enables real enemy movement")
	await click(workshop.buttons.enemy_action.get_global_rect().get_center())
	await click(workshop.buttons.auto.get_global_rect().get_center())
	check(session.sim.workshop_auto_attack, "automatic attack toggle reaches real simulator")
	await click(workshop.buttons.reset_build.get_global_rect().get_center())
	check(session.cards_applied.is_empty(), "reset builds removes acquired cards")
	check(workshop.battle.effects.is_empty() and workshop.battle.enemy_death_visuals.is_empty(), "reset removes paused impact flashes and death visuals")
	var second_hero: Dictionary = session.sim.heroes[1]
	var preserved_id: int = session.sim.heroes[13].id
	await click(workshop.battle.world_to_screen(second_hero.pos))
	await key(KEY_DELETE)
	check(not second_hero.deployed and int(session.sim.heroes[13].id) == preserved_id, "Delete removes selected hero without reindexing later owners")
	workshop.hero_picker.select(1)
	await click(workshop.buttons.hero.get_global_rect().get_center())
	await click(workshop.battle.world_to_screen(second_hero.pos))
	check(second_hero.deployed and second_hero.id == 1, "removed character redeploys into stable slot")
	await key(KEY_TAB)
	check(not workshop.drawer.visible, "drawer collapses through real input")
	await click(workshop.battle.world_to_screen(Vector2(500, 300)))
	await capture("workshop-collapsed")
	await key(KEY_TAB)
	# Changing map exercises the actual camera projection used for placement.
	await pick(workshop.map_picker, workshop.map_picker.item_count - 1)
	check(session.sim.endless_mode, "map selector chooses real endless terrain")
	var camera: Vector2 = workshop.camera_center
	var endless_point := Vector2(1450, 650)
	if not session.legal(endless_point): endless_point = Vector2(1200, 650)
	workshop.hero_picker.select(0)
	await click(workshop.buttons.hero.get_global_rect().get_center())
	await click(workshop.battle.world_to_screen(endless_point))
	check(session.selected().get("pos", Vector2.ZERO).distance_to(endless_point) < 0.1, "endless camera click places at actual world coordinate")
	check(workshop.camera_center == camera, "placing traveler does not move workshop camera")
	var pan := InputEventKey.new()
	pan.keycode = KEY_D
	pan.pressed = true
	root.push_input(pan, true)
	await create_timer(0.10).timeout
	pan = pan.duplicate(); pan.pressed = false
	root.push_input(pan, true)
	check(workshop.camera_center.x > camera.x, "real D input pans endless workshop camera while paused")
	var before_pan_world: Vector2 = session.selected().pos
	await click(workshop.battle.world_to_screen(before_pan_world))
	check(session.selected_kind == "hero", "selection remains accurate after camera panning")
	await pick(workshop.buttons.speed, 0)
	check(is_equal_approx(session.speed, 0.25), "slow motion selector works through keyboard and GUI input")
	workshop.set_physics_process(false)
	at_time = session.sim.elapsed
	session.paused = false
	workshop._physics_process(0.1)
	check(is_equal_approx(session.sim.elapsed - at_time, 0.025), "quarter-speed advances actual simulator by scaled duration")
	session.paused = true
	workshop.set_physics_process(true)
	workshop.refresh()
	await capture("workshop-expanded")
	await click(workshop.buttons.clear.get_global_rect().get_center())
	await key(KEY_PERIOD)
	check(session.sim.enemies.is_empty() and session.sim.heroes.all(func(h: Dictionary): return not bool(h.deployed)), "clear removes every on-field unit")
	check(session.sim.state == "running", "empty workshop never triggers defeat or reward")
	check(game.sim == initial_sim and object_hash(game.sim) == initial_hash, "original simulation remains byte-identical during workshop")
	check(storage_hash(game.qa_storage_path) == storage, "no workshop operation writes progress or settings")
	await key(KEY_ESCAPE)
	for i in 3: await process_frame
	check(game.workshop == null and workshop_weak.get_ref() == null, "exit frees workshop subtree and audio")
	check(game.settings_panel.is_open() and game.settings_panel.visible, "exit restores original settings")
	check(object_hash(game.sim) == initial_hash, "exit preserves original simulation hash")
	check(get_node_count() == initial_nodes, "exit restores original node count without leaks")
	check(get_processed_tweens().size() == initial_tweens, "exit leaves no workshop tweens")
	check(storage_hash(game.qa_storage_path) == storage, "exit performs no persistence writes")
	# The same entry also returns to a previously paused in-progress battle.
	game.settings_panel.root.hide()
	game.settings_from_menu = false
	game.mode_select_panel.close()
	game.sim.state = "paused"
	game.sim.previous_state = "running"
	game.sim.elapsed = 17.25
	game.hud.get_child(0).show()
	await key(KEY_F10)
	await create_timer(0.2).timeout
	initial_hash = object_hash(game.sim)
	await click(game.settings_panel.workshop_button.get_global_rect().get_center())
	await key(KEY_SPACE)
	await key(KEY_PERIOD)
	await key(KEY_ESCAPE)
	check(game.sim.state == "paused" and object_hash(game.sim) == initial_hash, "paused original battle resumes at exact previous state")

func pick(picker: OptionButton, index: int) -> void:
	await click(picker.get_global_rect().get_center())
	var focused := picker.get_popup().get_focused_item()
	if focused < 0:
		await key(KEY_DOWN)
		focused = picker.get_popup().get_focused_item()
	for i in absi(index - focused): await key(KEY_DOWN if index > focused else KEY_UP)
	await key(KEY_ENTER)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func object_hash(object: Object) -> String:
	return var_to_str(snapshot(object)).sha256_text()

func snapshot(value: Variant) -> Variant:
	if value is RandomNumberGenerator: return {"seed":value.seed, "state":value.state}
	if value is Object:
		var data := {}
		for property: Dictionary in value.get_property_list():
			if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				data[str(property.name)] = snapshot(value.get(str(property.name)))
		return data
	if value is Dictionary:
		var data := {}
		for key: Variant in value: data[key] = snapshot(value[key])
		return data
	if value is Array:
		var data := []
		for item: Variant in value: data.append(snapshot(item))
		return data
	return value

func storage_hash(path: String) -> Dictionary:
	var data := {}
	var dir := DirAccess.open(path)
	if dir == null: return data
	for file: String in dir.get_files(): data[file] = FileAccess.get_sha256(path.path_join(file))
	for sub: String in dir.get_directories(): data[sub] = storage_hash(path.path_join(sub))
	return data
