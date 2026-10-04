extends SceneTree
const Exploration = preload("res://scripts/home_exploration.gd")
const Regions = preload("res://scripts/home_regions.gd")
const Story = preload("res://scripts/dialogue_director.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func _initialize() -> void:
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	if not output.is_absolute_path(): printerr("Provide absolute --qa-output"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var path := output.path_join("home-%d.json" % OS.get_process_id())
	var progress = Exploration.new(path)
	check(progress.region == "base", "fresh game starts in original base")
	check(not progress.enter("missing"), "unknown destinations rejected")
	check(not progress.enter("garden"), "cannot skip physical region connections")
	check(progress.enter("harbor"), "base exit leads to harbor")
	check(progress.visited.has("harbor"), "region arrival is recorded")
	check(progress.enter("garden"), "harbor exit leads to new garden")
	check(progress.enter("harbor") and progress.enter("base"), "both exits allow return")
	check(Regions.residents("harbor") != Regions.residents("garden"), "new regions have different residents")
	var stories: Dictionary = Regions.stories()
	for region: String in ["harbor", "garden"]:
		for resident: Dictionary in Regions.residents(region):
			var key: String = Regions.story_key(region, str(resident.id))
			check(stories.has(key), "region resident has authored encounter")
			var director = Story.new()
			director.stories.merge(stories, true)
			check(director.begin(key), "encounter can begin")
			var selected := false
			for step in range(20):
				if not director.active: break
				if director.has_choices(): director.choose(0); selected = true
				else: director.advance()
			check(not director.active and selected, "encounter has a playable branch and ending")
			check(not str(director.choice_history).contains("unlock_character"), "social encounter cannot unlock battle roster")
			progress.complete_scene(key)
	check(not progress.complete_scene("made_up"), "only authored encounters persisted")
	var restored = Exploration.new(path)
	check(restored.visited.size() == 3, "discovered regions restore")
	check(restored.completed.size() == stories.size(), "completed encounters restore")
	check(restored.region == "base", "last region restores")
	print("HOME EXPLORATION: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
