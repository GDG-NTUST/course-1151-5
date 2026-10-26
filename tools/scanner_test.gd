extends SceneTree
## Validator 掃描的回歸測試：tools/scanner_cases.txt 裡標了 BAD 的行都要被擋，其他行都不能被擋。
##
##   godot --headless --script res://tools/scanner_test.gd

const CASES := "res://tools/scanner_cases.txt"


func _init() -> void:
	var expected: Array[int] = []
	var lines: PackedStringArray = FileAccess.get_file_as_string(CASES).split("\n")
	for i: int in lines.size():
		if lines[i].ends_with("# BAD"):
			expected.append(i + 1)
		elif lines[i].strip_edges() == "# BAD 下一行":   # 用 \ 接續的那一行不能寫註解
			expected.append(i + 2)
	var flagged: Array[int] = []
	var failed: bool = false
	var line_regex: RegEx = RegEx.create_from_string(r"第 (\d+) 行")
	for error: String in Validator.check_source(CASES):
		var found: RegExMatch = line_regex.search(error)
		var row: int = int(found.get_string(1)) if found else 0
		flagged.append(row)
		if not expected.has(row):
			print("誤擋：", error)
			failed = true
	for row: int in expected:
		if not flagged.has(row):
			print("沒擋到第 %d 行：%s" % [row, lines[row - 1].strip_edges()])
			failed = true
	print("FAIL" if failed else "OK：%d 行都擋到了，沒有誤擋" % expected.size())
	quit(1 if failed else 0)
