extends RefCounted

const SequenceLibrary = preload("res://scripts/character_sequence_library.gd")
const AnimationMachine = preload("res://scripts/animation_state_machine.gd")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V49 PASS: " + message)
	else:
		failures += 1
		push_error("V49 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.hud.get_child(0).show()
	game.refresh()
	await game.get_tree().create_timer(0.25).timeout
	game.battle.advance(0.0)
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v49-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		var error := image.save_png(directory.path_join(name + ".png"))
		expect(error == OK, "capture written: " + name)

func prepare_squad(game, squad: Array[String]) -> void:
	game.sim.reset_stage("stage_01", squad, 4901)
	game.battle.unit_visual_actors.clear()
	game.battle.hero_attack_visuals.clear()
	game.battle.hero_down_visuals.clear()
	var positions := [Vector2(370, 280), Vector2(520, 360), Vector2(690, 440)]
	for i in game.sim.heroes.size():
		var hero: Dictionary = game.sim.heroes[i]
		hero.deployed = true
		hero.pos = positions[i]
		hero.target = positions[i]
		hero.moving = false
	game.sim.state = "running"
	game.battle._build_stage_tile_cache("stage_01")

func run(game) -> void:
	var library = SequenceLibrary.new()
	var expected := {
		"hero_01": {"idle":31,"run":35,"attack":42,"down":59},
		"hero_02": {"idle":25,"run":29,"attack":43,"down":24},
		"traveler": {"idle":25,"run":14,"attack":37,"down":25},
		"hero_06": {"idle":17,"run":15,"attack":48,"down":45},
	}
	expect(library.load_errors.is_empty(), "sequence manifest loads without errors")
	for character_id: String in expected:
		expect(library.has_character(character_id), character_id + " owns a sequence profile")
		for state: String in expected[character_id]:
			var count := int(expected[character_id][state])
			expect(library.frame_count(character_id, state) == count, "%s %s keeps every source frame" % [character_id, state])
			expect(library.texture(character_id, state) != null, "%s %s atlas loads" % [character_id, state])
			expect(library.frame_at_time(character_id, state, 999.0) == (999 * 24) % count if state != "down" else count - 1, "%s %s loop/hold behavior is correct" % [character_id, state])
	expect(game.sim.database.characters.has("hero_01") and str(game.sim.database.characters.hero_01.name) == "哥伦比亚", "missing girl slot is restored as hero_01")
	expect(game.sim.database.animation_profiles.size() == game.sim.database.characters.size(), "animation profiles match the thirteen-character roster")
	expect(game.compendium.unlocked_characters.has("hero_01"), "girl is visible to existing and new saves")
	expect(game.squad_panel.buttons.size() == 13 and game.squad_panel.grid_scroll != null, "formation UI scrolls across all thirteen character cards")
	for character_id: String in expected:
		var asset_key := "character." + character_id
		var asset: Dictionary = game.sim.database.assets.get(asset_key, {})
		expect(str(asset.get("sequence_profile", "")) == character_id, character_id + " asset manifest binds its sequence profile")
		expect(int(game.squad_panel.previews[character_id].atlas_frames) == int(expected[character_id].idle), character_id + " formation card plays the real breath cycle")
	var machine = AnimationMachine.new()
	machine.setup(game.sim.database.animation_profiles.hero_06)
	machine.play("down", -1.0)
	machine.tick(99.0)
	expect(machine.state == "down" and machine.frame_index() == 44, "death animation holds Amiya's final frame")

	var first_squad: Array[String] = ["traveler", "hero_01", "hero_02"]
	prepare_squad(game, first_squad)
	game.sim.heroes[0].animation_state = "idle"
	game.sim.heroes[1].moving = true
	game.sim.heroes[1].target = game.sim.heroes[1].pos + Vector2(180, 0)
	game.sim.heroes[1].animation_state = "run"
	game.sim.heroes[2].animation_state = "attack"
	game.sim.heroes[2].status_timer = 2.0
	game.battle.hero_attack_visuals[2] = {"elapsed":0.36,"duration":1.0}
	game.battle.advance(0.12)
	await capture(game, "traveler-girl-sylphiette-cycles")

	var second_squad: Array[String] = ["traveler", "hero_02", "hero_06"]
	prepare_squad(game, second_squad)
	game.sim.heroes[0].moving = true
	game.sim.heroes[0].target = game.sim.heroes[0].pos + Vector2(-180, 0)
	game.sim.heroes[0].facing = -1.0
	game.sim.heroes[1].animation_state = "attack"
	game.sim.heroes[1].status_timer = 2.0
	game.battle.hero_attack_visuals[1] = {"elapsed":0.72,"duration":1.0}
	game.sim.heroes[2].hp = 0.0
	game.sim.heroes[2].animation_state = "down"
	game.sim.heroes[2].status_timer = 999999.0
	game.battle.hero_down_visuals[2] = 99.0
	game.battle.advance(0.12)
	await capture(game, "traveler-sylphiette-amiya-death-hold")
	print("V49 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)