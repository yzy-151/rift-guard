extends SceneTree
const Main = preload("res://main.tscn")
const Scale = preload("res://scripts/battle_visual_scale.gd")
const Layout = preload("res://data/ui_layout_profile.tres")
var failures: Array[String] = []
var checks := 0
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func capture(game: Node, name: String) -> void:
	game.refresh()
	game.battle.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless" and not output.is_empty():
		await RenderingServer.frame_post_draw
		check(game.get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "capture " + name)

func clear_battle(game: Node) -> void:
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	game.sim.enemy_projectiles.clear()
	game.sim.enemy_hazards.clear()
	game.sim.projectiles.clear()
	game.sim.skill_effects.clear()
	game.sim.drain_events()
	game.battle.reset_transients()
	game.battle.effects.clear()
	game.battle.position = Vector2.ZERO
	game.battle.shake_trauma = 0

func run() -> void:
	var game = Main.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.set_process(false)
	game.set_physics_process(false)
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	var squad: Array[String] = ["traveler", "hero_04", "hero_08"]
	game.sim.reset_stage("stage_02", squad, 91003)
	game.sim.start()
	for hero: Dictionary in game.sim.heroes:
		hero.deployed = true
		hero.pos = Vector2(420 + int(hero.id) * 116, 390)
		hero.target = hero.pos
	clear_battle(game)
	for i in 5:
		var kinds := ["grunt", "shielded", "hilichurl_brute", "rift_bat", "originium_bug"]
		var enemy: Dictionary = game.sim.spawn_enemy(Vector2(715 + i * 102, 320 + (i % 2) * 142), kinds[i])
		enemy.special_pending = false
		enemy.attack_pending = false
	game.sim.drain_events()
	game.battle.advance(0.05)
	await capture(game, "01-battle-scale-hud")
	check(Layout.battle_status_rect.end.y <= 56, "top HUD ends by 56px")
	check(Layout.battle_right_shell_rect.position.y >= 616, "bottom HUD begins at 616px")
	check(Layout.battle_playfield_rect.size.y >= 550, "map receives at least 550px height")
	check(Scale.enemy_size("hilichurl_brute", 375) < 200, "large original atlas significantly reduced")
	check(Scale.enemy_size("boss_01", 285) > Scale.enemy_size("hilichurl_brute", 375), "boss hierarchy retained")
	for hero: Dictionary in game.sim.heroes:
		var rect: Rect2 = game.battle.hero_pick_rect(hero)
		check(rect.has_point(game.battle.world_to_screen(hero.pos)), "pick rectangle includes foot anchor")
		check(rect.has_point(game.battle.world_to_screen(hero.pos) - Vector2(0, 70)), "pick rectangle includes visible torso")
	for i in 32:
		var world := Vector2(640,360) + Vector2.from_angle(i * TAU / 32) * 140
		check(game.battle.screen_to_world(game.battle.world_to_screen(world)).is_equal_approx(world), "projection round trip " + str(i))
		check(is_equal_approx(game.battle.world_to_screen(world).distance_to(game.battle.world_to_screen(Vector2(640,360))), 140), "circular distance unchanged " + str(i))
	for kind in ["grunt", "runner", "ranged", "buffer", "hilichurl_brute", "rift_bat"]:
		game.battle.comic_vfx.reset()
		game.battle.comic_vfx.accept(game.battle, {"kind":"death", "pos":Vector2(700,400), "enemy_kind":kind})
		check(game.battle.comic_vfx.accents.is_empty(), kind + " death uses original down atlas only")
	var point := Vector2(790,390)
	for kind in ["barrage", "crossfire", "fireball_fall", "fireball_impact", "support_heal", "finale"]:
		game.battle.effects.clear()
		var batch: Array[Dictionary] = [{"kind":kind, "pos":point, "radius":112.0, "lane_y":390.0, "lane_half_width":58.0, "duration":0.72, "hero_ids":[0,1,2]}]
		game.battle.accept_events(batch)
		check(game.battle.effects.any(func(e: Dictionary) -> bool: return str(e.kind) == kind), kind + " actual support event retained")
		game.battle.advance(0.34)
		await capture(game, "02-support-" + kind)
	clear_battle(game)
	for boss in ["boss_01", "boss_02", "boss_03", "boss_galio"]:
		clear_battle(game)
		var enemy: Dictionary = game.sim.spawn_enemy(Vector2(920,390), boss)
		enemy.special_pending = true
		enemy.special_warning = 0.55
		enemy.special_warning_total = 1.8
		enemy.special_warning_radius = 100.0
		enemy.special_warning_positions = [Vector2(630,390)]
		enemy.special_move = {"boss_01":"rift_overhead", "boss_02":"slime_burst", "boss_03":"kindred_wolf", "boss_galio":"galio_durand"}[boss]
		game.sim.drain_events()
		game.battle.advance(0.1)
		await capture(game, "03-warning-" + boss)
		enemy.special_pending = false
		var event: Array[Dictionary] = [{"kind":enemy.special_move, "pos":Vector2(630,390), "points":[Vector2(630,390)], "radius":100.0, "source":enemy.pos, "phase":2}]
		game.battle.accept_events(event)
		game.battle.advance(0.20)
		await capture(game, "04-release-" + boss)
	clear_battle(game)
	game.selected_id = 1
	game.battle.selected_id = 1
	game.battle.skill_targeting = true
	game.battle.skill_preview_ultimate = true
	game.battle.skill_point = Vector2(810,390)
	await capture(game, "05-roxy-cross-preview")
	game.battle.skill_targeting = false
	for id in ["blood_gate", "frost_isles", "wind_cross"]:
		game.sim.select_endless_layout(id)
		game.sim.reset_stage("stage_endless", squad, 91003)
		game.sim.start()
		clear_battle(game)
		for hero: Dictionary in game.sim.heroes:
			hero.deployed = true
			hero.pos = game.sim._resolve_walkable_target(Vector2(1550 + int(hero.id) * 90,1100))
			hero.target = hero.pos
		game.battle.camera_center = Vector2(1640,1100)
		game.sim.combat_contract = {"metric":"zone_hold", "zone_pos":Vector2(1770,1100), "zone_radius":120, "name":"驻留试炼", "target":12, "progress":4, "completed":false}
		await capture(game, "06-endless-" + id)
		check(game.hud.wave_timeline_panel.visible, "endless forecast visible " + id)
		check(game.hud.map_name_label.text == str(game.sim.endless_forecast().layout_name), "layout name refreshes between equal-state runs " + id)
	print("V91 PRESENTATION QA: %d checks; %d failures" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	quit(0 if failures.is_empty() else 1)
