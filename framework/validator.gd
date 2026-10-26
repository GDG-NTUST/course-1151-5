class_name Validator
extends RefCounted
## 上場前的檢查：用文字掃描學員的 .gd 擋掉作弊和危險的寫法 + 站位、點數預算。
## 回傳錯誤訊息陣列，空陣列代表通過。
##
## 擂台賽會在講師的電腦上執行所有人的程式，所以除了作弊，也要擋掉
## 碰檔案、網路、系統的功能，以及打開專案就會在 Godot 編輯器裡執行的 @tool。
## 訊息裡的 {0} 會換成實際寫到的字。

const BANNED := [
	[r"@tool\b",
		"不能用 @tool（打開專案時就會在 Godot 編輯器裡執行）"],
	[r"\bclass_name\b",
		"不能用 class_name（全班的類別名稱會撞在一起），自己寫的類別請用 preload(\"檔名.gd\")"],
	[r"\bstatic\s+var\b",
		"不能用 static var（每次建立的角色都要一樣，也不能把資料帶到下一場戰鬥）"],
	[r"\b(_process|_physics_process|_ready|_enter_tree|_exit_tree|_notification|_input|_unhandled_input|_unhandled_key_input|_shortcut_input)\b",
		"不能覆寫 {0}，畫面效果請寫在 on_frame(delta)"],
	[r"\b(OS|FileAccess|DirAccess|ResourceLoader|ResourceSaver|ClassDB|Engine|EngineDebugger|ProjectSettings|JavaScriptBridge|Thread|Mutex|Semaphore|WorkerThreadPool|HTTPRequest|HTTPClient|StreamPeer\w*|PacketPeer\w*|WebSocket\w*|WebRTC\w*|ENet\w*|IP|Marshalls|Input|InputMap|DisplayServer|Performance|GDExtension\w*|\w+Server(2D|3D)?)\b",
		"不能使用 {0}（系統、檔案、網路和引擎的功能都不能用）"],
	[r"\b(load|instance_from_id|str_to_var|bytes_to_var_with_objects|get_script|get_property_list|get_method_list)\s*\(",
		"不能用 {0}()，要用自己資料夾裡的檔案請寫 preload(\"檔名.gd\")"],
	[r"\"\"\"|'''",
		"不能用三個引號的多行字串"],
	[r"\bget_tree\b|\bget_node\b|\bget_parent\b|\bget_child(ren)?\b|\bfind_child(ren)?\b|\$[\w\"]",
		"不能用 get_tree / get_node 這類方法去抓別的物件，請用 get_allies() / get_enemies()"],
	[r"\b_framework",
		"不能碰框架內部（_framework 開頭的東西）"],
	[r"\b(set|set_deferred|set_indexed|call|callv|call_deferred|set_script)\s*\(|\bCallable\s*\(|\bExpression\b",
		"不能用 set() / call() 這類方法繞過 API"],
	[r"\b(free|queue_free|add_child|remove_child|reparent)\s*\(",
		"不能新增、移除或刪除節點"],
	[r"\b(randi|randf|randi_range|randf_range|randfn|randomize|seed)\s*\(|\.(pick_random|shuffle)\s*\(|\bRandomNumberGenerator\b",
		"不能用內建隨機（結果會不固定），請用 random_int() / random_pick()"],
	[r"\bBoss\b",
		"學員的角色不能用 Boss 類別"],
]
const FRAME_FORBIDDEN := r"\b(deal_damage|heal|buff_attack|summon_token|say|poison|shield|drain|curse)\s*\("
# 指定 hp、max_hp、attack、grid_position、school、能量、護盾、詛咒（包含 enemy.hp = 0 這種）；== 是比較，不算
const STAT_WRITE := r"(^|[^\w.])((?:\w+\.)*)(hp|max_hp|attack|grid_position|school|energy|energy_regen|shield_points|curse_points)\s*([-+*/%]?=)(?!=)"
# 只有框架能改的狀態，連 _init() 裡也不能改
const FRAMEWORK_ONLY: Array[String] = ["energy", "energy_regen", "shield_points", "curse_points"]


## 檢查 teams/<github>/：先掃描整個資料夾的程式碼，通過了才執行 team.gd 和角色的 _init()
static func check_team_folder(github: String) -> Array[String]:
	var errors: Array[String] = []
	var dir: String = Rules.team_dir(github)
	if github == "" or not DirAccess.dir_exists_absolute(dir):
		errors.append("找不到隊伍資料夾 %s" % _short(dir))
		return errors
	errors.append_array(scan_folder(dir))
	if not errors.is_empty():
		return errors

	if not ResourceLoader.exists(Team.path_of(github)):
		errors.append("找不到 %s，可以照 teams/example/team.gd 寫一個" % _short(Team.path_of(github)))
		return errors
	var team: Team = Team.load_folder(github)
	if team == null:
		errors.append("%s 要 extends Team" % _short(Team.path_of(github)))
		return errors
	if team.github != github:
		errors.append("%s：github 要寫 \"%s\"（和資料夾名稱一樣），現在是 \"%s\""
				% [_short(Team.path_of(github)), github, team.github])
	errors.append_array(check_team(team.members, dir))
	return errors


