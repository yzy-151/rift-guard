extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("CONTENT PASS: " if ok else "CONTENT FAIL: ") + message)
func _initialize() -> void:
	var Config = preload("res://scripts/content_config.gd")
	var root: String = ProjectSettings.globalize_path("res://../research/m5-fixtures")
	var original = Config.new(ProjectSettings.globalize_path("res://../content"))
	check(original.loaded and original.errors.is_empty(), "real authored xlsx loads")
	check(original.stories.get("opening", []).size() == 4 and original.stories.get("mode1_opening", []).size() == 3 and original.ui.size() == 35, "legacy and Mode 1 stories plus all UI controls parsed")
	if original.loaded:
		check(original.texture("saria") != null, "built-in texture resolves")
	var modified = Config.new(root.path_join("modified"))
	check(modified.loaded, "edited workbook with external PNG loads")
	if modified.loaded:
		var line: Dictionary = modified.stories.opening[0]
		check(line.speaker == "测试编剧" and line.text == "Excel 自动加载验证", "speaker and dialogue use edited Excel cells")
		check(line.x == 900 and line.y == 100 and line.scale == 0.6 and line.flip and line.side == "right", "position scale flip and side parsed")
		check(line.partner == "" and modified.stories.has("extra_scene"), "blank companion and custom scene supported")
		check(modified.texture("qa_external") != null, "external PNG decoded")
		var frame := NinePatchRect.new()
		modified.apply_ui(frame, "dialog_frame")
		check(frame.position == Vector2(60, 450) and frame.size == Vector2(1000, 240), "Excel UI frame coordinates apply")
		frame.free()
		var button := Button.new()
		modified.apply_ui(button, "dialog_continue")
		check(button.text == "测试继续", "Excel static UI text applies")
		check(button.get_child_count() == 1 and button.get_child(0).show_behind_parent, "keep button artwork draws behind caption")
		button.free()
	for variant in ["missing_image", "invalid_number", "duplicate_order", "formula", "truncated_xml"]:
		var bad = Config.new(root.path_join(variant))
		check(not bad.loaded and not bad.errors.is_empty() and bad.stories.is_empty() and bad.ui.is_empty(), variant + " rejected atomically")
	var disabled = Config.new(root.path_join("disabled_opening"))
	check(disabled.loaded and disabled.stories.opening.is_empty(), "disabling opening is valid configuration")
	print("CONTENT TESTS: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
