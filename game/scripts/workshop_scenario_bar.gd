extends Panel
## Persistent experiment recipes, separate from campaign checkpoints.
const Store = preload("res://scripts/workshop_scenarios.gd")

var workshop
var store
var picker: OptionButton
var summary: Label
var save_button: Button
var load_button: Button
var confirmation: ConfirmationDialog
var pending_action := ""
var pending_slot := 1
var was_paused := false

func build(owner_panel, directory: String) -> void:
	workshop = owner_panel
	store = Store.new(directory)
	var region: Rect2 = workshop.hud.UI_LAYOUT.battle_workshop_scenario_bar_rect
	position = region.position
	size = region.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#180e16")
	style.border_color = Color("#75414c")
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	workshop._label(self, Rect2(14, 8, 125, 30), "实验场景", 19, workshop.WHITE)
	picker = workshop._picker(self, Rect2(144, 8, 148, 32))
	for slot in range(1, 4): picker.add_item("场景槽 %d" % slot)
	picker.item_selected.connect(func(_index: int): refresh_slots())
	save_button = workshop._button(self, Rect2(306, 8, 154, 32), "保存场景 [F5]", "scenario_save", request_save)
	load_button = workshop._button(self, Rect2(470, 8, 154, 32), "载入场景 [F9]", "scenario_load", request_load)
	workshop._label(self, Rect2(638, 8, 138, 30), "载入后暂停", 12, workshop.MUTED)
	summary = workshop._label(self, Rect2(14, 44, 756, 20), "", 12, workshop.MUTED)
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	confirmation = ConfirmationDialog.new()
	confirmation.title = "实验场景"
	confirmation.ok_button_text = "确认"
	confirmation.cancel_button_text = "取消"
	confirmation.dialog_autowrap = true
	confirmation.min_size = Vector2i(460, 180)
	confirmation.confirmed.connect(_confirm)
	confirmation.canceled.connect(_cancel)
	add_child(confirmation)
	refresh_slots()

func refresh_slots() -> void:
	var info: Dictionary = store.slot_info(picker.selected + 1)
	var error := str(info.get("error", ""))
	load_button.disabled = not bool(info.get("occupied", false)) or not error.is_empty()
	load_button.text = "恢复备份 [F9]" if not str(info.get("warning", "")).is_empty() else "载入场景 [F9]"
	summary.text = error if not error.is_empty() else str(info.get("summary", "空槽 · 保存地图、摆放、卡牌与实验开关"))
	if summary.text.is_empty(): summary.text = "空槽 · 保存地图、摆放、卡牌与实验开关"
	summary.tooltip_text = summary.text

func request_save() -> void:
	if confirmation.visible: return
	pending_slot = picker.selected + 1
	var info: Dictionary = store.slot_info(pending_slot)
	if bool(info.get("occupied", false)):
		_ask("save", "覆盖场景槽 %d 的现有配置？\n保存当前摆放和构筑，载入时从满血实验起点开始。" % pending_slot)
	else:
		_save()

func request_load() -> void:
	if confirmation.visible: return
	refresh_slots()
	if load_button.disabled: return
	pending_slot = picker.selected + 1
	var warning := str(store.slot_info(pending_slot).get("warning", ""))
	var message := "载入场景槽 %d 并替换当前工坊？\n未保存的摆放会丢失；载入后时间归零并暂停。" % pending_slot
	if not warning.is_empty(): message = warning + "\n确认恢复上一份完整配置并替换当前工坊？\n载入后时间归零并暂停。"
	_ask("load", message)

func _ask(action: String, message: String) -> void:
	pending_action = action
	was_paused = workshop.session.paused
	workshop.session.paused = true
	workshop.pan_keys.clear()
	workshop.card_search.release_focus()
	confirmation.dialog_text = message
	confirmation.popup_centered()
	workshop.refresh()

func _cancel() -> void:
	workshop.session.paused = was_paused
	pending_action = ""
	workshop.refresh()

func _confirm() -> void:
	var action := pending_action
	pending_action = ""
	workshop.session.paused = was_paused
	if action == "save": _save()
	elif action == "load":
		var result: Dictionary = store.load_slot(pending_slot)
		if bool(result.get("ok", false)):
			workshop.restore_scenario(result.session)
			workshop.session.message = "已载入场景槽 %d · 实验起点已暂停，按空格运行或逐帧观察。" % pending_slot
			if not str(result.get("warning", "")).is_empty(): workshop.session.message = str(result.warning) + " · 已恢复并暂停。"
		else:
			workshop.session.message = "载入失败：" + str(result.get("error", "未知错误"))
		refresh_slots()
		workshop.refresh()

func _save() -> void:
	var result: Dictionary = store.save_slot(pending_slot, workshop.session)
	workshop.session.message = "已保存场景槽 %d · 可退出游戏后重新载入。" % pending_slot if bool(result.get("ok", false)) else "保存失败：" + str(result.get("error", "未知错误"))
	refresh_slots()
	workshop.refresh()
