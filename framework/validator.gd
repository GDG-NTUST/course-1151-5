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
	# GDScript、JSON.to_native()、ConfigFile.parse() 都能從字串產生並執行沒被掃描過的程式
	[r"\b(OS|FileAccess|DirAccess|ResourceLoader|ResourceSaver|ClassDB|Engine|EngineDebugger|ProjectSettings|JavaScriptBridge|Thread|Mutex|Semaphore|WorkerThreadPool|HTTPRequest|HTTPClient|StreamPeer\w*|PacketPeer\w*|WebSocket\w*|WebRTC\w*|ENet\w*|IP|Marshalls|Input|InputMap|DisplayServer|Performance|GDExtension\w*|GDScript|JSON|ConfigFile|\w+Server(2D|3D)?)\b",
		"不能使用 {0}（系統、檔案、網路和引擎的功能都不能用）"],
	[r"\b(load|instance_from_id|str_to_var|bytes_to_var_with_objects|get_script|get_property_list|get_method_list)\s*\(",
		"不能用 {0}()，要用自己資料夾裡的檔案請寫 preload(\"檔名.gd\")"],
	[r"\"\"\"|'''",
		"不能用三個引號的多行字串"],
	[r"\bget_tree\b|\bget_node\w*|\bget_parent\b|\bget_child(ren)?\b|\bfind_(child|children|parent)\b|\b(get_)?owner\b|\bget_(viewport|window)\b|\$[\w\"]",
		"不能用 get_tree / get_node 這類方法去抓別的物件，請用 get_allies() / get_enemies()"],
	[r"\b_framework",
		"不能碰框架內部（_framework 開頭的東西）"],
	# 用名稱存取屬性或方法的寫法；不加括號也擋，因為 [x].reduce(enemy.set, "名稱") 這種寫法也會呼叫它
	[r"\b(set|set_deferred|set_indexed|set_thread_safe|set_deferred_thread_group|get_indexed|call|callv|call_deferred|call_thread_safe|call_deferred_thread_group|propagate_call|create_tween|set_script|script|source_code|inst_to_dict|dict_to_inst|var_to_str|decode_var)\b|\bCallable\s*[(.]|\bExpression\b",
		"不能用 {0}（set()、call()、get() 這類用名稱存取的寫法會繞過 API）"],
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
# 敘述開頭（或 : ; 後面）被指定的目標，例如 enemy.charging、get_allies()[0].mood、o.memory[k]；== 是比較，不算
const ASSIGN_TARGET := r"(?:^|[:;])\s*((?:\w+|\((?:[^()]|\([^()]*\))*\)|\[[^\[\]]*\])(?:\.\w+|\((?:[^()]|\([^()]*\))*\)|\[[^\[\]]*\])*)\s*(?:\*\*|<<|>>|[-+*/%&|^])?=(?!=)"
# 改成員前先拿掉不是指定的冒號：函式參數 func f(a: X.Y = 1)、型別標註 var s: Unit.School = …
const FUNC_PARAMS := r"\bfunc\b[^(]*\((?:[^()]|\([^()]*\))*\)"
const VAR_TYPE := r"\b((?:var|const)\s+\w+)\s*:(?!=)[^=;]*"
const GROUPS := r"\((?:[^()]|\([^()]*\))*\)|\[[^\[\]]*\]"
# 自己的向量、顏色可以改分量：position.y、modulate.a、區域變數 v.x
const COMPONENTS: Array[String] = ["x", "y", "z", "w", "r", "g", "b", "a", "h", "s", "v", "r8", "g8", "b8", "a8"]
# enemy[名稱] 和 enemy.get(名稱) 會用執行時才組出來的名稱存取物件（"_frame" + "work_dead"），
# 文字掃描擋不住名稱，所以 [] 裡只能放確定是整數的東西；宣告成 Array / Dictionary 的變數不會是物件，怎麼取都可以
const SUBSCRIPT_MESSAGE := "[] 裡只能放整數或宣告成 int 的變數（例如 enemies[0]、enemies[i]，i 要寫成 var i: int 或 for i: int in ...）；Dictionary 要宣告型別：var d: Dictionary = {}"
const GET_MESSAGE := "只有宣告成 Dictionary 的變數能用 get()（例如 var d: Dictionary = {}），不能用名稱讀別的物件的屬性"
const NOT_SUBSCRIPT: Array[String] = ["Array", "Dictionary", "return", "in", "and", "or", "not", "if", "elif", "else", "while", "match", "when", "await", "is", "as"]


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

	var lines := _logical_lines(text)
	var kinds := _typed_names(lines)
	var func_name := ""       # 現在在哪個函式本體裡，"" 代表不在函式裡
	var func_indent := -1
	var func_regex := RegEx.create_from_string(r"^(\s*)(static\s+)?func\s+(\w+)")
	var stat_regex := RegEx.create_from_string(STAT_WRITE)
	var path_regex := RegEx.create_from_string(r"\b(preload|extends)\s*\(?\s*\"([^\"]*)\"")
	# 學員的檔案只能用自己隊伍資料夾 teams/<帳號>/ 裡的東西
	var team_root: String = Rules.team_dir(path.trim_prefix(Rules.TEAMS_DIR + "/").get_slice("/", 0))
	var frame_regex := RegEx.create_from_string(FRAME_FORBIDDEN)
	var framework_methods := _framework_methods()
	for line: Array in lines:
		var code: String = line[1]
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

		var where := "%s 第 %d 行" % [_short(path), line[0] + 1]
		if func_match and framework_methods.has(func_name):
			errors.append("%s：不能改寫框架的 %s()，只能覆寫 on_ 開頭的事件和射手的 choose_target()" % [where, func_name])
		for rule in BANNED:
			var found: RegExMatch = RegEx.create_from_string(rule[0]).search(code)
			if found:
				var word: String = found.get_string(1) if found.get_group_count() >= 1 and found.get_string(1) != "" else found.get_string()
				errors.append("%s：%s" % [where, rule[1].replace("{0}", word)])
		var access: String = _check_access(code, kinds)
		if access != "":
			errors.append("%s：%s" % [where, access])
		# 下面兩項要連字串內容一起看
		var raw: String = line[2]
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
		var member: String = _member_write(code)
		if member != "" and not stat_match:
			errors.append("%s：不能改別的角色或物件的 %s，只能改自己的變數；向量、顏色可以改分量，例如 position.y"
					% [where, member])
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


