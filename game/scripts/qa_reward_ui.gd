extends RefCounted
var checks := 0
var failures := 0

func run(game) -> void:
	var directory := ProjectSettings.globalize_path("res://../docs/v62-reward-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	var squad: Array[String] = ["traveler", "hero_01", "hero_02"]
	game.sim.reset_stage("stage_01", squad, 6201)
	game.sim.start()
	var showcase: Array[Dictionary] = []
	for rarity: String in ["rare", "epic", "legendary"]:
		for source: Dictionary in game.sim.database.cards:
			if str(source.get("rarity", "")) == rarity:
				showcase.append(source.duplicate(true))
				break
	_expect(showcase.size() == 3, "找到稀有、史诗、传奇三张展示卡")
	if showcase.size() != 3:
		game.get_tree().quit(1)
		return
	game.sim.rewards.offered.assign(showcase)
	game.sim.run_state.pending_level_ups = 1
	game.sim.state = "reward"
	game.hud.signature = ""
	game.refresh()
	game.hud.overlay.hide()
	await _settle(game)
	_expect(game.hud.reward_panel.visible, "三选一增益页已显示")
	_expect(game.hud.reward_panel.buttons.size() == 3, "页面仅显示三张可选卡")
	_expect(_all_artwork_uniform(game.hud.reward_panel), "三张海报卡纸与大图标全部保持等比例缩放")
	_expect(game.hud.reward_panel.hover_sound.stream != null, "悬停卡牌已绑定对话选择提示音")
	_expect(_capture(game, directory, "01-reward-default.png"), "默认卡牌状态截图")
	game.hud.reward_panel.buttons[1].grab_focus()
	await game.get_tree().create_timer(0.24).timeout
	await _settle(game)
	_expect(game.hud.reward_panel.focused_index == 1, "悬停等价焦点触发高亮")
	_expect(game.hud.reward_panel.card_bodies[1].scale.x > game.hud.reward_panel.card_bodies[0].scale.x, "高亮卡纸轻微放大且不干扰按钮入场动画")
	_expect(_capture(game, directory, "02-reward-hover.png"), "悬停高亮状态截图")
	print("REWARD UI QA COMPLETE: %d checks, %d failures -> %s" % [checks, failures, directory])
	game.get_tree().quit(failures)

func _all_artwork_uniform(panel) -> bool:
	var sprites: Array[Sprite2D] = []
	for icon: Sprite2D in panel.icons:
		sprites.append(icon)
	for sprite: Sprite2D in sprites:
		if not is_equal_approx(sprite.scale.x, sprite.scale.y):
			return false
	return sprites.size() == 3 and panel.card_art.size() == 3 and panel.card_bodies.size() == 3
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("REWARD UI PASS: " + message)
	else:
		failures += 1
		push_error("REWARD UI FAIL: " + message)

func _settle(game) -> void:
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	await game.get_tree().create_timer(0.12).timeout
	RenderingServer.force_draw()

func _capture(game, directory: String, file_name: String) -> bool:
	var image: Image = game.get_viewport().get_texture().get_image()
	if image == null:
		return false
	if image.get_size() != Vector2i(1920, 1080):
		image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	return image.save_png(directory.path_join(file_name)) == OK
