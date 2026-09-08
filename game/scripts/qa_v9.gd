extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V9 PASS: " + message)
	else:
		failures += 1
		push_error("V9 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v9-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	game.sim.state = "running"
	game.hud.overlay.hide()
	var boss: Dictionary = game.sim.spawn_enemy(Vector2(940, 360), "boss_01")
	boss.hp = boss.max_hp * 0.64
	boss.shield = boss.max_shield * 0.38
	game.hud.signature = ""
	game.hud.refresh(game.sim, 0)
	expect(game.hud.boss_panel.visible, "boss health panel appears while a boss is alive")
	expect(absf(game.hud.boss_hp_bar.value - float(boss.hp)) < 0.1, "boss health bar follows live health")
	expect("护盾" in game.hud.boss_hp_label.text, "boss shield is displayed separately")
	await capture(game, "01-boss-health-bar")
	game.hud.announce_boss(str(boss.name))
	await game.get_tree().create_timer(0.20).timeout
	expect(game.hud.boss_alert.visible and "裂隙统领" in game.hud.boss_alert.text, "boss arrival warning uses the localized boss name")
	await capture(game, "02-boss-arrival-warning")
	await game.get_tree().create_timer(1.10).timeout
	game.sim.enemies.clear()
	game.sim.state = "won"
	game.sim.kills = 286
	game.sim.base_hp = 91
	game.sim.best_streak = 34
	game.sim.reactions = 57
	game.hud.signature = ""
	game.hud.refresh(game.sim, 0)
	expect(game.hud.modal_copy.text.begins_with("评级 S"), "victory screen calculates and shows an S rank")
	expect("F4" in game.hud.modal_copy.text, "victory screen points to mission selection")
	await capture(game, "03-ranked-victory")
	print("V9 UI TESTS: %d checks; %d failures" % [checks, failures])
	var tree = game.get_tree()
	game.queue_free()
	await tree.process_frame
	tree.quit(0 if failures == 0 else 1)
