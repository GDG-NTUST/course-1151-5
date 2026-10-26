extends SceneTree
## 隊伍檢查：學員在本機跑的和 GitHub Actions 檢查 PR 時跑的是同一支腳本。
##
##   godot --headless --script res://tools/validate.gd -- 你的帳號
##
## GitHub Actions 另外會傳：
##   --changed=檔案   PR 改到的檔案清單（git diff --name-status 的格式），用來檢查只改了自己的資料夾
##   --summary=檔案   把結果（Markdown）附加到這個檔案，也就是 job summary
##
## 依序檢查：1 檔案範圍 → 2 程式碼掃描 → 3 語法 → 4 隊伍設定 → 5 試打 Lv1。
## 程式碼掃描沒通過就不會執行學員的程式；前面的檢查沒通過，後面的會略過。
## 結束代碼：0 全部通過、1 有檢查沒通過。

const PASS := "pass"
const FAIL := "fail"
const SKIP := "skip"
const TEST_BOSS := "lv1"


## 收集執行學員程式時發生的錯誤（例如陣列超出範圍、呼叫 null 的方法）
class ErrorCatcher extends Logger:
	var errors: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var where: String = "%s:%d" % [file, line]
		for backtrace: ScriptBacktrace in script_backtraces:
			if backtrace.get_frame_count() > 0:
				where = "%s 第 %d 行" % [backtrace.get_frame_file(0).trim_prefix("res://"), backtrace.get_frame_line(0)]
				break
		var message: String = code if rationale == "" else "%s（%s）" % [rationale, code]
		errors.append("%s：%s" % [where, message])

	func _log_message(_message: String, _error: bool) -> void:
		pass


class Section:
	var title: String
	var status: String = PASS
	var lines: Array[String] = []

	func _init(p_title: String) -> void:
		title = p_title


var github: String = ""
var sections: Array[Section] = []
var battle: Battle = null   # 第 4 項建立並檢查、第 5 項試打的同一場戰鬥


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var changed_path: String = ""
	var summary_path: String = ""
	for arg: String in args:
		if arg.begins_with("--changed="):
			changed_path = arg.trim_prefix("--changed=")
		elif arg.begins_with("--summary="):
			summary_path = arg.trim_prefix("--summary=")
		elif github == "":
			github = arg
	if github == "":
		print("用法：godot --headless --script res://tools/validate.gd -- 你的GitHub帳號")
		quit(1)
		return

	var dir: String = Rules.team_dir(github)
	_check_files(changed_path)
	var ok: bool = _check_scan(dir)
	ok = ok and _check_syntax(dir)
	ok = ok and _check_team()
	if ok:
		_check_battle()

	var report: String = _report()
	print(report)
	if summary_path != "":
		_append(summary_path, report)
	# ok 也要看：學員的東西讓檢查函式中途出錯的話，它會回傳 false 卻沒標 FAIL
	quit(0 if ok and sections.all(func(s: Section) -> bool: return s.status != FAIL) else 1)


# ---------------------------------------------------------------- 檢查

func _check_files(changed_path: String) -> void:
	var section: Section = _section("1. 只修改自己的資料夾")
	if changed_path == "":
		section.status = SKIP
		section.lines.append("只有檢查 PR 時才會比對改到的檔案。")
		return
	var allowed: String = "teams/%s/" % github
	var count: int = 0
	for line: String in FileAccess.get_file_as_string(changed_path).split("\n", false):
		var parts: PackedStringArray = line.split("\t")
		if parts.size() < 2:
			continue
		count += 1
		var path: String = parts[parts.size() - 1]
		if not path.begins_with(allowed):
			section.status = FAIL
			section.lines.append("`%s`：PR 只能改 `%s` 底下的檔案，請把這個檔案的修改移出這個 PR" % [path, allowed])
	if section.status == PASS:
		section.lines.append("改了 %d 個檔案，都在 `%s` 裡。" % [count, allowed])


func _check_scan(dir: String) -> bool:
	var section: Section = _section("2. 程式碼掃描")
	if not DirAccess.dir_exists_absolute(dir):
		section.status = FAIL
		section.lines.append("找不到 `%s/`。資料夾名稱要和你的 GitHub 帳號一模一樣（包含大小寫）" % dir.trim_prefix("res://"))
		return false
	var files: Array[String] = Validator.gd_files(dir)
	var errors: Array[String] = Validator.scan_folder(dir)
	if errors.is_empty():
		section.lines.append("掃描了 %d 個 .gd 檔，沒有發現禁止的寫法。" % files.size())
		return true
	section.status = FAIL
	section.lines.append_array(errors)
	section.lines.append("為了安全，掃描沒通過之前不會執行你的程式，後面的檢查先略過。")
	return false