## get_enemies() 拿到的是角色本身，enemy.charging = false 會直接改到 Boss 或別隊的狀態。
## 這行有指定別的物件的成員就回傳那個目標，只改自己（self.x、x、v.x 這種分量）回傳 ""
static func _member_write(code: String) -> String:
	var line := RegEx.create_from_string(FUNC_PARAMS).sub(code, "func()", true)
	line = RegEx.create_from_string(VAR_TYPE).sub(line, "$1 ", true)
	var groups := RegEx.create_from_string(GROUPS)
	for found: RegExMatch in RegEx.create_from_string(ASSIGN_TARGET).search_all(line):
		var target: String = found.get_string(1).trim_prefix("self.")
		var parts: PackedStringArray = groups.sub(target, "", true).split(".")
		if parts.size() == 1 or (parts.size() == 2 and COMPONENTS.has(parts[1]) and target.begins_with(parts[0] + ".")):
			continue
		return found.get_string(1)
	return ""


## Unit 提供的方法（is_alive()、get_enemies()…）。框架和 Boss 會在自己的事件裡呼叫別隻角色的這些方法，
## 學員改寫的話，程式就會用 Boss 的身分執行，所以不能改寫
static func _framework_methods() -> Array[String]:
	var names: Array[String] = []
	for method: Dictionary in (Unit as Script).get_script_method_list():
		var method_name: String = method.name
		if not method_name.begins_with("on_") and not method_name.begins_with("_") and not method_name.begins_with("@"):
			names.append(method_name)
	return names


## 把程式碼切成 Godot 眼中的一行：括號裡的換行、行尾的 \（字串裡也算）都接成同一行，去掉註解。
## 不然 enemy.set \ 換行 (...) 或 "...\ 換行 ..." 就能把字拆開躲過掃描。
## 回傳 [[開始的行號（0 起算）, 去掉字串內容的程式碼, 保留字串內容的程式碼], ...]
static func _logical_lines(text: String) -> Array:
	text = text.replace("\r\n", "\n")
	var result: Array = []
	var code := ""
	var raw := ""
	var start := 0
	var row := 0
	var depth := 0
	var quote := ""
	var comment := false
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == "\n":
			row += 1
			comment = false
			quote = ""          # 字串沒有用 \ 接續就換行，Godot 會當成語法錯誤
			if depth > 0:
				code += " "
				raw += " "
			else:
				result.append([start, code, raw])
				code = ""
				raw = ""
				start = row
		elif comment:
			pass
		elif c == "\\":
			i += 1
			if i < text.length() and text[i] == "\n":
				row += 1        # 接續下一行，不算換行
			elif quote != "" and i < text.length():
				raw += c + text[i]
		elif c == "\r":
			code += " "
			raw += " "
		elif quote != "":
			if c == quote:
				quote = ""
				code += c
			raw += c
		elif c == "\"" or c == "'":
			quote = c
			code += c
			raw += c
		elif c == "#":
			comment = true
		else:
			code += c
			raw += c
			if c in "([{":
				depth += 1
			elif c in ")]}":
				depth = maxi(depth - 1, 0)
		i += 1
	result.append([start, code, raw])
	return result