## 檢查角色腳本：先確認都在自己的資料夾裡才執行 _init()，建立出來的角色交給 check_units()
static func check_team(members: Array, dir: String) -> Array[String]:
	var errors: Array[String] = []
	for i: int in members.size():
		var script: Script = members[i] as Script
		if script == null:
			errors.append("members 第 %d 個不是角色腳本" % (i + 1))
		elif not script.resource_path.begins_with(dir + "/"):
			errors.append("%s：角色要放在自己的資料夾 %s/ 裡" % [_short(script.resource_path), _short(dir)])
	if not errors.is_empty():
		return errors
	var units: Array = []
	for script: Script in members:
		units.append(script.new())
	errors = check_units(units, dir)
	for unit: Object in units:
		if unit is Node:
			(unit as Node).free()
	return errors


## 檢查 Battle 實際建立的那一隊。學員的 _init() 每次執行的結果可能不一樣，check_team_folder()
## 檢查過的不一定是上場的這一批，所以 Battle.new() 之後、start() 之前要再檢查一次
static func check_side(battle: Battle, side: int, github: String) -> Array[String]:
	return check_units(battle.created[side], Rules.team_dir(github))


## 檢查建立出來的角色：要在自己的資料夾裡、數值範圍、站位、預算、同一個角色檔只能上場一次。
## units 照 members 的順序，裡面可能有 null 或不是 Unit 的東西；這裡不能假設型別，出錯中斷就等於通過
static func check_units(units: Array, dir: String) -> Array[String]:
	var errors: Array[String] = []
	if units.is_empty():
		errors.append("隊伍是空的，請在 team.gd 的 members 加入角色")
		return errors
	if units.size() > Rules.MAX_UNITS:
		errors.append("隊伍最多 %d 隻，現在有 %d 隻" % [Rules.MAX_UNITS, units.size()])

	var total: int = 0
	var receipt: Array[String] = []
	var used: Dictionary = {}       # 格子 -> 站在那裡的角色名稱
	var seen: Dictionary = {}       # 已經上場的角色腳本
	for i: int in units.size():
		var unit: Object = units[i]
		var script: Script = null
		if unit != null:
			script = unit.get_script() as Script
		if script == null:
			errors.append("members 第 %d 個不是角色腳本" % (i + 1))
			continue
		if not script.resource_path.begins_with(dir + "/"):
			errors.append("%s：角色要放在自己的資料夾 %s/ 裡" % [_short(script.resource_path), _short(dir)])
			continue
		if not unit is Unit:
			errors.append("%s 要 extends Unit 或某個職業" % _short(script.resource_path))
			continue
		if seen.has(script):
			errors.append("%s：同一個角色檔只能上場一次，要兩隻一樣的就再寫一個檔案繼承它" % _short(script.resource_path))
			continue
		seen[script] = true
		if unit is Boss:
			errors.append("%s 不能繼承 Boss" % _short(script.resource_path))
		var label: String = "%s（%s）" % [unit.unit_name, _short(script.resource_path)]
		if unit.max_hp < Rules.MAX_HP_MIN or unit.max_hp > Rules.MAX_HP_MAX:
			errors.append("%s：max_hp 要在 %d–%d 之間，現在是 %d"
					% [label, Rules.MAX_HP_MIN, Rules.MAX_HP_MAX, unit.max_hp])
		if unit.attack < Rules.ATTACK_MIN or unit.attack > Rules.ATTACK_MAX:
			errors.append("%s：attack 要在 %d–%d 之間，現在是 %d"
					% [label, Rules.ATTACK_MIN, Rules.ATTACK_MAX, unit.attack])
		if unit.school < 0 or unit.school >= Rules.SCHOOL_NAMES.size():
			errors.append("%s：school 要是 School.NONE、VENOM、AEGIS、BLOOD、NECRO 其中一個" % label)
		var cell: Vector2i = unit.grid_position
		if not Rules.is_valid_cell(cell):
			errors.append("%s：請在 _init() 設定 grid_position = Vector2i(行, 排)，行是左右、排是前後，都要是 0–2，現在是 Vector2i(%d, %d)"
					% [label, cell.x, cell.y])
		elif used.has(cell):
			errors.append("%s：和 %s 站在同一格 %s，請換一個空格（陣型預覽的空格上有寫座標）"
					% [label, used[cell], Rules.cell_label(cell)])
		else:
			used[cell] = unit.unit_name
		var cost: int = Rules.unit_cost(unit.max_hp, unit.attack)
		total += cost
		receipt.append("%s %d+2×%d=%d" % [unit.unit_name, unit.max_hp, unit.attack, cost])

	if total > Rules.BUDGET:
		errors.append("總花費 %d 點，超過預算 %d 點：%s" % [total, Rules.BUDGET, "、".join(receipt)])
	return errors


## 只掃描程式碼、不執行；資料夾裡每個 .gd 都要通過
static func scan_folder(dir: String) -> Array[String]:
	var errors: Array[String] = []
	for path: String in gd_files(dir):
		errors.append_array(check_source(path))
	return errors


