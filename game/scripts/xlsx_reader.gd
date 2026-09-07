extends RefCounted
var errors: Array[String] = []
var strings: Array[String] = []
func tag(xml: XMLParser) -> String:
	return xml.get_node_name().get_slice(":", xml.get_node_name().get_slice_count(":") - 1)
func read(path: String) -> Dictionary:
	errors.clear()
	strings.clear()
	var output: Dictionary = {}
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		errors.append("无法打开 Excel：" + path)
		return output
	for file in ["xl/workbook.xml", "xl/_rels/workbook.xml.rels"]:
		if not zip.file_exists(file):
			errors.append("xlsx 缺少文件：" + file)
	for file in ["xl/workbook.xml", "xl/_rels/workbook.xml.rels"]:
		if zip.file_exists(file):
			valid_xml(zip.read_file(file), file)
	if not errors.is_empty():
		zip.close()
		return output
	if zip.file_exists("xl/sharedStrings.xml"):
		shared(zip.read_file("xl/sharedStrings.xml"))
	var links: Dictionary = {}
	var xml := XMLParser.new()
	if xml.open_buffer(zip.read_file("xl/_rels/workbook.xml.rels")) != OK:
		errors.append("工作表关联损坏")
	else:
		while xml.read() == OK:
			if xml.get_node_type() == XMLParser.NODE_ELEMENT and tag(xml) == "Relationship":
				var target: String = xml.get_named_attribute_value_safe("Target")
				links[xml.get_named_attribute_value_safe("Id")] = target.trim_prefix("/") if target.begins_with("/") else ("xl/" + target).simplify_path()
	var names: Dictionary = {}
	xml = XMLParser.new()
	if xml.open_buffer(zip.read_file("xl/workbook.xml")) != OK:
		errors.append("工作簿 XML 损坏")
	else:
		while xml.read() == OK:
			if xml.get_node_type() == XMLParser.NODE_ELEMENT and tag(xml) == "sheet":
				names[xml.get_named_attribute_value_safe("name")] = links.get(xml.get_named_attribute_value_safe("r:id"), "")
	for name in names:
		if not zip.file_exists(names[name]):
			errors.append("工作表缺失：" + str(name))
		else:
			output[name] = rows(zip.read_file(names[name]), name)
	zip.close()
	return output
func shared(bytes: PackedByteArray) -> void:
	if not valid_xml(bytes, "sharedStrings"):
		return
	var xml := XMLParser.new()
	if xml.open_buffer(bytes) != OK:
		errors.append("共享字符串表损坏")
		return
	var value: String = ""
	var in_text: bool = false
	while xml.read() == OK:
		if xml.get_node_type() == XMLParser.NODE_ELEMENT:
			if tag(xml) == "si":
				value = ""
			elif tag(xml) == "t":
				in_text = not xml.is_empty()
		elif xml.get_node_type() == XMLParser.NODE_TEXT and in_text:
			value += xml.get_node_data()
		elif xml.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if tag(xml) == "t":
				in_text = false
			elif tag(xml) == "si":
				strings.append(value)
func rows(bytes: PackedByteArray, sheet: String) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not valid_xml(bytes, sheet):
		return output
	var xml := XMLParser.new()
	if xml.open_buffer(bytes) != OK:
		errors.append(sheet + " XML 损坏")
		return output
	var cells: Dictionary = {}
	var row: int = 0
	var ref: String = ""
	var kind: String = ""
	var value: String = ""
	var reading: bool = false
	while xml.read() == OK:
		if xml.get_node_type() == XMLParser.NODE_ELEMENT:
			match tag(xml):
				"row":
					row = int(xml.get_named_attribute_value_safe("r"))
					cells = {}
				"c":
					ref = xml.get_named_attribute_value_safe("r")
					kind = xml.get_named_attribute_value_safe("t")
					value = ""
					reading = false
				"v", "t":
					reading = not xml.is_empty()
				"f":
					if row >= 5:
						errors.append("%s!%s 不支持公式，请填写实际值" % [sheet, ref])
		elif xml.get_node_type() == XMLParser.NODE_TEXT and reading:
			value += xml.get_node_data()
		elif xml.get_node_type() == XMLParser.NODE_ELEMENT_END:
			match tag(xml):
				"v", "t":
					reading = false
				"c":
					if kind == "s":
						if value.is_valid_int() and int(value) >= 0 and int(value) < strings.size():
							value = strings[int(value)]
						else:
							errors.append("%s!%s 字符串索引无效" % [sheet, ref])
					elif kind == "e" and row >= 5:
						errors.append("%s!%s 包含 Excel 错误" % [sheet, ref])
					var column: String = ""
					for c in ref:
						if c >= "A" and c <= "Z":
							column += c
					cells[column] = value
				"row":
					output.append({"row": row, "cells": cells.duplicate()})
	return output

func valid_xml(bytes: PackedByteArray, label: String) -> bool:
	var xml := XMLParser.new()
	if xml.open_buffer(bytes) != OK:
		errors.append(label + " XML 无法解析")
		return false
	var stack: Array[String] = []
	var roots: int = 0
	var code: int = xml.read()
	while code == OK:
		if xml.get_node_type() == XMLParser.NODE_ELEMENT:
			if stack.is_empty():
				roots += 1
			if not xml.is_empty():
				stack.append(xml.get_node_name())
		elif xml.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if stack.is_empty() or stack.back() != xml.get_node_name():
				errors.append(label + " XML 结束标签不匹配")
				return false
			stack.pop_back()
		code = xml.read()
	if code != ERR_FILE_EOF or not stack.is_empty() or roots != 1:
		errors.append(label + " XML 损坏或未完整保存")
		return false
	return true