## 檔案裡每個變數、參數宣告成什麼："int"、"container"（Array / Dictionary），其他是 ""。
## 同一個名稱在檔案裡每一處宣告都一樣才算數（不同函式裡可能有同名的 String 變數）
static func _typed_names(lines: Array) -> Dictionary:
	var kinds: Dictionary = {}
	var decl := RegEx.create_from_string(r"\b(?:var|const|for)\s+(\w+)(?=([^;]*))")
	var params := RegEx.create_from_string(r"\bfunc\b\s*\w*\s*\(")
	var param := RegEx.create_from_string(r"^\s*(\w+)(.*)$")
	for line: Array in lines:
		var code: String = line[1]
		var found: Array = []      # [名稱, 名稱後面的型別和初始值]
		for m: RegExMatch in decl.search_all(code):
			found.append([m.get_string(1), m.get_string(2)])
		for m: RegExMatch in params.search_all(code):
			# 參數列到對應的右括號為止，用最外層的逗號切開
			var depth := 0
			var part := ""
			for c: String in code.substr(m.get_end()) + ")":
				if c in "([{":
					depth += 1
				elif c in ")]}":
					depth -= 1
				if depth < 0 or (c == "," and depth == 0):
					var p: RegExMatch = param.search(part)
					if p:
						found.append([p.get_string(1), p.get_string(2)])
					part = ""
					if depth < 0:
						break
				else:
					part += c
		for item: Array in found:
			var kind := _kind(item[1])
			kinds[item[0]] = kind if kinds.get(item[0], kind) == kind else ""
	return kinds


static func _kind(tail: String) -> String:
	if RegEx.create_from_string(r"^\s*(:\s*int\b|:=\s*-?\d[\d_]*\s*$)").search(tail):
		return "int"
	if RegEx.create_from_string(r"^\s*(:\s*(Array|Dictionary|Packed\w+Array)\b|:=\s*(\[\s*\]|\{\s*\})\s*$)").search(tail):
		return "container"
	return ""


## [] 和 get()：會不會用名稱存取物件。回傳錯誤訊息，"" 代表沒問題
static func _check_access(code: String, kinds: Dictionary) -> String:
	for m: RegExMatch in RegEx.create_from_string(r"(?:(?<![.\w])(\w+)\s*\.\s*)?\bget\b").search_all(code):
		if kinds.get(m.get_string(1), "") != "container":
			return GET_MESSAGE
	var receiver_regex := RegEx.create_from_string(r"(\.\s*)?(\w+)$")
	var name_regex := RegEx.create_from_string(r"(\.\s*)?\b([A-Za-z_]\w*)\b(\s*\()?")
	var int_chars := RegEx.create_from_string(r"^[\d_\s+\-*/%()]*$")
	var open := code.find("[")
	while open >= 0:
		var before := code.substr(0, open).rstrip(" \t")
		var receiver: RegExMatch = receiver_regex.search(before)
		var is_subscript: bool = before != "" and (before.right(1) in ")]\"'" \
				or (receiver != null and not NOT_SUBSCRIPT.has(receiver.get_string(2))))
		var close := open + 1
		var depth := 1
		while close < code.length() and depth > 0:
			depth += 1 if code[close] in "([{" else -1 if code[close] in ")]}" else 0
			close += 1
		var index := code.substr(open + 1, close - open - 2)
		var container: bool = receiver != null and receiver.get_string(1) == "" \
				and kinds.get(receiver.get_string(2), "") == "container"
		if is_subscript and not container:
			# [] 裡每個名字都要是 int 變數（不能是函式呼叫、別的物件的屬性），其他只能是數字和運算
			for m: RegExMatch in name_regex.search_all(index):
				if m.get_string(1) != "" or m.get_string(3) != "" or kinds.get(m.get_string(2), "") != "int":
					return SUBSCRIPT_MESSAGE
			if not int_chars.search(name_regex.sub(index, "", true)):
				return SUBSCRIPT_MESSAGE
		open = code.find("[", open + 1)
	return ""


static func _short(path: String) -> String:
	return path.trim_prefix("res://")