## 資料夾裡（包含子資料夾）所有 .gd 檔
static func gd_files(dir: String) -> Array[String]:
	var files: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.ends_with(".gd"):
			files.append("%s/%s" % [dir, file_name])
	for sub: String in DirAccess.get_directories_at(dir):
		files.append_array(gd_files("%s/%s" % [dir, sub]))
	return files


## 總花費明細，例如「騎士 28 + 史萊姆 18 = 46 / 100」；units 是通過 check_side() 的 Battle.created
static func describe_cost(units: Array) -> String:
	var parts: Array[String] = []
	var total := 0
	for unit: Unit in units:
		var cost := Rules.unit_cost(unit.max_hp, unit.attack)
		parts.append("%s %d" % [unit.unit_name, cost])
		total += cost
	return "%s = %d / %d 點" % [" + ".join(parts), total, Rules.BUDGET]


static func check_source(path: String) -> Array[String]:
	var errors: Array[String] = []
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		errors.append("讀不到 %s" % _short(path))
		return errors

	var lines := text.split("\n")
	var func_name := ""       # 現在在哪個函式本體裡，"" 代表不在函式裡
	var func_indent := -1
	var func_regex := RegEx.create_from_string(r"^(\s*)(static\s+)?func\s+(\w+)")
	var stat_regex := RegEx.create_from_string(STAT_WRITE)
	var path_regex := RegEx.create_from_string(r"\b(preload|extends)\s*\(?\s*\"([^\"]*)\"")
	# 學員的檔案只能用自己隊伍資料夾 teams/<帳號>/ 裡的東西
	var team_root: String = Rules.team_dir(path.trim_prefix(Rules.TEAMS_DIR + "/").get_slice("/", 0))
	var frame_regex := RegEx.create_from_string(FRAME_FORBIDDEN)
	for i in lines.size():
		var code := _strip(lines[i])
		if code.strip_edges() == "":
			continue
		var indent := code.length() - code.lstrip(" \t").length()
		if func_indent >= 0 and indent <= func_indent:
			func_name = ""
			func_indent = -1
		var func_match := func_regex.search(code)
		if func_match:
			func_name = func_match.get_string(3)
			func_indent = func_match.get_string(1).length()

		var where := "%s 第 %d 行" % [_short(path), i + 1]
		for rule in BANNED:
			var found: RegExMatch = RegEx.create_from_string(rule[0]).search(code)
			if found:
				var word: String = found.get_string(1) if found.get_group_count() >= 1 and found.get_string(1) != "" else found.get_string()
				errors.append("%s：%s" % [where, rule[1].replace("{0}", word)])
		# 下面兩項要連字串內容一起看
		var raw: String = _strip(lines[i], true)
		if not code.contains("_framework") and raw.contains("_framework"):
			errors.append("%s：不能碰框架內部（_framework 開頭的東西）" % where)
		for path_match: RegExMatch in path_regex.search_all(raw):
			var target: String = path_match.get_string(2)
			var resolved: String = target if target.begins_with("res://") \
					else path.get_base_dir().path_join(target).simplify_path()
			if not resolved.begins_with(team_root + "/"):
				errors.append("%s：只能用自己資料夾 %s/ 裡的檔案，不能用 %s" % [where, _short(team_root), target])
		if func_name == "on_frame" and frame_regex.search(code):
			errors.append("%s：on_frame 只能做畫面效果，不能呼叫戰鬥 API" % where)
		var stat_match: RegExMatch = stat_regex.search(code)
		var statement: String = code.strip_edges()
		var stat: String = stat_match.get_string(3) if stat_match else ""
		if stat_match and not func_match and not statement.begins_with("var ") and not statement.begins_with("const ") \
				and (func_name != "_init" or FRAMEWORK_ONLY.has(stat)):
			if FRAMEWORK_ONLY.has(stat):
				errors.append("%s：%s%s 只有框架能改；護盾請用 shield()、詛咒請用 curse()，能量每回合會自己回復"
						% [where, stat_match.get_string(2), stat])
			else:
				var fix: String = "站位只能在 _init() 設定，戰鬥中不能移動" if stat == "grid_position" \
						else "流派只能在 _init() 設定" if stat == "school" \
						else "戰鬥中請用 deal_damage()、heal()、buff_attack()"
				errors.append("%s：%s%s 只能在 _init() 裡設定；%s" % [where, stat_match.get_string(2), stat, fix])
	return errors


## 去掉註解和字串內容，避免誤判；keep_strings = true 時保留字串內容
static func _strip(line: String, keep_strings: bool = false) -> String:
	var result := ""
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if quote != "":
			if c == "\\":
				i += 1
				if keep_strings and i < line.length():
					result += c + line[i]
			elif c == quote:
				quote = ""
				result += c
			elif keep_strings:
				result += c
		elif c == "\"" or c == "'":
			quote = c
			result += c
		elif c == "#":
			break
		else:
			result += c
		i += 1
	return result


static func _short(path: String) -> String:
	return path.trim_prefix("res://")
