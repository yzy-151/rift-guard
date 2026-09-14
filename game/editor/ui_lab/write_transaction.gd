@tool
extends RefCounted
class_name RiftUIWriteTransaction

const Validator = preload("res://editor/ui_lab/profile_validator.gd")
const LOCK_PATH := "res://editor/ui_lab/.master_editing.lock"

static func file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

static func acquire_lock(page: String) -> void:
	var file := FileAccess.open(LOCK_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"page": page, "unix_time": Time.get_unix_time_from_system()}))

static func release_lock() -> void:
	if FileAccess.file_exists(LOCK_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK_PATH))

static func save_pair(layout: Resource, skin: Resource, layout_path: String, skin_path: String, expected_layout_hash: String, expected_skin_hash: String) -> Dictionary:
	var errors := Validator.validate(layout, "Layout")
	errors.append_array(Validator.validate(skin, "Skin"))
	if not errors.is_empty():
		return {"ok": false, "message": "\n".join(errors)}
	if file_hash(layout_path) != expected_layout_hash:
		return {"ok": false, "message": "Layout 已被外部修改，请先点击刷新。"}
	if file_hash(skin_path) != expected_skin_hash:
		return {"ok": false, "message": "Skin 已被外部修改，请先点击刷新。"}
	var layout_temp := layout_path.get_basename() + ".ui_lab_tmp.tres"
	var skin_temp := skin_path.get_basename() + ".ui_lab_tmp.tres"
	var layout_error := ResourceSaver.save(layout, layout_temp)
	var skin_error := ResourceSaver.save(skin, skin_temp)
	if layout_error != OK or skin_error != OK:
		_cleanup([layout_temp, skin_temp])
		return {"ok": false, "message": "临时资源保存失败: %s / %s" % [error_string(layout_error), error_string(skin_error)]}
	var probe_layout := ResourceLoader.load(layout_temp, "", ResourceLoader.CACHE_MODE_IGNORE)
	var probe_skin := ResourceLoader.load(skin_temp, "", ResourceLoader.CACHE_MODE_IGNORE)
	var probe_errors := Validator.validate(probe_layout, "Layout 临时文件")
	probe_errors.append_array(Validator.validate(probe_skin, "Skin 临时文件"))
	if not probe_errors.is_empty():
		_cleanup([layout_temp, skin_temp])
		return {"ok": false, "message": "\n".join(probe_errors)}
	var layout_original := FileAccess.get_file_as_bytes(layout_path)
	var skin_original := FileAccess.get_file_as_bytes(skin_path)
	var write_error := _copy_bytes(layout_temp, layout_path)
	if write_error == OK:
		write_error = _copy_bytes(skin_temp, skin_path)
	if write_error != OK:
		_restore_bytes(layout_path, layout_original)
		_restore_bytes(skin_path, skin_original)
		_cleanup([layout_temp, skin_temp])
		return {"ok": false, "message": "写回失败且已恢复原文件: %s" % error_string(write_error)}
	_cleanup([layout_temp, skin_temp])
	var saved_layout := ResourceLoader.load(layout_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	var saved_skin := ResourceLoader.load(skin_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	var final_errors := Validator.validate(saved_layout, "Layout 写回结果")
	final_errors.append_array(Validator.validate(saved_skin, "Skin 写回结果"))
	if not final_errors.is_empty():
		_restore_bytes(layout_path, layout_original)
		_restore_bytes(skin_path, skin_original)
		return {"ok": false, "message": "写回后校验失败且已恢复原文件:\n%s" % "\n".join(final_errors)}
	return {"ok": true, "message": "写回成功，运行游戏或按 F6/F7 查看结果。", "layout_hash": file_hash(layout_path), "skin_hash": file_hash(skin_path)}

static func _copy_bytes(from_path: String, to_path: String) -> Error:
	var output := FileAccess.open(to_path, FileAccess.WRITE)
	if output == null:
		return FileAccess.get_open_error()
	output.store_buffer(FileAccess.get_file_as_bytes(from_path))
	output.close()
	return OK

static func _restore_bytes(path: String, bytes: PackedByteArray) -> void:
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output != null:
		output.store_buffer(bytes)
		output.close()

static func _cleanup(paths: Array[String]) -> void:
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
