extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V6 PASS: " + message)
	else:
		failures += 1
		push_error("V6 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.refresh()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v6-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func wait_frames(game, count: int) -> void:
	for frame in count:
		await game.get_tree().process_frame

func find_card(game, id: String) -> Dictionary:
	return game.sim.database.cards.filter(func(card): return card.id == id)[0].duplicate(true)

func run(game) -> void:
	expect(game.sim.database.cards.size() == 152, "card pool contains 152 upgrades")
	expect(game.sim.database.stages.size() == 3, "mode one contains three stages")
	await capture(game, "01-helltaker-title")
	game.preview_scene("mode1_stage3_opening")
	await wait_frames(game, 40)
	expect(game.story.active and game.story.key == "mode1_stage3_opening", "stage three opens with a Helltaker story scene")
	await capture(game, "02-stage3-dialogue")
	game.dialogue.skip()
	await wait_frames(game, 12)
	var stage_three_squad: Array[String] = ["traveler", "hero_02", "hero_03"]
	game.sim.reset_stage("stage_03", stage_three_squad, 606)
	game.sim.start()
	game.sim.run_state.traveler_element = "pyro"
	game.sim.heroes[0].element = "pyro"
	game.sim.enemies.clear()
	var roster := ["charger", "healer", "splitter", "warder", "flyer", "ranged", "shielded", "boss_02"]
	for i in roster.size():
		game.sim.spawn_enemy(Vector2(690 + (i % 4) * 105, 270 + (i / 4) * 150), roster[i])
	game.compendium.observe(game.sim)
	expect(game.sim.heroes.size() == 3, "third stage deploys the full three-character squad")
	expect(game.sim.enemies.size() == 8, "specialist roster and second boss coexist")
	await capture(game, "03-stage3-roster")
	var boss: Dictionary = game.sim.enemies.filter(func(enemy): return enemy.kind == "boss_02")[0]
	boss.special_timer = 0.0
	game.sim.tick(0.01)
	game.process_events()
	expect(game.sim.enemies.size() >= 11, "Black Obsidian Broodmother summons a runner pack")
	await capture(game, "04-boss-summon")
	game.sim.enemies.clear()
	var frozen: Dictionary = game.sim.spawn_enemy(Vector2(770, 360), "armored")
	var nearby: Dictionary = game.sim.spawn_enemy(Vector2(845, 360), "grunt")
	game.sim.apply_hit(frozen, 1.0, "hydro")
	game.sim.apply_hit(frozen, 25.0, "cryo")
	game.sim.apply_hit(frozen, 35.0, "")
	game.sim.apply_hit(nearby, 1.0, "pyro")
	game.sim.apply_hit(nearby, 30.0, "anemo")
	game.process_events()
	expect(game.sim.reactions >= 2, "reaction showcase triggers freeze and swirl")
	await capture(game, "05-reaction-showcase")
	game.sim.state = "reward"
	var element_offer: Array[Dictionary] = [find_card(game, "pyro_skill_power_add"), find_card(game, "pyro_skill_area_add"), find_card(game, "pyro_reaction_damage_add")]
	game.sim.rewards.offered = element_offer
	game.hud.signature = ""
	game.refresh()
	expect(game.sim.rewards.offered.all(func(card): return card.requires_element == "pyro"), "locked element reward contains matching build cards")
	await capture(game, "06-element-card-build")
	print("V6 UI TESTS: %d checks; %d failures" % [checks, failures])
	var tree = game.get_tree()
	game.queue_free()
	await tree.process_frame
	tree.quit(0 if failures == 0 else 1)
