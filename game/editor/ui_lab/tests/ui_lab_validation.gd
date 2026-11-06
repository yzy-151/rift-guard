extends SceneTree

const Adapter = preload("res://editor/ui_lab/profile_adapter.gd")
const Validator = preload("res://editor/ui_lab/profile_validator.gd")
const Transaction = preload("res://editor/ui_lab/write_transaction.gd")
const WorkspaceScene = preload("res://editor/ui_lab/ui_lab_workspace.tscn")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("UI LAB PASS: " + message)
	else:
		failures += 1
		push_error("UI LAB FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var layout := ResourceLoader.load("res://data/ui_layout_profile.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var skin := ResourceLoader.load("res://data/ui_skin_profile.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(layout != null and skin != null, "profiles load")
	check(Adapter.records(layout, "Dialogue").size() >= 8, "dialogue layout fields reflect automatically")
	check(Adapter.records(layout, "Campaign Battle").size() >= 10, "campaign battle layout fields reflect automatically")
	check(Adapter.records(layout, "Endless Battle").size() >= 10, "endless battle layout fields reflect automatically")
	check(Adapter.records(layout, "Squad").size() >= 6, "squad layout fields reflect automatically")
	check(Adapter.records(layout, "Reward").size() >= 8, "reward layout fields reflect automatically")
	check(Adapter.records(layout, "Settings").size() >= 8, "settings layout fields reflect automatically")
	check(Adapter.page_names().size() >= 9, "all requested pages are listed")
	check(Adapter.records(skin, "Mode").size() >= 3, "mode skin fields reflect automatically")
	check(Validator.validate(layout, "Layout").is_empty(), "production layout validates")
	check(Validator.validate(skin, "Skin").is_empty(), "production skin validates")
	check(skin.mode_portrait != null, "production menu character binding survives a fresh load")
	var invalid := layout.duplicate(true)
	invalid.dialogue_body_rect = Rect2(0, 0, -10, 20)
	check(not Validator.validate(invalid, "Invalid").is_empty(), "negative rect is rejected")
	check(not Validator.validate_expected_fields(layout, PackedStringArray(["missing_ui_field"]), "Layout").is_empty(), "missing field is rejected")
	var fixture_layout_path := "user://ui_lab_layout_fixture.tres"
	var fixture_skin_path := "user://ui_lab_skin_fixture.tres"
	ResourceSaver.save(layout.duplicate(true), fixture_layout_path)
	ResourceSaver.save(skin.duplicate(true), fixture_skin_path)
	var stale_layout_hash := Transaction.file_hash(fixture_layout_path)
	var fixture_skin_hash := Transaction.file_hash(fixture_skin_path)
	var file := FileAccess.open(fixture_layout_path, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string("\n")
	file.close()
	var stale_result := Transaction.save_pair(layout.duplicate(true), skin.duplicate(true), fixture_layout_path, fixture_skin_path, stale_layout_hash, fixture_skin_hash)
	check(not bool(stale_result.get("ok", false)) and str(stale_result.get("message", "")).contains("外部修改"), "stale hash blocks overwrite")
	var workspace := WorkspaceScene.instantiate()
	root.add_child(workspace)
	await process_frame
	var rebuilt: Dictionary = workspace.rebuild("Dialogue")
	check(bool(rebuilt.get("ok", false)) and int(rebuilt.get("layout_count", 0)) >= 8, "workspace rebuilds reflected dialogue page")
	check(workspace.field_rows().size() >= 8, "workspace exposes field names and values")
	workspace.release_lock()
	workspace.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_layout_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_skin_path))
	print("UI LAB COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(failures)
