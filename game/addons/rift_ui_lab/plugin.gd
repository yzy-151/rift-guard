@tool
extends EditorPlugin

const WORKSPACE_SCENE := "res://editor/ui_lab/ui_lab_workspace.tscn"
const DockScene = preload("res://editor/ui_lab/ui_lab_dock.tscn")
const Transaction = preload("res://editor/ui_lab/write_transaction.gd")
var dock: RiftUILayoutDock
var live_refresh_elapsed := 0.0

func _enter_tree() -> void:
	dock = DockScene.instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	dock.open_requested.connect(_open_workspace)
	dock.page_requested.connect(_show_page)
	dock.refresh_requested.connect(_refresh)
	dock.write_requested.connect(_write_back)
	dock.field_selected.connect(_select_field)
	scene_changed.connect(_scene_changed)
	set_process(true)

func _exit_tree() -> void:
	Transaction.release_lock()
	if scene_changed.is_connected(_scene_changed):
		scene_changed.disconnect(_scene_changed)
	if dock != null:
		remove_control_from_docks(dock)
		dock.queue_free()

func _process(delta: float) -> void:
	live_refresh_elapsed += delta
	if live_refresh_elapsed < 0.25 or dock == null:
		return
	live_refresh_elapsed = 0.0
	var workspace := _workspace()
	if workspace != null:
		dock.update_fields(workspace.field_rows())

func _open_workspace() -> void:
	get_editor_interface().open_scene_from_path(WORKSPACE_SCENE)
	call_deferred("_show_page", dock.selected_page())

func _workspace() -> RiftUILayoutWorkspace:
	var root := get_editor_interface().get_edited_scene_root()
	return root as RiftUILayoutWorkspace if root is RiftUILayoutWorkspace else null

func _show_page(page: String) -> void:
	var workspace := _workspace()
	if workspace == null:
		_open_workspace()
		return
	dock.set_page(page)
	var result := workspace.rebuild(page)
	dock.show_result(result)
	dock.update_fields(workspace.field_rows())
	get_editor_interface().mark_scene_as_unsaved()

func _refresh() -> void:
	_show_page(dock.selected_page())

func _write_back() -> void:
	var workspace := _workspace()
	if workspace == null:
		dock.show_result({"ok": false, "message": "请先点击“打开实验台场景”。"})
		return
	var result := workspace.write_back()
	dock.show_result(result)
	dock.update_fields(workspace.field_rows())
	if bool(result.get("ok", false)):
		get_editor_interface().get_resource_filesystem().scan()

func _select_field(index: int) -> void:
	var workspace := _workspace()
	if workspace == null:
		return
	var nodes: Array[Node] = workspace.editable_nodes()
	if index < 0 or index >= nodes.size():
		return
	var selection := get_editor_interface().get_selection()
	selection.clear()
	selection.add_node(nodes[index])

func _scene_changed(scene_root: Node) -> void:
	if scene_root is RiftUILayoutWorkspace:
		call_deferred("_show_page", dock.selected_page())
