extends SceneTree
## 流派平衡測試：讓隊伍兩兩對戰，每個組合打很多場，印出勝率矩陣。
##
##   godot --headless --script res://tools/balance.gd                        # 四個流派範例，每組 100 場
##   godot --headless --script res://tools/balance.gd -- 帳號A 帳號B 帳號C    # 指定隊伍
##   godot --headless --script res://tools/balance.gd -- --games=200
##
## 每一場用不同的種子：種子決定先手，也是 random_int() / random_pick() 的種子。
## 隊伍都沒用隨機的話，同一組對戰只會有「A 先手」「B 先手」兩種結果，勝率會接近這兩種結果的平均。
## 整體勝率超過 HIGH 或低於 LOW 的流派會被標出來。

const DEFAULT_TEAMS: Array[String] = ["example_venom", "example_aegis", "example_blood", "example_necro"]
const DEFAULT_GAMES := 100
const HIGH := 0.65
const LOW := 0.35


func _init() -> void:
	var teams: Array[String] = []
	var games: int = DEFAULT_GAMES
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			games = maxi(1, arg.trim_prefix("--games=").to_int())
		else:
			teams.append(arg)
	if teams.is_empty():
		teams = DEFAULT_TEAMS.duplicate()

	var members: Dictionary = {}     # 帳號 -> Array[Script]
	for github: String in teams:
		var errors: Array[String] = Validator.check_team_folder(github)
		if not errors.is_empty():
			print("✗ %s 沒有通過檢查：" % github)
			for error: String in errors:
				print("    ", error)
			quit(1)
			return
		members[github] = Team.load_folder(github).members

	# wins[a][b]：a 對 b 贏了幾場
	var wins: Dictionary = {}
	var stats: Dictionary = {}       # 帳號 -> {"wins", "games"}
	for github: String in teams:
		wins[github] = {}
		stats[github] = {"wins": 0, "games": 0}
	var first_wins: int = 0
	var timeouts: int = 0
	var total_rounds: int = 0
	var total_games: int = 0

	for i: int in teams.size():
		for j: int in range(i + 1, teams.size()):
			var a: String = teams[i]
			var b: String = teams[j]
			wins[a][b] = 0
			wins[b][a] = 0
			for game: int in games:
				var battle: Battle = _play(a, b, members[a], members[b], Rules.SEED + game)
				if battle == null:
					quit(1)
					return
				var winner: String = battle.side_names[battle.winner]
				var loser: String = b if winner == a else a
				wins[winner][loser] += 1
				stats[winner]["wins"] += 1
				stats[a]["games"] += 1
				stats[b]["games"] += 1
				if battle.winner == battle.first_team:
					first_wins += 1
				if battle.result_reason.begins_with("超過"):
					timeouts += 1
				total_rounds += battle.round_number
				total_games += 1

	_print_report(teams, members, wins, stats, games)
	if total_games > 0:
		print("")
		print("共 %d 場：先手勝率 %d%%，平均 %.1f 回合，打到第 %d 回合比血量的有 %d 場" % [total_games,
				roundi(100.0 * first_wins / total_games), float(total_rounds) / total_games, Rules.MAX_ROUNDS, timeouts])
	quit(0)


## 打一場：seed 決定先手和隨機數。上場的角色沒通過檢查就回傳 null
func _play(left: String, right: String, left_members: Array, right_members: Array, match_seed: int) -> Battle:
	var left_scripts: Array[Script] = []
	left_scripts.assign(left_members)
	var right_scripts: Array[Script] = []
	right_scripts.assign(right_members)
	var battle: Battle = Battle.new(left_scripts, right_scripts)
	var errors: Array[String] = []
	for side: int in [Battle.PLAYER, Battle.ENEMY]:
		var github: String = [left, right][side]
		for error: String in Validator.check_side(battle, side, github):
			errors.append("%s：%s" % [github, error])
	if not errors.is_empty():
		print("✗ %s vs %s：上場的角色沒有通過檢查：" % [left, right])
		for error: String in errors:
			print("    ", error)
		for unit: Unit in battle.roster:
			unit.free()
		return null
	battle.setup_versus(left, right)
	var coin: RandomNumberGenerator = RandomNumberGenerator.new()
	coin.seed = match_seed
	battle.first_team = coin.randi() % 2
	battle.rng.seed = match_seed
	battle.start()
	while battle.result == "":
		battle.step()
	for unit: Unit in battle.roster:
		unit.free()
	return battle


func _print_report(teams: Array[String], members: Dictionary, wins: Dictionary, stats: Dictionary, games: int) -> void:
	var labels: Dictionary = {}
	for github: String in teams:
		labels[github] = "%s %s" % [_school_label(members[github]), github]

	print("")
	print("## 勝率矩陣（列對上欄的勝率，每格 %d 場）" % games)
	print("")
	var header: String = "| |"
	var line: String = "|---|"
	for github: String in teams:
		header += " %s |" % labels[github]
		line += "---|"
	print(header)
	print(line)
	for a: String in teams:
		var row: String = "| %s |" % labels[a]
		for b: String in teams:
			row += " — |" if a == b else " %d%% |" % roundi(100.0 * wins[a][b] / games)
		print(row)

	print("")
	print("## 整體勝率")
	print("")
	print("| 隊伍 | 勝場 | 勝率 | |")
	print("|---|---|---|---|")
	for github: String in teams:
		var played: int = stats[github]["games"]
		var rate: float = float(stats[github]["wins"]) / maxf(1.0, played)
		var flag: String = ""
		if rate > HIGH:
			flag = "⚠ 太強（超過 %d%%）" % roundi(HIGH * 100.0)
		elif rate < LOW:
			flag = "⚠ 太弱（低於 %d%%）" % roundi(LOW * 100.0)
		print("| %s | %d / %d | %d%% | %s |" % [labels[github], stats[github]["wins"], played, roundi(rate * 100.0), flag])


## 隊伍裡最多的流派，例如「🧪 劇毒」；沒有流派就是「無流派」
func _school_label(scripts: Array) -> String:
	var counts: Array[int] = []
	counts.resize(Rules.SCHOOL_NAMES.size())
	for script: Script in scripts:
		var unit: Unit = script.new()
		counts[clampi(unit.school, 0, counts.size() - 1)] += 1
		unit.free()
	var best: int = 0
	for school: int in range(1, counts.size()):
		if counts[school] > counts[best] or (best == 0 and counts[school] > 0):
			best = school
	return "無流派" if best == 0 else "%s %s" % [Rules.SCHOOL_ICONS[best], Rules.SCHOOL_NAMES[best]]
