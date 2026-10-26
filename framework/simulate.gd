extends SceneTree
## 無畫面模擬：
##   godot --headless --script res://framework/simulate.gd                    # example 打木樁
##   godot --headless --script res://framework/simulate.gd -- 帳號            # 指定隊伍（teams/ 底下的資料夾）
##   godot --headless --script res://framework/simulate.gd -- 帳號 lv3        # 指定隊伍和 Boss
##   godot --headless --script res://framework/simulate.gd -- 帳號A vs 帳號B  # 隊伍對戰
##
## 打 Boss 的結束代碼：0 勝利、2 落敗、1 隊伍沒通過檢查。
## 隊伍對戰最後一行會印出 JSON 結果，給賽程工具讀：
##   {"left": "帳號A", "right": "帳號B", "first": "帳號A", "winner": "帳號B", "rounds": 12, "reason": "..."}
## 對戰結束代碼：0 分出勝負（包含一方沒通過檢查而不戰而勝）、1 兩隊都沒通過檢查。


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 3 and args[1] == "vs":
		quit(_versus(args[0], args[2]))
	else:
		quit(_boss(args[0] if args.size() >= 1 else Rules.DEFAULT_TEAM,
				args[1] if args.size() >= 2 else Rules.DEFAULT_BOSS))


func _boss(github: String, boss_key: String) -> int:
	var errors: Array[String] = []
	if not Rules.BOSSES.has(boss_key):
		errors.append("Boss 要是 %s 其中一個，現在是 \"%s\"" % [", ".join(Rules.BOSSES.keys()), boss_key])
	else:
		errors = Validator.check_team_folder(github)
	var team: Team = null
	var battle: Battle = null
	if errors.is_empty():
		team = Team.load_folder(github)
		battle = Battle.new(team.members, [load(Rules.BOSSES[boss_key]) as Script])
		errors = Validator.check_side(battle, Battle.PLAYER, github)
	if not errors.is_empty():
		for error: String in errors:
			print("✗ ", error)
		if battle != null:
			_free(battle)
		return 1

	print("%s vs %s：%s" % [team.label(), boss_key, Validator.describe_cost(battle.created[Battle.PLAYER])])
	_play(battle)
	return 0 if battle.result == "win" else 2


func _versus(left: String, right: String) -> int:
	var report: Dictionary = {"left": left, "right": right, "first": "", "winner": "", "rounds": 0, "reason": ""}
	var sides: Array[String] = [left, right]
	var bad: Array[String] = []
	for github: String in sides:
		_mark_bad(github, Validator.check_team_folder(github), bad)
	var left_team: Team = null
	var right_team: Team = null
	var battle: Battle = null
	if bad.is_empty():
		left_team = Team.load_folder(left)
		right_team = Team.load_folder(right)
		battle = Battle.new(left_team.members, right_team.members)
		for side: int in [Battle.PLAYER, Battle.ENEMY]:
			_mark_bad(sides[side], Validator.check_side(battle, side, sides[side]), bad)

	if bad.size() == 2:
		report["reason"] = "兩隊都沒有通過檢查"
	elif bad.size() == 1:
		report["winner"] = right if bad[0] == left else left
		report["reason"] = "%s 沒有通過檢查，不戰而勝" % bad[0]
	else:
		battle.setup_versus(left, right)
		print("%s：%s" % [left_team.label(), Validator.describe_cost(battle.created[Battle.PLAYER])])
		print("%s：%s" % [right_team.label(), Validator.describe_cost(battle.created[Battle.ENEMY])])
		_play(battle)
		report["first"] = battle.side_names[battle.first_team]
		report["winner"] = battle.side_names[battle.winner]
		report["rounds"] = battle.round_number
		report["reason"] = battle.result_reason
	if not bad.is_empty() and battle != null:
		_free(battle)

	print(JSON.stringify(report))
	return 1 if bad.size() == 2 else 0


func _play(battle: Battle) -> void:
	var tags: RegEx = RegEx.create_from_string(r"\[/?(b|i|u|color)(=[^\]]*)?\]")
	battle.logged.connect(func(text: String) -> void:
		print(tags.sub(text, "", true).replace("[lb]", "[").replace("[rb]", "]")))
	battle.start()
	while battle.result == "":
		battle.step()
	_free(battle)


func _mark_bad(github: String, errors: Array[String], bad: Array[String]) -> void:
	for error: String in errors:
		print("✗ %s：%s" % [github, error])
	if not errors.is_empty():
		bad.append(github)


func _free(battle: Battle) -> void:
	for unit: Unit in battle.roster:
		unit.free()
