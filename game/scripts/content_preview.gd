extends CanvasLayer
var game
var list: ItemList
var scene_keys: Array[String] = []
func build(main) -> void:
	game = main
	layer = 24
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = game.hud.get_child(0).theme
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.015, 0.025, 0.96)
	root.add_child(shade)
	game.hud.label(root, Vector2(330, 130), Vector2(720, 50), "对话预览", 32, Color("#f1cdc4"))
	game.hud.label(root, Vector2(330, 186), Vector2(720, 35), "保存 Excel 后重启游戏更新；预览不改变本局进度。", 15, Color("#bdacb7"))
	list = ItemList.new()
	list.position = Vector2(330, 240)
	list.size = Vector2(620, 280)
	list.add_theme_font_size_override("font_size", 20)
	root.add_child(list)
	list.item_activated.connect(func(_index: int): play())
	var play_button: Button = game.hud.button(root, Rect2(650, 546, 300, 44), "播放选中段落", true)
	play_button.pressed.connect(play)
	var close_button: Button = game.hud.button(root, Rect2(330, 546, 300, 44), "返回 [Esc]", false)
	close_button.pressed.connect(func(): hide(); game.refresh())
	hide()
func open() -> void:
	scene_keys.clear()
	list.clear()
	for key in game.story.stories:
		if not game.story.stories[key].is_empty():
			scene_keys.append(key)
			list.add_item(key + "  /  %d 句" % game.story.stories[key].size())
	if not scene_keys.is_empty():
		list.select(0)
	show()
	list.grab_focus()
func play() -> void:
	var selection: PackedInt32Array = list.get_selected_items()
	if not selection.is_empty():
		game.preview_scene(scene_keys[selection[0]])
