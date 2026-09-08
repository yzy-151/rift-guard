extends SceneTree
func _initialize() -> void:
	var story = preload("res://scripts/dialogue_director.gd").new()
	var valid: bool = story.stories.size() == 13
	var count: int = 0
	var scene_keys := ["mode1_opening", "mode1_won", "mode1_stage2_opening", "mode1_stage3_opening", "mode1_final_won", "mode1_lost", "opening", "node1", "node2", "node3", "node4", "won", "lost"]
	for key in scene_keys:
		valid = valid and story.begin(key)
		valid = valid and not story.begin(key)
		for row in story.lines:
			valid = valid and row.size() == 3 and not row[2].is_empty()
			valid = valid and FileAccess.file_exists("res://assets/portraits/" + row[0] + ".png")
			count += 1
		while story.active:
			story.advance()
		valid = valid and not story.begin(key)
	valid = valid and story.history.size() == count
	story.reset()
	valid = valid and story.seen.is_empty() and story.history.is_empty() and not story.active
	valid = valid and not story.begin("missing")
	valid = valid and story.begin("opening")
	story.skip()
	valid = valid and not story.active and story.history.size() == 4
	for attempt in 3:
		story.reset()
		for scene_key in scene_keys:
			valid = valid and story.begin(scene_key)
			story.skip()
		valid = valid and story.history.size() == count
	print("M4 STORY VALIDATION: %d lines; %s" % [count, "PASS" if valid else "FAIL"])
	quit(0 if valid else 1)
