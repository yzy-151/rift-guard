@tool
extends RefCounted
class_name RiftUIProfileAdapter

const PAGE_PREFIXES := {
	"Dialogue": ["dialogue_"],
	"Mode": ["mode_"],
	"Mission": ["mission_"],
	"Squad": ["squad_"],
	"Campaign Battle": ["battle_", "stage_"],
	"Endless Battle": ["battle_", "stage_"],
	"Reward": ["reward_"],
	"Settings": ["settings_"],
	"Stage": ["stage_"]
}

static func page_names() -> PackedStringArray:
	return PackedStringArray(["Dialogue", "Mode", "Mission", "Squad", "Campaign Battle", "Endless Battle", "Reward", "Settings", "Stage"])

static func records(resource: Resource, page: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if resource == null:
		return result
	var current_group := ""
	for info: Dictionary in resource.get_property_list():
		var usage := int(info.get("usage", 0))
		if usage & PROPERTY_USAGE_GROUP:
			current_group = str(info.get("name", ""))
			continue
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue
		var key := str(info.get("name", ""))
		if key in ["resource_local_to_scene", "resource_name", "script", "schema_version"] or not belongs_to_page(key, current_group, page):
			continue
		var value = resource.get(key)
		if value is Rect2:
			result.append({"key": key, "kind": "rect", "index": -1, "value": value, "group": current_group})
		elif value is Vector2:
			result.append({"key": key, "kind": "size" if key.ends_with("_size") or key.ends_with("_gap") else "point", "index": -1, "value": value, "group": current_group})
		elif value is Array:
			for index in value.size():
				if value[index] is Rect2:
					result.append({"key": key, "kind": "rect", "index": index, "value": value[index], "group": current_group})
		elif value is Texture2D or (value == null and int(info.get("type", TYPE_NIL)) == TYPE_OBJECT):
			result.append({"key": key, "kind": "texture", "index": -1, "value": value, "group": current_group})
	return result

static func belongs_to_page(key: String, group: String, page: String) -> bool:
	if group == "Common" and key.begins_with("common_"):
		return true
	for prefix: String in PAGE_PREFIXES.get(page, []):
		if key.begins_with(prefix):
			return true
	if page == "Mode" and group == "Mode and Mission" and key.begins_with("mode_"):
		return true
	if page == "Mission" and group == "Mode and Mission" and key.begins_with("mission_"):
		return true
	return false

static func display_name(record: Dictionary) -> String:
	var key := str(record.get("key", ""))
	var index := int(record.get("index", -1))
	return "%s[%d]" % [key, index] if index >= 0 else key

static func set_record(resource: Resource, record: Dictionary, value) -> String:
	var key := str(record.get("key", ""))
	if resource == null or not _has_property(resource, key):
		return "字段不存在: %s" % key
	var index := int(record.get("index", -1))
	if index < 0:
		resource.set(key, value)
		return ""
	var values = resource.get(key)
	if not (values is Array) or index >= values.size():
		return "数组字段或索引无效: %s[%d]" % [key, index]
	values[index] = value
	resource.set(key, values)
	return ""

static func _has_property(resource: Resource, key: String) -> bool:
	for info: Dictionary in resource.get_property_list():
		if str(info.get("name", "")) == key:
			return true
	return false
