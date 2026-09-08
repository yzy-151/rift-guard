extends SceneTree

const Database = preload("res://scripts/content/game_database.gd")

func _initialize() -> void:
	var db = Database.new()
	assert(db.errors.is_empty(), str(db.errors))
	assert(db.characters.size() == 8)
	assert(db.cards.size() >= 150)
	assert(db.stages.has("stage_01"))
	assert(db.stages.has("stage_03"))
	assert(db.modes.has("rift_watch"))
	assert(db.modes["rift_watch"].starting_stage_id == "stage_01")
	assert(db.characters["traveler"].element == "none")
	assert(db.characters.values().all(func(character): return db.assets.has(character.asset_key)))
	print("GAME DATABASE PASSED")
	quit()
