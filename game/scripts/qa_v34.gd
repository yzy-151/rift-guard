extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V34 PASS: " + message)
	else:
		failures += 1
		push_error("V34 FAIL: " + message)

func run(game) -> void:
	game.choose_mode("endless_survival")
	await game.get_tree().process_frame
	expect(game.sim.endless_mode and game.sim.state == "running", "endless mode enters playable state")
	expect(game.sim.heroes.size() >= 1 and game.sim.heroes.all(func(hero: Dictionary) -> bool: return bool(hero.get("deployed", false))), "endless party starts deployed")
	print("V34 CONFIG: loaded=" + str(game.content.loaded) + " path=" + str(game.content.path) + " errors=" + str(game.content.errors) + " row=" + str(game.content.ui.get("hero_card_1", {})))
	print("V34 HUD POS: " + str(game.hud.hero_buttons[0].position) + " / " + str(game.hud.hero_buttons[1].position))
	expect(game.hud.hero_buttons[0].position.x >= 1040.0 and game.hud.hero_buttons[1].position.y > game.hud.hero_buttons[0].position.y, "party HUD is arranged in the reserved right column")
	expect(game.hud.hero_portraits[0].texture != null, "party HUD uses a real character portrait")

	for character: Dictionary in game.sim.database.characters.values():
		expect(str(character.active_skill.get("targeting", "")) == "point", str(character.name) + " active skill uses circular point targeting")
		expect(float(character.ultimate.get("cooldown", 0.0)) >= 20.0, str(character.name) + " ultimate defines a cooldown")

	game.selected_id = 0
	var start_pos: Vector2 = game.sim.heroes[0].pos
	var move_key := InputEventKey.new()
	move_key.keycode = KEY_W
	move_key.pressed = true
	Input.parse_input_event(move_key)
	await game.get_tree().process_frame
	game._update_selected_hero_keyboard(0.08)
	game.sim.tick(0.12)
	move_key.pressed = false
	Input.parse_input_event(move_key)
	await game.get_tree().process_frame
	game._update_selected_hero_keyboard(0.08)
	expect(game.sim.heroes[0].pos.y < start_pos.y, "selected hero moves with WASD")
	game.sim.heroes[0].skill_cooldown = 4.2
	game.hud.signature = ""
	game.refresh()
	expect(game.hud.skill_cd_label.text == "4.2s", "Q cell renders a numeric cooldown countdown")
	game.sim.heroes[0].skill_cooldown = 0.0
	game.hud.signature = ""
	game.refresh()
	game.toggle_skill_aiming()
	expect(game.skill_aiming and game.battle.skill_targeting and not game.battle.skill_preview_ultimate, "Q enters circular placement preview")
	game.set_skill_aiming(false)
	game.sim.heroes[0].energy = game.sim.heroes[0].max_energy
	game.activate_selected_ultimate()
	expect(game.ultimate_aiming and game.battle.skill_targeting and game.battle.skill_preview_ultimate and int(game.sim.heroes[0].ultimate_uses) == 0, "E previews range before committing")
	var view := Rect2(Vector2(700, 420), Vector2(1280, 720))
	game.sim.set_active_view_rect(view)
	var target := Vector2(-500, -500)
	expect(game.sim.activate_hero_ultimate(0, target), "ready ultimate commits at an aimed point")
	var impact: Dictionary = game.sim.pending_impacts[-1]
	expect(view.grow(-24.0).has_point(impact.target_pos), "endless ultimate target is clamped to the visible screen")
	game.set_ultimate_aiming(false)
	game.hud.signature = ""
	game.refresh()
	var rendered_ultimate_cd: float = game.hud.ultimate_cd_label.text.to_float()
	expect(rendered_ultimate_cd > 0.0, "E cell renders the active ultimate cooldown countdown")
	var cooldown_before := float(game.sim.heroes[0].ultimate_cooldown)
	game.sim.tick(0.25)
	expect(cooldown_before > 0.0 and float(game.sim.heroes[0].ultimate_cooldown) < cooldown_before, "ultimate cooldown starts and ticks down")

	game.sim.enemies.clear()
	var inside: Dictionary = game.sim.spawn_enemy(view.get_center(), "grunt")
	var outside: Dictionary = game.sim.spawn_enemy(view.end + Vector2(160, 120), "grunt")
	var inside_hp := float(inside.hp)
	var outside_hp := float(outside.hp)
	game.sim._damage_area(view.get_center(), 5000.0, 10.0, "", 0)
	expect(float(inside.hp) < inside_hp and is_equal_approx(float(outside.hp), outside_hp), "endless skills damage visible enemies only")

	game.set_ultimate_aiming(false)
	expect(not game.skill_aiming and not game.ultimate_aiming and not game.battle.skill_targeting, "right-click cancel state clears both previews")
	print("V34 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await game.get_tree().create_timer(0.08).timeout
	game.get_tree().quit(failures)
