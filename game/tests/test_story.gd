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
	var valid: bool = story.stories.size() == 13
	var count := 0
	for scene_key: String in story.stories:
		valid = valid and story.begin(scene_key)
		for line: Variant in story.lines:
			valid = valid and line_valid(line)
			count += 1
		while story.active:
			if story.has_choices():
				valid = valid and story.choose(0)
			else:
				story.advance()
	story.reset()
	valid = valid and story.begin("mode1_opening")
	story.advance()
	story.advance()
	valid = valid and story.has_choices() and story.current().choices.size() == 2
	valid = valid and story.choose(1)
	valid = valid and story.choice_history.size() == 1 and story.choice_history[0].result == "hidden_character"
	valid = valid and "白露" in story.current().text
	story.reset()
	valid = valid and story.begin("mode1_won")
	valid = valid and story.has_choices() and story.current().choices.size() == 2
	valid = valid and str(story.current().choices[1].get("effect", {}).get("type", "")) == "inherit_endless"
	story.reset()
	valid = valid and story.seen.is_empty() and story.history.is_empty() and story.choice_history.is_empty()
	print("V16 STORY VALIDATION: %d source lines; %s" % [count, "PASS" if valid else "FAIL"])
	quit(0 if valid else 1)
