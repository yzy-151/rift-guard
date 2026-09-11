extends RefCounted

const TeamResonance = preload("res://scripts/team_resonance.gd")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V32 PASS: " + message)
	else:
		failures += 1
		push_error("V32 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await game.get_tree().create_timer(0.25).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory: String = ProjectSettings.globalize_path("res://../docs/v32-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func _has(rows: Array[Dictionary], id: String) -> bool:
	return rows.any(func(row: Dictionary) -> bool: return str(row.get("id", "")) == id)

func run(game) -> void:
	game.mode_select_panel.close()
	var database = game.sim.database
	var state = game.sim.run_state
	state.reset_run_meta()
	expect(database.team_resonances.size() >= 12, "database loads at least twelve team resonances")
	expect(database.errors.filter(func(error: String) -> bool: return error.contains("resonance")).is_empty(), "resonance content passes database validation")

	var collision_team: Array[Dictionary] = [
		{"character_id":"hero_02","element":"anemo","secondary_element":"","role":"风系支援"},
		{"character_id":"hero_05","element":"anemo","secondary_element":"","role":"风系支援"},
		{"character_id":"traveler","element":"electro","secondary_element":"hydro","role":"无元素剑士"}
	]
	var exclusive: Array[Dictionary] = TeamResonance.resolve(database.team_resonances, state, collision_team)
	expect(_has(exclusive, "anemo_chorus") and not _has(exclusive, "prismatic_triad"), "same-element and prismatic compositions obey exclusive priority")
	expect(_has(exclusive, "support_network"), "role composition can activate independently")

	var signal_team: Array[Dictionary] = [
		{"character_id":"traveler","element":"","secondary_element":"","role":"无元素剑士"},
		{"character_id":"hero_12","element":"electro","secondary_element":"","role":"以太骇入"}
	]
	var before_bond: Array[Dictionary] = TeamResonance.resolve(database.team_resonances, state, signal_team)
	expect(_has(before_bond, "new_eridu_link") and not _has(before_bond, "hidden_signal_bond"), "basic character bond activates before relationship threshold")
	state.add_relationship("hero_12", 2)
	var after_bond: Array[Dictionary] = TeamResonance.resolve(database.team_resonances, state, signal_team)
	expect(_has(after_bond, "hidden_signal_bond"), "relationship threshold unlocks hidden resonance")

	state.reset_run_meta()
	var star_team: Array[String] = ["traveler", "hero_03"]
	state.set_squad(star_team)
	game.sim.reset_stage("stage_02", state.squad, 3201)
	expect(state.active_resonances.has("star_and_tide"), "stage reset recomputes current squad resonances")
	expect(float(game.sim.heroes[0].damage) > float(game.sim.heroes[0].base_damage), "resonance changes real combat attack value")
	expect(game.sim.heroes.all(func(hero: Dictionary) -> bool: return float(hero.energy) >= 12.0), "resonance applies starting energy to every hero")

	var winter_team: Array[String] = ["hero_07", "hero_08", "hero_11"]
	state.set_squad(winter_team)
	game.sim.reset_stage("stage_03", state.squad, 3202)
	expect(state.active_resonances.has("cryo_oath") and game.sim.crystal_shield >= 45.0, "cryo composition grants its combat shield")
	expect(game.sim.heroes[0].crit_chance >= 0.14, "resonance critical chance reaches hero stats")

	star_team = ["traveler", "hero_03"]
	state.set_squad(star_team)
	game.sim.reset_stage("stage_02", state.squad, 3203)
	game.sim.state = "paused"
	game.hud.signature = ""
	game.hud.refresh(game.sim, 0)
	expect(game.hud.status_label.text.contains("共鸣") and game.hud.pause_status_label.text.contains("星海巡礼"), "combat HUD and pause center expose active resonance")
	var exported: Dictionary = game.sim.export_build_record()
	expect(exported.get("active_resonances", []).has("star_and_tide"), "final build report records active resonances")
	await capture(game, "01-team-resonance-pause")
	print("V32 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)