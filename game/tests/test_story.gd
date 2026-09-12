extends SceneTree

func line_valid(line: Variant) -> bool:
	if line is Array:
		return line.size() == 3 and not str(line[2]).is_empty()
	if not line is Dictionary:
		return false
	if str(line.get("speaker", "")).is_empty() or str(line.get("text", "")).is_empty():
		return false
	var choices: Array = line.get("choices", [])
	if choices.is_empty():
		return true
	if choices.size() != 2:
		return false
	for choice: Dictionary in choices:
		if str(choice.get("text", "")).is_empty() or str(choice.get("response", "")).is_empty():
			return false
	return true

func _initialize() -> void:
	var Story = preload("res://scripts/dialogue_director.gd")
	var story = Story.new()
	var required_scenes := ["mode1_opening", "mode1_won", "mode1_lost", "mode1_final_won", "branch_sylphiette"]
	var valid: bool = required_scenes.all(func(id: String) -> bool: return story.stories.has(id))
	var count := 0
	for scene_key: String in story.stories:
		valid = story.begin(scene_key) and valid
		for line: Variant in story.lines:
			valid = valid and line_valid(line)
			count += 1
		while story.active:
			if story.has_choices():
				valid = story.choose(0) and valid
			else:
				story.advance()
	story.reset()
	valid = story.begin("mode1_opening") and valid
	story.advance()
	story.advance()
	valid = valid and story.has_choices() and story.current().choices.size() == 2
	valid = valid and story.choose(1)
	valid = valid and story.choice_history.size() == 1 and story.choice_history[0].result == "hidden_character"
	valid = valid and "白露" in story.current().text
	story.reset()
	valid = story.begin("mode1_won") and valid
	valid = valid and story.has_choices() and story.current().choices.size() == 2
	valid = valid and str(story.current().choices[1].get("effect", {}).get("type", "")) == "inherit_endless"
	story.reset()
	valid = valid and story.seen.is_empty() and story.history.is_empty() and story.choice_history.is_empty()
	print("STORY VALIDATION: %d source lines; %s" % [count, "PASS" if valid else "FAIL"])
	quit(0 if valid else 1)
