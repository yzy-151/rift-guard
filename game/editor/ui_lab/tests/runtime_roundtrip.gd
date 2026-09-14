extends SceneTree

const Transaction = preload("res://editor/ui_lab/write_transaction.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var source_layout := ResourceLoader.load("res://data/ui_layout_profile.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var source_skin := ResourceLoader.load("res://data/ui_skin_profile.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var layout_path := "user://ui_lab_success_layout.tres"
	var skin_path := "user://ui_lab_success_skin.tres"
	ResourceSaver.save(source_layout.duplicate(false), layout_path)
	ResourceSaver.save(source_skin.duplicate(false), skin_path)
	var layout := ResourceLoader.load(layout_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var skin := ResourceLoader.load(skin_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var rects: Array[Rect2] = layout.dialogue_choice_rects.duplicate()
	var changed_rect: Rect2 = rects[0]
	changed_rect.position.x += 20.0
	rects[0] = changed_rect
	layout.dialogue_choice_rects = rects
	skin.choice_frame_gray = skin.choice_frame_red
	var result := Transaction.save_pair(layout, skin, layout_path, skin_path, Transaction.file_hash(layout_path), Transaction.file_hash(skin_path))
	var saved_layout := ResourceLoader.load(layout_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var saved_skin := ResourceLoader.load(skin_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var rect_ok: bool = is_equal_approx(saved_layout.dialogue_choice_rects[0].position.x, source_layout.dialogue_choice_rects[0].position.x + 20.0)
	var skin_ok: bool = saved_skin.choice_frame_gray.resource_path == source_skin.choice_frame_red.resource_path
	var ok: bool = bool(result.get("ok", false)) and rect_ok and skin_ok
	print("ROUNDTRIP DEBUG result=%s rect=%.1f expected=%.1f skin=%s expected_skin=%s" % [result, saved_layout.dialogue_choice_rects[0].position.x, source_layout.dialogue_choice_rects[0].position.x + 20.0, saved_skin.choice_frame_gray.resource_path, source_skin.choice_frame_red.resource_path])
	print("ROUNDTRIP %s: transactional layout and skin write" % ("PASS" if ok else "FAIL"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(layout_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(skin_path))
	quit(0 if ok else 1)
