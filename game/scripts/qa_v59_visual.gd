extends RefCounted
## V59 视觉验收：无尽模式石墙 / 可破坏大门素材、剧情选项框素材。

var checks: int = 0
var failures: int = 0

func run(game) -> void:
	var directory := ProjectSettings.globalize_path("res://../docs/v59-validation")
	DirAccess.make_dir_recursive_absolute(directory)

	# 1) 无尽竞技场：横向石墙、纵向石墙、竖门（铁箱）
	var squad: Array[String] = ["traveler", "hero_01", "hero_02"]
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	game.sim.reset_stage("stage_endless", squad, 5901)
	game.sim.start()
	_place_party(game, Vector2(700, 740))
	game.battle.advance(0.10)
	_place_party(game, Vector2(700, 740))
	_gameplay_frame(game, Vector2(760, 620))
	await _settle(game)
	_expect(_capture(game, directory, "endless-stone-wall.png"), "无尽竞技场石墙与大门截图")

	# 2) 纵墙特写：只露顶面的叠放效果 + 竖门铁箱
	_gameplay_frame(game, Vector2(660, 720))
	await _settle(game)
	_expect(_capture(game, directory, "endless-vertical-wall.png"), "纵向石墙叠放截图")

	# 3) 横墙 + 横门（锁箱）特写
	_gameplay_frame(game, Vector2(1180, 470))
	await _settle(game)
	_expect(_capture(game, directory, "endless-horizontal-gate.png"), "横向石墙与锁箱大门截图")

	# 4) 战斗HUD与加长Boss预警
	_gameplay_frame(game, Vector2(760, 620))
	await _settle(game)
	_expect(_capture(game, directory, "battle-hud-redesign.png"), "顶部、计数徽标与底部指令台截图")
	game.hud.announce_boss("裂隙审判者")
	await game.get_tree().create_timer(0.52).timeout
	RenderingServer.force_draw()
	_expect(game.hud.boss_alert.visible, "Boss预警保持可见")
	_expect(_capture(game, directory, "boss-warning-long.png"), "加长Boss预警截图")
	await game.get_tree().create_timer(1.80).timeout

	# 普通模式小型怪物计数徽标
	game.sim.reset_stage("stage_01", squad, 5902)
	game.sim.start()
	game.battle.advance(0.10)
	game.refresh()
	await _settle(game)
	_expect(game.hud.wave_timeline_panel.visible, "普通模式怪物计数徽标可见")
	_expect(_capture(game, directory, "campaign-compact-counter.png"), "普通模式紧凑HUD截图")

	# 5) 剧情页选项框：未选中为白色描边，选中为暗红描边
	game.dialogue.show()
	_expect(game.begin_dialogue("mode1_opening"), "剧情验证场景已打开")
	await game.get_tree().create_timer(0.24).timeout
	game.dialogue.advance()
	game.dialogue.advance()
	for frame in 90:
		await game.get_tree().process_frame
		if not game.dialogue.transition_texture.visible:
			break
	var visible_choices: Array = game.dialogue.choice_buttons.filter(func(item: Button) -> bool: return item.visible)
	_expect(visible_choices.size() == 2, "剧情页显示两个选项框")
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	await game.get_tree().create_timer(0.12).timeout
	RenderingServer.force_draw()
	_expect(_capture(game, directory, "dialogue-choice-frames.png"), "剧情选项框截图")
	game.dialogue.choose_option(1)
	await game.get_tree().create_timer(1.12).timeout
	RenderingServer.force_draw()
	_expect(game.dialogue.death_overlay.visible, "错误选项死亡动画已显示")
	_expect(game.dialogue.death_reason_label.text.contains("死亡原因"), "死亡原因文字已显示")
	_expect(_capture(game, directory, "dialogue-wrong-choice-death.png"), "错误选项死亡动画截图")
	await game.get_tree().create_timer(1.55).timeout
	_expect(not game.dialogue.death_overlay.visible, "死亡动画结束后已返回选项")
	_expect(game.dialogue.choice_buttons[0].visible and game.dialogue.choice_buttons[1].visible, "两个选项重新可选")

	# 6) 选角色界面
	game.dialogue.hide()
	game.hud.get_child(0).show()
	var squad_now: Array[String] = ["traveler", "hero_01"]
	game.squad_panel.open("stage_01", squad_now, [])
	await _settle(game)
	_expect(_capture(game, directory, "squad-panel.png"), "选角色界面截图")

	print("V59 VISUAL QA COMPLETE: %d checks, %d failures -> %s" % [checks, failures, directory])
	game.get_tree().quit(failures)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V59 FAIL: " + message)
	else:
		print("V59 PASS: " + message)

func _place_party(game, origin: Vector2) -> void:
	for index in game.sim.heroes.size():
		var hero: Dictionary = game.sim.heroes[index]
		hero.pos = origin + Vector2(-70 + index * 55, index * 45)
		hero.target = hero.pos
		hero.moving = false
		hero.deployed = true

## 先推进一帧再定机位：advance() 会把相机拉回英雄，测试里必须最后设 camera_center。
func _gameplay_frame(game, focus: Vector2) -> void:
	game.refresh()
	game.battle.advance(0.0)
	game.battle.camera_center = focus
	game.sim.set_active_view_rect(Rect2(focus - Vector2(624, 245), Vector2(1248, 490)))

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


