extends SceneTree

const Transaction = preload("res://editor/ui_lab/write_transaction.gd")
const LAYOUT_PATH := "res://data/ui_layout_profile.tres"
const SKIN_PATH := "res://data/ui_skin_profile.tres"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var layout := ResourceLoader.load(LAYOUT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE).duplicate(false)
	var skin := ResourceLoader.load(SKIN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE).duplicate(false)
	var rects: Array[Rect2] = layout.dialogue_choice_rects.duplicate()
	var changed_rect: Rect2 = rects[0]
	changed_rect.position.x += 20.0
	rects[0] = changed_rect
	layout.dialogue_choice_rects = rects
	skin.choice_frame_gray = skin.choice_frame_red
	var result := Transaction.save_pair(layout, skin, LAYOUT_PATH, SKIN_PATH, Transaction.file_hash(LAYOUT_PATH), Transaction.file_hash(SKIN_PATH))
	print("MUTATE: " + str(result.get("message", "")))
	quit(0 if bool(result.get("ok", false)) else 1)
