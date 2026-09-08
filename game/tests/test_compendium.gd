extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("COMPENDIUM PASS: " if ok else "COMPENDIUM FAIL: ") + message)

func _initialize() -> void:
	var path := "user://compendium-test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var State = preload("res://scripts/compendium_state.gd")
	var state = State.new(path)
	check(state.unlocked_characters.has("traveler"), "Traveler is unlocked by default")
	state.discovered_cards["card_a"] = true
	state.encountered_enemies["runner"] = true
	state.clear_stage("stage_01", ["hero_02"])
	state.record_result("stage_01", 120, 72, 18)
	state.record_result("stage_01", 110, 91, 12)
	var restored = State.new(path)
	check(restored.discovered_cards.has("card_a"), "card discovery persists")
	check(restored.encountered_enemies.has("runner"), "enemy encounter persists")
	check(restored.unlocked_characters.has("hero_02") and restored.cleared_stages.has("stage_01"), "stage clear unlock persists")
	check(restored.stage_records.stage_01.best_kills == 120 and restored.stage_records.stage_01.best_base_hp == 91 and restored.stage_records.stage_01.best_streak == 18, "best stage records merge and persist")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("COMPENDIUM TESTS: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
