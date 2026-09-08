extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("V10 PASS: " if ok else "V10 FAIL: ") + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v10-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	game.sim.state = "running"
	game.hud.overlay.hide()
	var boss: Dictionary = game.sim.spawn_enemy(Vector2(900, 360), "boss_02")
	boss.hp = boss.max_hp * 0.34
	boss.shield = 0.0
	game.sim._update_boss_phase(boss)
	game.hud.signature = ""
	game.hud.refresh(game.sim, 0)
	expect(boss.boss_phase == 3, "boss reaches final phase")
	expect("PHASE III" in game.hud.boss_name_label.text, "boss bar exposes the active phase")
	game.hud.announce_boss_phase(str(boss.name), 3)
	await game.get_tree().create_timer(0.20).timeout
	expect("F I N A L" in game.hud.boss_alert.text and game.hud.boss_alert.visible, "final phase warning is visible")
	await capture(game, "01-final-phase-warning")
	print("V10 UI TESTS: %d checks; %d failures" % [checks, failures])
	var tree = game.get_tree()
	game.queue_free()
	await tree.process_frame
	tree.quit(0 if failures == 0 else 1)
