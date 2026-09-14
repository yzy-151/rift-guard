@tool
extends RefCounted
class_name RiftUIProfileValidator

const Adapter = preload("res://editor/ui_lab/profile_adapter.gd")

static func validate(resource: Resource, label: String = "Profile") -> PackedStringArray:
	var errors := PackedStringArray()
	if resource == null:
		errors.append("%s 未加载" % label)
		return errors
	if not Adapter._has_property(resource, "schema_version"):
		errors.append("%s 缺少 schema_version" % label)
	elif int(resource.get("schema_version")) < 1:
		errors.append("%s schema_version 必须大于 0" % label)
	for page: String in Adapter.page_names():
		for record: Dictionary in Adapter.records(resource, page):
			var value = record.get("value")
			var key := Adapter.display_name(record)
			if value is Rect2 and (value.size.x <= 0.0 or value.size.y <= 0.0):
				errors.append("%s 尺寸必须为正数: %s = %s" % [label, key, value])
			elif value is Vector2 and str(record.get("kind", "")) == "size" and (value.x < 0.0 or value.y < 0.0):
				errors.append("%s 尺寸或间距不能为负数: %s = %s" % [label, key, value])
	return errors

static func validate_expected_fields(resource: Resource, fields: PackedStringArray, label: String) -> PackedStringArray:
	var errors := PackedStringArray()
	for field: String in fields:
		if not Adapter._has_property(resource, field):
			errors.append("%s 字段丢失: %s" % [label, field])
	return errors
