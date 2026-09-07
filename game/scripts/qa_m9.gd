extends RefCounted

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("M9 PASS: " if ok else "M9 FAIL: ") + message)

func capture(main, name: String) -> void:
	await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: int = main.get_viewport().get_texture().get_image().save_png("user://m9-" + name + ".png")
	check(result == OK, "screenshot " + name)

func run(main) -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var actor = main.battle.furina_actor
	check(actor != null and actor.sprite is AnimatedSprite2D, "Furina uses AnimatedSprite2D")
	var expected := {"idle": 8, "move": 8, "attack": 16, "hurt": 4, "down": 8}
	for animation in expected:
		check(actor.sprite.sprite_frames.has_animation(animation), animation + " animation exists")
		check(actor.sprite.sprite_frames.get_frame_count(animation) == expected[animation], animation + " frame count")
	check(actor.sprite.sprite_frames.get_frame_texture("attack", 0) != null, "attack first frame texture")
	check(actor.sprite.sprite_frames.get_frame_texture("attack", 15) != null, "attack last frame texture")
	check(is_equal_approx(actor.sprite.sprite_frames.get_animation_speed("attack"), 8.0), "attack plays at 8 FPS")
	check(actor.sprite.sprite_frames.get_animation_loop("attack"), "attack is a 2-second loop")
	main.sim.reset(909)
	main.story.reset()
	main.story.seen.opening = true
	main.sim.start()
	main.selected_id = 2
	main.refresh()
	main.battle.advance(0.1)
	check(actor.current_state == "idle", "idle state")
	await capture(main, "furina-idle-range")
	main.sim.command_move(2, main.sim.heroes[2].pos + Vector2(80, 0))
	main._physics_process(1.0 / 60.0)
	main.battle.advance(0.1)
	check(actor.current_state == "move", "move state")
	main.sim.heroes[2].target = main.sim.heroes[2].pos
	main.sim.heroes[2].moving = false
	main.battle.shot_flashes[2] = 0.12
	main.battle.advance(0.01)
	check(actor.current_state == "attack", "attack state")
	actor.sprite.pause()
	actor.sprite.frame = 7
	await capture(main, "furina-attack-16-impact")
	main.battle.shot_flashes[2] = 0.0
	actor.attack_hold = 0.0
	main.sim.heroes[2].flash = 0.1
	main.battle.advance(0.01)
	check(actor.current_state == "hurt", "hurt state")
	main.sim.heroes[2].hp = 0.0
	main.battle.advance(0.01)
	check(actor.current_state == "down", "down state")
	print("M9 FRAME TESTS: %d checks; %d failures" % [checks, failures])
	main.get_tree().quit(0 if failures == 0 else 1)
