extends RefCounted

const Stage = preload("res://scripts/stage_projection.gd")
var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V13 PASS: " + message)
	else:
		failures += 1
		push_error("V13 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.refresh()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v13-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	var sim = game.sim
	var solo: Array[String] = ["traveler"]
	sim.reset_stage("stage_01", solo, 1301)
	sim.state = "running"
	var hero: Dictionary = sim.heroes[0]
	var radii: Vector2 = sim.attack_range_screen_radii(hero)
	expect(radii.x < float(hero.range) and is_equal_approx(radii.y, radii.x * 0.30), "range indicator uses the original compact ellipse")
	var center := Stage.project(hero.pos) + Vector2(0, 8)
	var inside_point := Stage.unproject(center + Vector2(radii.x * 0.82, 0))
	var outside_point := Stage.unproject(center + Vector2(radii.x * 1.08, 0))
	var inside: Dictionary = sim.spawn_enemy(inside_point, "grunt")
	var outside: Dictionary = sim.spawn_enemy(outside_point, "grunt")
	var inside_hp: float = inside.hp
	var outside_hp: float = outside.hp
	hero.attack_timer = 0.0
	sim._hero_tick()
	expect(inside.hp < inside_hp, "enemy inside the visible ellipse receives the basic attack")
	expect(is_equal_approx(float(outside.hp), outside_hp), "enemy outside the visible ellipse is excluded from the basic attack")
	expect(sim.is_in_attack_range(hero, inside_point) and not sim.is_in_attack_range(hero, outside_point), "visual ellipse and combat predicate share one boundary")
	sim.command_move(0, Vector2(1228, 148))
	expect(hero.target.x > 660.0 and hero.target.y < 215.0, "story squad can move across the full map instead of the former defense box")
	var trio: Array[String] = ["traveler", "hero_02", "hero_03"]
	sim.reset_stage("stage_01", trio, 1300)
	sim.state = "running"
	for hero_id in sim.heroes.size():
		sim.command_move(hero_id, Vector2(1180 - hero_id * 35, 155 + hero_id * 30))
	expect(sim.heroes.all(func(member: Dictionary) -> bool: return member.target.x > 1000.0 and member.target.y < 220.0), "all three deployed party members accept full-map movement orders")
	sim.reset_stage("stage_01", solo, 1301)
	sim.state = "running"
	game.selected_id = 0
	await capture(game, "01-compact-range")

	sim.state = "running"
	sim.toggle_pause()
	game.refresh()
	expect(sim.state == "paused" and game.hud.pause_menu_button.visible, "pause screen exposes the return-to-menu action")
	await capture(game, "02-pause-return-menu")
	game.hud.pause_menu_button.pressed.emit()
	expect(game.mode_select_panel.is_open() and sim.state == "ready", "return-to-menu action opens the mode selector and leaves combat")
	game.mode_select_panel.buttons["endless_survival"].pressed.emit()
	expect(sim.endless_mode and sim.current_stage_id == "stage_endless", "mode can be switched to endless after returning from pause")
	var endless_has_crystal_card := false
	for card: Dictionary in sim.database.cards:
		if str(card.get("effect", "")) in ["crystal_health_flat", "crystal_heal", "last_stand"] and sim.card_pool.eligible(card, sim.run_state):
			endless_has_crystal_card = true
	expect(not endless_has_crystal_card, "endless card pool excludes every crystal health and repair card")
	var common_card := {"rarity": "common", "weight": 10}
	var mythic_weight_card := {"rarity": "mythic", "weight": 10}
	sim.run_state.luck = 0.0
	var common_base: float = sim.card_pool.adjusted_weight(common_card, sim.run_state)
	var mythic_base: float = sim.card_pool.adjusted_weight(mythic_weight_card, sim.run_state)
	sim.run_state.luck = 1.0
	var common_lucky: float = sim.card_pool.adjusted_weight(common_card, sim.run_state)
	var mythic_lucky: float = sim.card_pool.adjusted_weight(mythic_weight_card, sim.run_state)
	expect(mythic_lucky / mythic_base > common_lucky / common_base, "luck shifts draw weight toward higher rarity cards")
	sim.run_state.crystal_level = 10
	sim.run_state.traveler_element = "pyro"
	var pity_offer: Array[Dictionary] = sim.card_pool.draw_three(sim.run_state)
	expect(pity_offer.any(func(card: Dictionary) -> bool: return card.get("rarity", "common") == "mythic"), "every tenth level guarantees a mythic choice in addition to luck-weighted drops")

	sim.reset_stage("stage_01", solo, 1302)
	sim.run_state.traveler_element = "pyro"
	sim.heroes[0].element = "pyro"
	var dual_card: Dictionary = {}
	var breaker_card: Dictionary = {}
	var luck_card: Dictionary = {}
	var crystal_guard_card: Dictionary = {}
	for card: Dictionary in sim.database.cards:
		if card.get("id", "") == "mythic_dual_element": dual_card = card
		if card.get("id", "") == "mythic_world_breaker": breaker_card = card
		if card.get("id", "") == "luck_blessing_epic": luck_card = card
		if card.get("id", "") == "crystal_guard_1": crystal_guard_card = card
	var projectile_before: int = int(sim.heroes[0].projectile_count)
	var dual_applied: bool = sim.card_pool.apply_card(dual_card, sim.run_state)
	sim.apply_v2_card_effect(dual_card)
	expect(dual_applied and sim.run_state.traveler_secondary_element not in ["none", "pyro"] and int(sim.heroes[0].projectile_count) == projectile_before + 2, "mythic dual-element card grants a distinct second element and a major combat boost")
	var reaction_before: int = sim.reactions
	var dual_target: Dictionary = sim.spawn_enemy(sim.heroes[0].pos + Vector2(48, 0), "armored")
	dual_target.hp = 9999.0
	dual_target.max_hp = 9999.0
	sim.heroes[0].attack_timer = 0.0
	sim._hero_tick()
	expect(sim.reactions > reaction_before, "dual-element Traveler basic attack triggers an immediate elemental reaction")
	var damage_before: float = float(sim.heroes[0].damage)
	sim.apply_v2_card_effect(breaker_card)
	expect(sim.heroes[0].damage >= damage_before + sim.heroes[0].base_damage * 1.49 and int(sim.heroes[0].chain_count) >= 6, "mythic world-breaker effect is materially stronger than legendary upgrades")
	var base_max_before: int = sim.base_max_hp
	sim.apply_v2_card_effect(crystal_guard_card)
	expect(sim.base_max_hp > base_max_before and sim.base_hp == sim.base_max_hp, "crystal fortification card now raises the actual base maximum health")
	expect(sim.database.errors.is_empty() and sim.database.assets.has("world.crystal"), "mythic rarity and replaceable crystal asset validate in the content database")
	sim.state = "running"
	game.battle.route_previews["upper"] = {"life": 4.0, "total": 4.0, "flying": false, "boss": true}
	await capture(game, "04-route-arrow-crystal")
	sim.run_state.pending_level_ups = 1
	sim.run_state.luck = 1.18
	sim.rewards.offered.assign([dual_card, luck_card, breaker_card])
	sim.state = "reward"
	game.hud.signature = ""
	await capture(game, "05-luck-mythic-cards")

	sim.reset_stage("stage_01", solo, 1303)
	game.hud.get_child(0).show()
	game.play_stage_exit()
	game.battle.advance(1.05)
	expect(game.battle.stage_exit_active and game.battle.stage_exit_phase == "waiting", "scaled newcomer waits beside the redesigned gate")
	await capture(game, "03-scaled-recruit-gate")

	print("V13 TESTS: %d checks; %d failures" % [checks, failures])
	var tree = game.get_tree()
	game.queue_free()
	await tree.process_frame
	tree.quit(0 if failures == 0 else 1)
