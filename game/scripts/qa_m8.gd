extends RefCounted

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("M8 PASS: " if ok else "M8 FAIL: ") + message)

func capture(main, name: String) -> void:
	await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: int = main.get_viewport().get_texture().get_image().save_png("user://m8-" + name + ".png")
	check(result == OK, "screenshot " + name)

func run(main) -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var rig = main.battle.furina_rig
	check(rig != null and rig.skeleton is Skeleton2D, "Furina uses Skeleton2D")
	check(rig.rest.size() == 9, "nine Bone2D nodes registered with rest poses")
	check(rig.sprites.size() == 11, "eleven separated texture parts attached to bones")
	main.sim.reset(808)
	main.story.reset()
	main.story.seen.opening = true
	main.sim.start()
	main.selected_id = 2
	main.refresh()
	main.battle.advance(0.5)
	check(rig.visible and rig.position.distance_to(preload("res://scripts/stage_projection.gd").project(main.sim.heroes[2].pos) + Vector2(0, 8)) < 0.01, "rig follows projected Furina position")
	main.sim.command_move(2, main.sim.heroes[2].pos + Vector2(80, 0))
	main._physics_process(1.0 / 60.0)
	main.battle.advance(0.07)
	check(not is_equal_approx(rig.left_leg_bone.rotation, rig.right_leg_bone.rotation), "movement drives opposing leg bones")
	main.sim.heroes[2].target = main.sim.heroes[2].pos
	main.sim.heroes[2].moving = false
	main.battle.shot_flashes[2] = 0.12
	main.battle.advance(0.01)
	check(absf(rig.right_arm_bone.rotation) > 0.2, "attack drives right arm bone")
	await capture(main, "furina-rig-range")
	print("M8 RIG TESTS: %d checks; %d failures" % [checks, failures])
	main.get_tree().quit(0 if failures == 0 else 1)