## 每個檔案用另一個 Godot 程序 --check-only 檢查，才拿得到語法錯誤的行號
func _check_syntax(dir: String) -> bool:
	var section: Section = _section("3. 語法")
	var project: String = ProjectSettings.globalize_path("res://")
	var error_regex: RegEx = RegEx.create_from_string(r"Parse Error: (.*)\n\s*at: .*\((res://[^)]*?):(\d+)\)")
	var seen: Dictionary = {}
	var files: Array[String] = Validator.gd_files(dir)
	for path: String in files:
		var output: Array = []
		OS.execute(OS.get_executable_path(), ["--headless", "--path", project, "--check-only", "--script", path], output, true)
		for found: RegExMatch in error_regex.search_all("\n".join(output)):
			var message: String = "%s 第 %s 行：%s" % [found.get_string(2).trim_prefix("res://"), found.get_string(3), found.get_string(1).strip_edges()]
			if not seen.has(message):
				seen[message] = true
				section.lines.append(message)
	if seen.is_empty():
		section.lines.append("%d 個 .gd 檔都沒有語法錯誤。" % files.size())
		return true
	section.status = FAIL
	section.lines.append("請照上面的錯誤訊息修正那一行；在 Godot 編輯器打開檔案，錯誤的地方會標紅色。")
	return false


func _check_team() -> bool:
	var section: Section = _section("4. 隊伍設定（team.gd、站位、數值、預算）")
	var catcher: ErrorCatcher = ErrorCatcher.new()
	OS.add_logger(catcher)
	var errors: Array[String] = Validator.check_team_folder(github)
	var team: Team = null
	if errors.is_empty():
		# 檢查第 5 項真的會上場的這一批角色
		team = Team.load_folder(github)
		battle = Battle.new(team.members, [load(Rules.BOSSES[TEST_BOSS]) as Script])
		errors = Validator.check_side(battle, Battle.PLAYER, github)
	OS.remove_logger(catcher)
	errors.append_array(catcher.errors)
	if not errors.is_empty():
		section.status = FAIL
		section.lines.append_array(errors)
		if battle != null:
			for unit: Unit in battle.roster:
				unit.free()
		return false
	section.lines.append("%s：%s" % [team.label(), Validator.describe_cost(battle.created[Battle.PLAYER])])
	for unit: Unit in battle.created[Battle.PLAYER]:
		section.lines.append("%s（%s）站在 %s" % [unit.unit_name, unit.get_role(), Rules.cell_label(unit.grid_position)])
	return true


func _check_battle() -> void:
	var section: Section = _section("5. 試打 Boss Lv1（輸贏不影響檢查）")
	var catcher: ErrorCatcher = ErrorCatcher.new()
	OS.add_logger(catcher)
	var violations: Array[String] = []
	battle.logged.connect(func(text: String) -> void:
		if text.contains("⚠"):
			violations.append(_plain(text)))
	battle.start()
	while battle.result == "" and battle.round_number <= Rules.MAX_ROUNDS:
		battle.step()
	OS.remove_logger(catcher)
	for unit: Unit in battle.roster:
		unit.free()

	if battle.result == "":
		section.status = FAIL
		section.lines.append("戰鬥沒有正常結束，請檢查技能裡的邏輯。")
	else:
		var outcome: String = "勝利 douob" if battle.result == "win" else "落敗 qonop"
		section.lines.append("戰鬥跑完了：%s（%s，第 %d 回合）" % [outcome, battle.result_reason, battle.round_number])
	if not catcher.errors.is_empty():
		section.status = FAIL
		section.lines.append("執行時發生錯誤，技能裡出錯的那一段沒有生效：")
		for error: String in _unique(catcher.errors):
			section.lines.append(error)
	if not violations.is_empty():
		section.lines.append("戰鬥紀錄裡的警告（不影響檢查，但技能可能沒照你想的運作）：")
		section.lines.append_array(_unique(violations))


# ---------------------------------------------------------------- 報告

func _section(title: String) -> Section:
	var section: Section = Section.new(title)
	sections.append(section)
	return section


func _report() -> String:
	var icons: Dictionary = {PASS: "✅", FAIL: "❌", SKIP: "⏭️"}
	var failed: bool = sections.any(func(s: Section) -> bool: return s.status == FAIL)
	var out: Array[String] = []
	out.append("## %s 隊伍檢查：`%s` %s" % ["❌" if failed else "✅", github, "qonop" if failed else "douob"])
	out.append("")
	out.append("| 檢查 | 結果 |")
	out.append("|---|---|")
	for section: Section in sections:
		out.append("| %s | %s |" % [section.title, icons[section.status]])
	for title: String in ["1. 只修改自己的資料夾", "2. 程式碼掃描", "3. 語法", "4. 隊伍設定（team.gd、站位、數值、預算）", "5. 試打 Boss Lv1（輸贏不影響檢查）"]:
		if not sections.any(func(s: Section) -> bool: return s.title == title):
			out.append("| %s | ⏭️ 前面的檢查沒通過，先略過 |" % title)
	for section: Section in sections:
		out.append("")
		out.append("### %s %s" % [icons[section.status], section.title])
		for line: String in section.lines:
			out.append("- %s" % line.replace("|", "\\|"))
	out.append("")
	out.append("在自己電腦上跑一樣的檢查：`godot --headless --script res://tools/validate.gd -- %s`" % github)
	return "\n".join(out) + "\n"


func _append(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		push_error("寫不進 %s" % path)
		return
	file.seek_end()
	file.store_string(text)
	file.close()


func _plain(text: String) -> String:
	var tags: RegEx = RegEx.create_from_string(r"\[/?(b|i|u|color)(=[^\]]*)?\]")
	return tags.sub(text, "", true).replace("[lb]", "[").replace("[rb]", "]")


func _unique(items: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for item: String in items:
		if not result.has(item):
			result.append(item)
	return result
