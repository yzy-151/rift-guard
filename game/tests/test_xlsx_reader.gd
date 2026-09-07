extends SceneTree
func _initialize() -> void:
	var reader = preload("res://scripts/xlsx_reader.gd").new()
	reader.shared('<sst><si><t>姓名</t></si><si><r><t>你</t></r><r><t>好</t></r></si></sst>'.to_utf8_buffer())
	var rows: Array = reader.rows('<worksheet><sheetData><row r="5"><c r="A5" t="s"><v>1</v></c><c r="C5"><v>0.75</v></c><c r="D5" t="inlineStr"><is><t>甲 &amp; 乙</t></is></c><c r="H5" t="b"><v>1</v></c></row></sheetData></worksheet>'.to_utf8_buffer(), "test")
	var valid: bool = reader.strings == ["姓名", "你好"] and rows.size() == 1
	valid = valid and rows[0].cells.A == "你好" and rows[0].cells.C == "0.75" and rows[0].cells.D == "甲 & 乙" and rows[0].cells.H == "1"
	reader.rows('<worksheet><row r="5"><c r="A5"><f>1+1</f><v>2</v></c></row></worksheet>'.to_utf8_buffer(), "bad")
	valid = valid and not reader.errors.is_empty()
	print("XLSX XML READER: " + ("PASS" if valid else "FAIL"))
	quit(0 if valid else 1)
