extends RefCounted

const AchievementCatalog = preload("res://scripts/achievement_catalog.gd")
const GeneratedIconCatalog = preload("res://scripts/content/generated_icon_catalog.gd")
var checks := 0
var failures := 0
var output_dir := ""

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("ACHIEVEMENT PASS: " + message)
	else:
		failures += 1
		push_error("ACHIEVEMENT FAIL: " + message)

func capture(game, name: String) -> void:
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	await game.get_tree().create_timer(0.16).timeout
	var image: Image = game.get_viewport().get_texture().get_image()
	expect(image != null, name + " frame available")
	if image != null:
		if image.get_size() != Vector2i(1920, 1080):
			image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
		expect(image.save_png(output_dir.path_join(name + ".png")) == OK, name + " screenshot written")

func run(game) -> void:
	output_dir = ProjectSettings.globalize_path("res://../docs/achievement-icons-validation")
	DirAccess.make_dir_recursive_absolute(output_dir)
	expect(AchievementCatalog.ITEMS.size() == 30, "catalog contains exactly 30 achievements")
	var real_icon_count := 0
	for achievement: Dictionary in AchievementCatalog.ITEMS:
		var achievement_icon := AchievementCatalog.icon_path(str(achievement.id))
		if achievement_icon != AchievementCatalog.ICON_PLACEHOLDER and ResourceLoader.exists(achievement_icon):
			real_icon_count += 1
	expect(real_icon_count == 30, "all 30 achievements resolve dedicated icons")
	var icon_count := 0
	for card: Dictionary in game.sim.database.cards:
		icon_count += int(not GeneratedIconCatalog.card_path(card).is_empty())
	expect(icon_count == game.sim.database.cards.size(), "all 150 cards resolve an icon")
	expect(game.home_panel.FACILITIES.any(func(row: Dictionary) -> bool: return str(row.id) == "achievements"), "home contains an achievement wall facility")
	var squad: Array[String] = ["traveler"]
	game.sim.reset_stage("stage_01", squad, 7601)
	game.sim.state = "won"
	game.sim.base_hp = 12
	game.sim.elapsed = 180.0
	var unlocked: Array[String] = game.compendium.evaluate_achievements(game.sim, game.sim.database)
	expect("first_watch" in unlocked and "perfect_guard" in unlocked, "settlement unlocks eligible achievements")
	for id: String in ["first_watch", "perfect_guard", "hundred_slayer", "card_master", "damage_king", "five_crowns"]:
		game.compendium.unlocked_achievements[id] = {"unlocked_at":"QA"}
	game.hud.get_child(0).hide()
	game.compendium_panel.open("achievements")
	await capture(game, "01-compendium-achievement-wall")
	game.compendium_panel.close()
	game.home_facility_source = ""
	game.home_panel.open()
	game.home_panel.player_pos = Vector2(1540, 500)
	game.home_panel._update_camera()
	game.home_panel.map.queue_redraw()
	await capture(game, "02-home-achievement-wall")
	game.home_panel.close()
	var popup_ids: Array[String] = ["damage_king", "card_master"]
	game.achievement_popup.open(popup_ids)
	await capture(game, "03-achievement-unlock-popup")
	print("ACHIEVEMENT QA COMPLETE: %d checks, %d failures -> %s" % [checks, failures, output_dir])
	game.get_tree().quit(failures)
