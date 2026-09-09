extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V14 PASS: " + message)
	else:
		failures += 1
		push_error("V14 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.hud.signature = ""
	game.refresh()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v14-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	var sim = game.sim
	var solo: Array[String] = ["traveler"]
	expect(game.content.loaded and game.content.errors.is_empty(), "embedded Excel data loads without the missing-xlsx warning")

	game.open_mode_menu()
	expect(game.mode_select_panel.is_open(), "mode menu opens")
	game.mode_select_panel.buttons["rift_watch"].pressed.emit()
	expect(game.stage_select_panel.is_open(), "clicking campaign opens the stage selector")
	expect(not game.stage_select_panel.buttons["stage_01"].disabled, "first campaign stage is clickable")
	game.stage_select_panel.buttons["stage_01"].pressed.emit()
	expect(game.squad_panel.is_open() and game.pending_stage_id == "stage_01", "clicking stage one opens squad selection")
	game.squad_panel.confirm_button.pressed.emit()
	expect(sim.current_stage_id == "stage_01" and sim.run_state.mode_id == "rift_watch", "confirming squad enters campaign stage one")
	if game.story.active:
		game.story.active = false
		game.dialogue.root.hide()
	sim.state = "running"
	game.hud.get_child(0).show()

	expect(sim.terrain_features.size() >= 5, "campaign map loads five tactical terrain features")
	var kinds: Array[String] = []
	for feature: Dictionary in sim.terrain_features:
		kinds.append(str(feature.get("type", "")))
	expect(["high_ground", "low_ground", "blocked", "mechanism", "shortcut"].all(func(kind: String) -> bool: return kind in kinds), "high ground, low ground, blockers, mechanisms and shortcuts are all configured")

	var high: Dictionary = sim.terrain_features.filter(func(feature: Dictionary) -> bool: return feature.get("type", "") == "high_ground")[0]
	var hero: Dictionary = sim.heroes[0]
	hero.pos = high.area.get_center()
	var boosted_range: float = sim.attack_range_screen_radii(hero).x
	hero.pos = Vector2(high.area.end.x + 35.0, high.area.get_center().y)
	var normal_range: float = sim.attack_range_screen_radii(hero).x
	expect(boosted_range > normal_range and sim.terrain_attack_scale(high.area.get_center()) > 1.0, "high ground increases both range and attack power")
	var low: Dictionary = sim.terrain_features.filter(func(feature: Dictionary) -> bool: return feature.get("type", "") == "low_ground")[0]
	expect(sim.terrain_movement_scale(low.area.get_center()) < 1.0, "low ground applies its displayed movement penalty")

	var blocked: Dictionary = sim.terrain_features.filter(func(feature: Dictionary) -> bool: return feature.get("type", "") == "blocked")[0]
	hero.pos = blocked.area.position + Vector2(-20, blocked.area.size.y * 0.5)
	hero.target = blocked.area.end + Vector2(40, -blocked.area.size.y * 0.5)
	for i in 30:
		sim._move_hero_with_terrain(hero, 0.05)
	expect(not blocked.area.grow(6.0).has_point(hero.pos), "blocked terrain prevents direct traversal")

	var mechanism: Dictionary = sim.terrain_features.filter(func(feature: Dictionary) -> bool: return feature.get("type", "") == "mechanism")[0]
	hero.pos = mechanism.area.get_center()
	var target: Dictionary = sim.spawn_enemy(mechanism.area.get_center() + Vector2(45, 0), "armored")
	var target_hp: float = target.hp
	mechanism.timer = 0.0
	sim._terrain_tick(0.1)
	expect(target.hp < target_hp, "occupied mechanism damages nearby enemies")

	var shortcut: Dictionary = sim.terrain_features.filter(func(feature: Dictionary) -> bool: return feature.get("type", "") == "shortcut")[0]
	while float(shortcut.hp) > 0.0:
		sim.damage_terrain_shortcuts(shortcut.area.get_center(), 80.0, 300.0)
	expect(float(shortcut.hp) <= 0.0 and not sim._terrain_blocks(shortcut.area.get_center()), "traveler skills can destroy and open the shortcut")

	var Runtime = preload("res://scripts/stages/stage_runtime.gd")
	var runtime = Runtime.new(sim.database.stages["stage_01"])
	var warning_batch: Array[Dictionary] = runtime.tick(1.0)
	var warnings := warning_batch.filter(func(event: Dictionary) -> bool: return event.kind == "route_warning")
	expect(not warnings.is_empty() and warnings[0].has("enemy_id") and warnings[0].has("count"), "route warnings include enemy type and count before spawning")
	game.battle.accept_events(warning_batch)
	game.hud.signature = ""
	game.hud.refresh(sim, 0)
	expect(game.hud.wave_timeline_panel.visible and not game.hud.wave_timeline_labels[0].text.is_empty(), "HUD presents the next three enemy entries as a timeline")

	sim.enemies.clear()
	var enemy_kinds := ["runner", "flyer", "ranged", "buffer", "shielded", "charger", "healer", "splitter", "warder"]
	for i in enemy_kinds.size():
		var enemy: Dictionary = sim.spawn_enemy(Vector2(760 + (i % 3) * 95, 250 + (i / 3) * 105), enemy_kinds[i])
		enemy.route_points = [enemy.pos, Vector2(120, enemy.pos.y)]
		enemy.route_index = 1
	await capture(game, "01-terrain-timeline-enemy-silhouettes")

	sim.enemies.clear()
	game.set_formation_command("squad")
	expect(game.selected_id == -2 and sim.formation_mode == "squad", "squad command arms whole-party movement")
	sim.command_squad(Vector2(850, 360))
	expect(sim.heroes.all(func(member: Dictionary) -> bool: return member.target.x > 700.0), "squad move assigns formation destinations")
	game.set_formation_command("follow")
	expect(sim.formation_mode == "follow", "follow command activates automatic formation follow")
	game.set_formation_command("hold")
	expect(sim.formation_mode == "hold", "hold command freezes current positions")
	await capture(game, "02-formation-controls")

	var crit_card: Dictionary = sim.database.cards.filter(func(card: Dictionary) -> bool: return card.get("effect", "") == "squad_crit_flat")[0]
	var crit_before := float(sim.heroes[0].get("crit_chance", 0.0))
	sim.apply_v2_card_effect(crit_card)
	expect(float(sim.heroes[0].crit_chance) > crit_before, "critical chance card changes the combat stat")
	var shielded: Dictionary = sim.spawn_enemy(Vector2(720, 360), "shielded")
	sim.apply_hit(shielded, float(shielded.get("shield", 0.0)) + 50.0, "geo")
	var combat_events: Array[Dictionary] = sim.drain_events()
	expect(combat_events.any(func(event: Dictionary) -> bool: return event.kind == "shield_break"), "depleting an enemy shield emits a dedicated break event")

	sim.reset_stage("stage_endless", solo, 1414)
	sim.run_state.crystal_level = 50
	expect(sim.endless_next_threshold() < 3000, "late endless leveling uses the reduced experience curve")
	expect(sim.formation_mode == "follow" and sim.terrain_features.is_empty(), "endless starts in follow mode without crystal terrain mechanics")

	for stage_id in ["stage_01", "stage_02", "stage_03"]:
		var stage: Dictionary = sim.database.stages[stage_id]
		expect(int(stage.duration_seconds) >= 300, "%s supports at least five minutes of play" % stage_id)

	print("V14 TESTS: %d checks; %d failures" % [checks, failures])
	var tree = game.get_tree()
	game.queue_free()
	await tree.process_frame
	tree.quit(0 if failures == 0 else 1)
