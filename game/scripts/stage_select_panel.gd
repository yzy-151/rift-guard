extends CanvasLayer

const Catalog = preload("res://scripts/combat_catalog.gd")

signal chosen(stage_id: String)

const WHITE := Color("#f3e9df")
const MUTED := Color("#a9929b")
const ACCENT := Color("#e7a0a4")

var root: Control
var buttons: Dictionary = {}
var status_labels: Dictionary = {}
var database
var progress
var hud

func build(owner_hud, game_database, state) -> void:
	hud = owner_hud
	database = game_database
	progress = state
	layer = 44
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	var background := TextureRect.new()
	background.texture = preload("res://assets/helltaker/backgrounds/chapterBG0001.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	owner_hud.bind(background, "stage_background")
	var veil := ColorRect.new()
	veil.color = Color(0.025, 0.012, 0.02, 0.88)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)
	var frame: Panel = owner_hud.panel(root, Rect2(72, 64, 1136, 592), Color("#171119"), Color("#9f4f60"))
	owner_hud.bind(frame, "stage_frame")
	owner_hud.ornament(frame, Rect2(-18, -18, 1172, 628))
	owner_hud.label(frame, Vector2(38, 23), Vector2(700, 20), "M I S S I O N   /   裂 隙 选 择", 12, ACCENT)
	var title: Label = owner_hud.label(frame, Vector2(38, 52), Vector2(700, 43), "选择作战区域", 30, WHITE)
	owner_hud.bind(title, "stage_title")
	owner_hud.label(frame, Vector2(38, 96), Vector2(920, 24), "通关前一关后解锁下一关 · 选择后进入编队", 14, MUTED)
	var mode: Dictionary = database.modes.get("rift_watch", {})
	var ids: Array = mode.get("stage_ids", [])
	for i in ids.size():
		var id: String = str(ids[i])
		var stage: Dictionary = database.stages[id]
		var button: Button = owner_hud.button(frame, Rect2(38 + i * 354, 150, 330, 310), "", true)
		owner_hud.bind(button, "stage_card_%d" % (i + 1))
		button.pressed.connect(select.bind(id))
		buttons[id] = button
		owner_hud.label(button, Vector2(20, 22), Vector2(290, 36), "%02d  %s" % [i + 1, stage.name], 22, WHITE)
		var boss: Dictionary = Catalog.ENEMIES.get(str(stage.boss_id), {})
		owner_hud.label(button, Vector2(20, 70), Vector2(290, 68), "%d分%02d秒\n三路线 · Boss：%s" % [int(stage.duration_seconds) / 60, int(stage.duration_seconds) % 60, boss.get("name", stage.boss_id)], 14, MUTED)
		var record: Label = owner_hud.label(button, Vector2(20, 164), Vector2(290, 78), "", 14, WHITE)
		status_labels[id] = record
		owner_hud.label(button, Vector2(20, 266), Vector2(290, 24), "点击选择并前往编队  →", 13, ACCENT)
	var endless: Dictionary = database.modes.get("endless_survival", {})
	var endless_id := str(endless.get("starting_stage_id", "stage_endless"))
	var endless_button: Button = owner_hud.button(frame, Rect2(38, 475, 1038, 48), "∞  无尽生存 / 猩红荒原    四屏地图 · 四边追击 · 旅行者升级 · 无限构筑     →", true)
	owner_hud.bind(endless_button, "stage_endless")
	endless_button.pressed.connect(select.bind(endless_id))
	buttons[endless_id] = endless_button
	owner_hud.label(frame, Vector2(38, 540), Vector2(1040, 22), "F4 打开关卡选择 · ESC 返回战场", 11, MUTED)
	root.hide()

func open() -> void:
	_refresh()
	root.show()

func close() -> void:
	root.hide()

func is_open() -> bool:
	return root != null and root.visible

func select(id: String) -> void:
	if not _is_unlocked(id):
		return
	root.hide()
	chosen.emit(id)

func _is_unlocked(id: String) -> bool:
	if id == "stage_endless":
		return true
	var ids: Array = database.modes.get("rift_watch", {}).get("stage_ids", [])
	var index := ids.find(id)
	return index == 0 or (index > 0 and progress.cleared_stages.has(str(ids[index - 1])))

func _refresh() -> void:
	for id: String in buttons:
		var unlocked := _is_unlocked(id)
		var button: Button = buttons[id]
		button.disabled = not unlocked
		button.modulate = Color.WHITE if unlocked else Color("#352c31")
		if not status_labels.has(id):
			continue
		var record: Dictionary = progress.stage_records.get(id, {})
		var label: Label = status_labels[id]
		if not unlocked:
			label.text = "档案封锁\n先通关前一作战区域"
		elif record.is_empty():
			label.text = "尚未通关\n最佳记录：--"
		else:
			label.text = "已通关\n最高击退 %d\n最高基地 %d%%\n最高连杀 %d" % [int(record.get("best_kills", 0)), int(record.get("best_base_hp", 0)), int(record.get("best_streak", 0))]
