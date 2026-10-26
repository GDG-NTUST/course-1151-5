class_name Battle
extends RefCounted
## 戰鬥流程。純邏輯、不碰畫面，擂台和無畫面模擬共用。
##
## 雙方各有 3×3 棋盤（前排、中排、後排），角色站好就不會移動。
##
## 一回合的順序：
##   1. 每隻角色回復能量（energy_regen 點，最多 ENERGY_MAX）
##   2. Boss 的 on_round_start（這回合的受傷倍率等狀態從這裡開始生效，毒發也算）
##   3. 中毒的角色照行動順序毒發，每層各算一次傷害
##   4. 照行動順序，每隻角色輪流行動：選目標 → 扣血 → 自己的 on_attack → 受傷者的 on_hurt
##   5. 一方全滅就結束；打完 MAX_ROUNDS 回合算挑戰者輸
## 每個動作（一次行動、一層毒發）結束後馬上結算死亡：
##   on_death → 死靈 4 隻的全體傷害 → 隊友的 on_ally_death → 從場上移除（召喚的分身站到原本的格子）
## 死亡引起的連鎖全部結算完，才輪到下一個動作。
##
## 每一次傷害照這個順序結算（_apply_damage）：
##   0. 刺客的閃避：每場第一次被普攻打中時整次不算（不消耗詛咒、護盾，坦克也不分擔）
##   1. 基礎傷害（普攻是 attack，技能是指定的 amount）
##   2. 攻擊者的增傷，只有普攻：狂血 4 隻（血量低於一半 +2）、戰士的衝鋒、射手的弱點射擊；
##      Boss 的受傷倍率也在這一步
##   3. 加上目標身上的詛咒，並消耗詛咒
##   4. 扣護盾（毒傷跳過這一步）
##   5. 坦克分擔：目標相鄰有我方坦克時，坦克承受 TANK_SHARE_PERCENT%（目標本身是坦克時不分擔）
##   6. 扣血；血量歸零的角色在這個動作結束後結算死亡
##
## 能量與流派：
##   - 開場 ENERGY_START 點能量；技能 API 要花能量，不夠就回傳 false、不生效、不扣能量
##   - 流派 API（poison / shield / drain / curse）和施放者同流派是正常價，不同是兩倍價
##   - 流派加成看開場時同流派的隻數（2 隻、4 隻），之後有人陣亡也不會消失；Boss 不用能量
##
## 行動順序固定：玩家隊伍先、Boss 隊伍後；同一隊由前排到後排、每排由左到右。
## 輪到的時候血量已經歸零的角色不會行動。
##
## 隊伍對戰（setup_versus）：
##   - 先手由兩隊的 GitHub 帳號算出來，同一組對戰每次都一樣
##   - 兩隊交錯行動：先手 1 → 後手 1 → 先手 2 → 後手 2 …，一隊沒人了另一隊就繼續
##   - 同時全滅由後手獲勝；超過 MAX_ROUNDS 回合比剩餘血量比例（hp_ratio，分身不算），一樣也是後手獲勝
##
## 職業的攻擊目標（「最前排」指還有活著角色的最前面一排）：
##   戰士、坦克：敵方最前排，優先同一行，沒有就打最近的一行（一樣近打左邊）
##   刺客：敵方最後排，規則同上
##   射手：任何一格，由 Archer.choose_target() 決定（預設血最少）
##   法師：敵方同一行的所有角色；同一行沒人就打最近的一行
##   補師：不攻擊，幫相鄰有受傷的隊友回 attack 點血
##   坦克另外會替相鄰的隊友分擔 TANK_SHARE_PERCENT% 的傷害
##
## 職業被動（數值在 Rules，召喚的分身和 Boss 沒有）：
##   戰士「衝鋒」：每場第一次普攻 +WARRIOR_CHARGE（直接 extends Unit 的角色也算戰士）
##   坦克「掩護」：上面的分擔傷害
##   射手「弱點射擊」：普攻血量低於一半的目標 +ARCHER_WEAK_SPOT
##   法師「法力湧流」：每回合回復 MAGE_ENERGY_REGEN 能量（補師沒有）
##   補師「淨化」：普通治療有回到血時，移除目標 HEALER_CLEANSE 層中毒（被劇毒擋下治療就不會淨化）
##   刺客「閃避」：每場第一次被普攻打中時不受傷害
##
## 規則細節：
##   - 血量歸零的角色只會再觸發 on_death，其他事件都不會觸發
##   - 技能造成的傷害會立刻觸發對方的 on_hurt，連鎖最多 MAX_EVENT_DEPTH 層

signal logged(text: String)
signal unit_added(unit: Unit)
signal unit_died(unit: Unit)
signal unit_damaged(unit: Unit, amount: int)
signal unit_healed(unit: Unit, amount: int)
signal unit_acted(unit: Unit, target: Unit)   # 普攻或治療，畫面拿來做「往目標衝一下」
signal finished(result: String)

const PLAYER := 0
const ENEMY := 1
const TEAM_COLORS := ["#7cc4ff", "#ff8a80"]

var teams: Array = [[], []]   # 兩隊還在場上的角色（Array of Unit），照行動順序排
var roster: Array[Unit] = []  # 這場戰鬥出現過的所有角色（包含陣亡的）
var round_number := 0
var result := ""              # "" 進行中 / "win"（左邊、玩家贏）/ "lose"
var result_reason := ""
var winner := -1              # 贏的那隊 PLAYER / ENEMY；-1 進行中
var versus := false           # true：隊伍對戰
var first_team := PLAYER      # 對戰時的先手
var side_names: Array[String] = ["我方", "Boss"]
var rng := RandomNumberGenerator.new()

# 目前正在執行事件的角色；戰鬥 API 只接受它呼叫
var _actor: Unit = null
var _event := ""
var _calls_left := 0
var _depth := 0
var _tokens := {}         # 死亡的角色 -> 牠召喚的 token 陣列
var _token_budget := {}   # 死亡的角色 -> 剩下的 token 預算
var _start_max_hp := [0, 0]  # 開場時兩隊的 max_hp 總和，比剩餘血量用
var _school_counts: Array = [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0]]  # 開場時兩隊各流派的隻數

# _apply_damage 的傷害種類
const KIND_ATTACK := 0   # 普攻（狂血 4 隻的增傷只對這個有效）
const KIND_SKILL := 1    # 技能
const KIND_POISON := 2   # 毒發（無視護盾）
const KIND_NECRO := 3    # 死靈 4 隻的全體傷害


## 兩隊的角色腳本，每隻站在自己 grid_position 那一格；要先通過 Validator 檢查
func _init(player_scripts: Array[Script], enemy_scripts: Array[Script]) -> void:
	rng.seed = Rules.SEED
	seed(Rules.SEED)
	for script: Script in player_scripts:
		var unit: Unit = script.new()
		_add_unit(unit, PLAYER, unit.grid_position)
	for script: Script in enemy_scripts:
		var unit: Unit = script.new()
		_add_unit(unit, ENEMY, unit.grid_position)
	for unit: Unit in roster:
		_start_max_hp[unit._framework_team] += unit.max_hp
		_school_counts[unit._framework_team][clampi(unit.school, 0, Rules.SCHOOL_NAMES.size() - 1)] += 1


## 改成隊伍對戰；要在 start() 之前呼叫。left 是 PLAYER 那隊、right 是 ENEMY 那隊
func setup_versus(left_github: String, right_github: String) -> void:
	versus = true
	side_names = [left_github, right_github]
	first_team = first_mover(left_github, right_github)


## 用兩隊的帳號決定先手：左右交換結果也一樣，同一組對戰永遠同一隊先手
static func first_mover(left_github: String, right_github: String) -> int:
	if left_github == right_github:
		return PLAYER
	var names: Array[String] = [left_github, right_github]
	names.sort()
	var picked: String = names[absi(("%s|%s" % names).hash()) % 2]
	return PLAYER if picked == left_github else ENEMY


# ---------------------------------------------------------------- 流程

func start() -> void:
	_log("[b]=== 戰鬥開始（種子 %d）===[/b]" % Rules.SEED)
	if versus:
		_log("[b]先手：%s[/b]" % _side(first_team))
	for team: int in [PLAYER, ENEMY]:
		_start_schools(team)
	for unit: Unit in _all_alive():
		_fire(unit, "on_battle_start", [])
	_resolve_deaths()
	_check_end()


func step() -> void:
	if result != "":
		return
	round_number += 1
	_log("[b]— 第 %d 回合 —[/b]" % round_number)

	for unit: Unit in _all_alive():
		if not unit is Boss:
			_write(unit, "energy", mini(Rules.ENERGY_MAX, unit.energy + unit.energy_regen))
	# Boss 先設定這回合的狀態，毒發才會套用這回合（而不是上一回合）的受傷倍率
	for unit: Unit in _all_alive():
		if unit is Boss:
			_fire(unit, "on_round_start", [round_number])
	_resolve_deaths()
	if _team_wiped():
		_check_end()
		return

	for unit: Unit in _turn_order():
		if unit.is_alive() and not unit._framework_poisons.is_empty():
			_tick_poison(unit)
			_resolve_deaths()
	if _team_wiped():
		_check_end()
		return

	for unit: Unit in _turn_order():
		if unit.is_alive():
			_act(unit)
			_resolve_deaths()
			if _team_wiped():
				break
	_check_end()


func _team_wiped() -> bool:
	return get_alive(PLAYER).is_empty() or get_alive(ENEMY).is_empty()


## 開場的流派加成：寫進戰鬥紀錄，聖盾發護盾
func _start_schools(team: int) -> void:
	var parts: Array[String] = []
	for school: int in range(1, Rules.SCHOOL_NAMES.size()):
		var tier: int = school_tier(team, school)
		if tier == 0:
			continue
		var effects: Array[String] = Rules.school_bonus_text(school).slice(0, tier)
		if school == Unit.School.AEGIS:
			effects = [Rules.school_bonus_text(school)[tier - 1]]   # 聖盾 4 隻取代 2 隻的效果
		parts.append("%s%s %d 隻（%s）" % [Rules.SCHOOL_ICONS[school], Rules.SCHOOL_NAMES[school],
				school_count(team, school), "、".join(effects)])
	if parts.is_empty():
		return
	_log("%s 的流派加成：%s" % [_side(team), "；".join(parts)])
	var aegis: int = school_tier(team, Unit.School.AEGIS)
	if aegis > 0:
		var amount: int = Rules.AEGIS_SHIELD[aegis - 1]
		for unit: Unit in get_alive(team):
			_write(unit, "shield_points", mini(Rules.SHIELD_MAX, unit.shield_points + amount))
		_log("%s 聖盾之力：全隊獲得 %d 點護盾" % [_side(team), amount])


## 開場時 team 有幾隻 school 流派的角色
func school_count(team: int, school: int) -> int:
	if school < 0 or school >= Rules.SCHOOL_NAMES.size():
		return 0
	return _school_counts[team][school]


## team 的 school 流派加成等級：0 沒有、1 是 2 隻加成、2 是 4 隻加成
func school_tier(team: int, school: int) -> int:
	if school == Unit.School.NONE:
		return 0
	return Rules.school_tier(school_count(team, school))


## 這回合的行動順序（回合開始時還活著的角色）
func _turn_order() -> Array[Unit]:
	if not versus:
		return _all_alive()
	var first: Array[Unit] = get_alive(first_team)
	var second: Array[Unit] = get_alive(1 - first_team)
	var order: Array[Unit] = []
	for i: int in maxi(first.size(), second.size()):
		if i < first.size():
			order.append(first[i])
		if i < second.size():
			order.append(second[i])
	return order


func _act(unit: Unit) -> void:
	var boss: Boss = unit as Boss
	if boss and boss.skip_attack:
		return
	if unit is Healer:
		_heal_neighbors(unit)
		return

	var targets: Array[Unit] = _pick_targets(unit)
	var amount: int = unit.attack
	if boss and boss.pierce:
		targets = get_alive(1 - unit._framework_team)
		amount = boss.pierce_damage
	if targets.is_empty() or amount <= 0:
		return

	unit_acted.emit(unit, targets[0])
	var hurt: Array = []      # [受傷者, 實際傷害]
	var verb: String = "狂血攻擊" if _fury(unit) else "攻擊"
	for target: Unit in targets:
		hurt.append_array(_apply_damage(target, amount, unit, verb, KIND_ATTACK))
	if unit.is_alive() and school_tier(unit._framework_team, Unit.School.BLOOD) >= 1:
		_restore(unit, Rules.BLOOD_LIFESTEAL, "%s 的狂血之力，回了 %d 血（%d/%d）", unit)
	if unit.is_alive():
		_fire(unit, "on_attack", [targets[0]])
	for entry: Array in hurt:
		if entry[0] is Boss and entry[0].is_alive():
			_fire(entry[0], "on_attacked", [entry[1], unit])
		if entry[0].is_alive():
			_fire(entry[0], "on_hurt", [entry[1], unit])


func _heal_neighbors(healer: Unit) -> void:
	if healer.attack <= 0:
		return
	var first := true
	for ally: Unit in adjacent_allies(healer):
		if ally.hp >= ally.max_hp:
			continue
		if first:
			unit_acted.emit(healer, ally)
			first = false
		if _restore(ally, healer.attack, "%s 治療 %s，回了 %d 血（%d/%d）", healer) > 0:
			_cleanse(healer, ally)


## 補師的淨化：移除最早的 HEALER_CLEANSE 層中毒
func _cleanse(healer: Unit, ally: Unit) -> void:
	var removed: int = mini(Rules.HEALER_CLEANSE, ally._framework_poisons.size())
	if removed <= 0:
		return
	ally._framework_poisons = ally._framework_poisons.slice(removed)
	ally.queue_redraw()
	_log("%s 淨化了 %s 的 %d 層毒（剩 %d 層）" % [_n(healer), _n(ally), removed, ally._framework_poisons.size()])


## 回血（不超過 max_hp），中了劇毒 4 隻的毒就不會回。回傳實際回了多少。
## message 的參數依序是：施放者、目標、回了多少、hp、max_hp；施放者就是目標自己時省略施放者
func _restore(target: Unit, amount: int, message: String, healer: Unit) -> int:
	if _heal_blocked(target):
		_log("%s 中了劇毒，無法被治療" % _n(target))
		return 0
	amount = mini(amount, target.max_hp - target.hp)
	if amount <= 0:
		return 0
	_write(target, "hp", target.hp + amount)
	if healer == target:
		_log(message % [_n(target), amount, target.hp, target.max_hp])
	else:
		_log(message % [_n(healer), _n(target), amount, target.hp, target.max_hp])
	unit_healed.emit(target, amount)
	return amount


## 照職業挑普攻的目標（法師會回傳整行）
func _pick_targets(attacker: Unit) -> Array[Unit]:
	var enemy_team: int = 1 - attacker._framework_team
	var enemies: Array[Unit] = get_alive(enemy_team)
	if enemies.is_empty():
		return []
	var col: int = attacker.grid_position.x

	if attacker is Mage:
		return units_in_column(enemy_team, _nearest_column(enemies, col))

	if attacker is Archer:
		var picked: Unit = (attacker as Archer).choose_target(enemies.duplicate())
		if picked == null or not enemies.has(picked):
			report_violation(attacker, "choose_target() 要回傳一隻還活著的敵人，這次改打 %s" % _n(enemies[0]))
			picked = enemies[0]
		return [picked]

	# 近戰打最前排、刺客打最後排；get_alive 照前排到後排排好
	var row: int = enemies[-1].grid_position.y if attacker is Assassin else enemies[0].grid_position.y
	var in_row: Array[Unit] = units_in_row(enemy_team, row)
	return [in_row[_nearest_index(in_row, col)]]


## units 裡離 col 最近的那隻的索引；一樣近取前面的（units 由左到右排，所以是左邊）
func _nearest_index(units: Array[Unit], col: int) -> int:
	var best: int = 0
	for i: int in units.size():
		if absi(units[i].grid_position.x - col) < absi(units[best].grid_position.x - col):
			best = i
	return best


func _nearest_column(units: Array[Unit], col: int) -> int:
	var best: int = -1
	for unit: Unit in units:
		var c: int = unit.grid_position.x
		if best < 0 or absi(c - col) < absi(best - col) or (absi(c - col) == absi(best - col) and c < best):
			best = c
	return best


func _resolve_deaths() -> void:
	# on_death 裡的技能可能再打死別人，所以重複結算到沒人死為止
	for _i: int in 20:
		var dying: Array[Unit] = []
		for unit: Unit in _all_units():
			if not unit._framework_dead and unit.hp <= 0:
				dying.append(unit)
		if dying.is_empty():
			return
		for unit: Unit in dying:
			unit._framework_dead = true
			_tokens[unit] = []
			_token_budget[unit] = Rules.TOKEN_BUDGET
		for unit: Unit in dying:
			_log("%s 倒下了 qonop" % _n(unit))
			var necro: int = school_tier(unit._framework_team, Unit.School.NECRO) if unit.school == Unit.School.NECRO else 0
			if necro >= 1:
				unit._framework_soul = Rules.NECRO_SOUL
				_log("%s 獲得 %d 點靈魂能量（只能在 on_death 裡用）" % [_n(unit), Rules.NECRO_SOUL])
			_fire(unit, "on_death", [])
			unit._framework_soul = 0
			if necro >= 2:
				_necro_blast(unit)
			for ally: Unit in get_alive(unit._framework_team):
				_fire(ally, "on_ally_death", [unit])
		for unit: Unit in dying:
			teams[unit._framework_team].erase(unit)
			unit_died.emit(unit)
			for token: Unit in _tokens[unit]:
				var cell: Vector2i = _free_cell_near(unit._framework_team, unit.grid_position)
				if cell.x < 0:
					token.free()
					continue
				_add_unit(token, unit._framework_team, cell)
				unit_added.emit(token)
			_tokens.erase(unit)
			_token_budget.erase(unit)


## 離 origin 最近的空格（先看自己那格，再看上下左右，最後照行動順序找）
func _free_cell_near(team: int, origin: Vector2i) -> Vector2i:
	var candidates: Array[Vector2i] = [origin]
	for offset: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		candidates.append(origin + offset)
	for row: int in Rules.GRID_ROWS:
		for col: int in Rules.GRID_COLS:
			candidates.append(Vector2i(col, row))
	for cell: Vector2i in candidates:
		if Rules.is_valid_cell(cell) and _unit_at(team, cell) == null:
			return cell
	return Vector2i(-1, -1)


func _check_end() -> bool:
	if versus:
		return _check_versus_end()
	var players := get_alive(PLAYER).size()
	var enemies := get_alive(ENEMY).size()
	if players == 0 and enemies == 0:
		_finish(ENEMY, "同歸於盡，算挑戰者輸")
	elif enemies == 0:
		_finish(PLAYER, "擊敗了 Boss！")
	elif players == 0:
		_finish(ENEMY, "全隊陣亡")
	elif round_number >= Rules.MAX_ROUNDS:
		_finish(ENEMY, "超過 %d 回合還沒打倒 Boss" % Rules.MAX_ROUNDS)
	return result != ""


func _check_versus_end() -> bool:
	var second: int = 1 - first_team
	var alive: Array[int] = [get_alive(PLAYER).size(), get_alive(ENEMY).size()]
	if alive[PLAYER] == 0 and alive[ENEMY] == 0:
		_finish(second, "同時全滅，後手獲勝")
	elif alive[ENEMY] == 0:
		_finish(PLAYER, "%s 全滅" % side_names[ENEMY])
	elif alive[PLAYER] == 0:
		_finish(ENEMY, "%s 全滅" % side_names[PLAYER])
	elif round_number >= Rules.MAX_ROUNDS:
		var ratios: Array[float] = [hp_ratio(PLAYER), hp_ratio(ENEMY)]
		var reason: String = "超過 %d 回合，比剩餘血量：%s %d%%、%s %d%%" % [Rules.MAX_ROUNDS,
				side_names[PLAYER], roundi(ratios[PLAYER] * 100.0), side_names[ENEMY], roundi(ratios[ENEMY] * 100.0)]
		if is_equal_approx(ratios[PLAYER], ratios[ENEMY]):
			_finish(second, reason + "，一樣多由後手獲勝")
		else:
			_finish(PLAYER if ratios[PLAYER] > ratios[ENEMY] else ENEMY, reason)
	return result != ""


## 剩餘血量比例：還活著的角色目前血量總和 ÷ 開場時的 max_hp 總和。
## 召喚的分身不算（分母沒有牠們，算進來比例會超過 100%）
func hp_ratio(team: int) -> float:
	var total: int = 0
	for unit: Unit in get_alive(team):
		if not unit._framework_token:
			total += unit.hp
	return float(total) / maxf(1.0, _start_max_hp[team])


func _finish(new_winner: int, reason: String) -> void:
	winner = new_winner
	result = "win" if winner == PLAYER else "lose"
	result_reason = reason
	if versus:
		_log("[b]=== %s 獲勝 douob：%s（第 %d 回合）===[/b]" % [_side(winner), reason, round_number])
	else:
		var title := "勝利 douob" if result == "win" else "落敗 qonop"
		_log("[b]=== %s：%s（第 %d 回合）===[/b]" % [title, reason, round_number])
	finished.emit(result)


# ---------------------------------------------------------------- 事件

func _fire(unit: Unit, method: String, args: Array) -> void:
	if _depth >= Rules.MAX_EVENT_DEPTH:
		_log("[color=gray]（連鎖太深，%s 的 %s 被略過）[/color]" % [_n(unit), method])
		return
	var saved := [_actor, _event, _calls_left]
	_actor = unit
	_event = method
	_calls_left = Rules.CALLS_PER_EVENT
	_depth += 1
	unit.callv(method, args)
	_depth -= 1
	_actor = saved[0]
	_event = saved[1]
	_calls_left = saved[2]


## 照「傷害結算順序」扣血（見檔案開頭）。回傳 [[受傷者, 傷害, 實際少掉的血], ...]，
## 全部被護盾擋下的話是空陣列
func _apply_damage(target: Unit, amount: int, source: Unit, verb: String, kind: int = KIND_SKILL) -> Array:
	if not target.is_alive() or amount <= 0:
		return []
	# 0. 刺客的閃避
	if kind == KIND_ATTACK and target is Assassin and target._framework_passive_icon != "":
		target._framework_passive_icon = ""
		target.queue_redraw()
		_log("%s 閃避了 %s 的攻擊！" % [_n(target), _n(source)])
		return []
	# 2. 攻擊者的增傷、Boss 的受傷倍率
	if kind == KIND_ATTACK:
		if _fury(source):
			amount += Rules.BLOOD_FURY
		if _is_warrior(source) and source._framework_passive_icon != "":
			source._framework_passive_icon = ""
			source.queue_redraw()
			amount += Rules.WARRIOR_CHARGE
			verb = "衝鋒" + verb
		elif source is Archer and target.hp * 2 < target.max_hp:
			amount += Rules.ARCHER_WEAK_SPOT
			verb = "弱點" + verb
	var boss := target as Boss
	if boss:
		if kind == KIND_ATTACK and boss.attack_damage_percent != 100:
			amount = amount * boss.attack_damage_percent / 100
		amount *= boss.damage_taken_multiplier
	# 3. 詛咒
	if target.curse_points > 0:
		amount += target.curse_points
		_log("%s 身上的詛咒發作，傷害 +%d" % [_n(target), target.curse_points])
		_write(target, "curse_points", 0)
	# 4. 護盾
	if kind != KIND_POISON and target.shield_points > 0:
		var blocked: int = mini(target.shield_points, amount)
		amount -= blocked
		_write(target, "shield_points", target.shield_points - blocked)
		_log("%s 的護盾擋下 %d 點傷害（護盾剩 %d）" % [_n(target), blocked, target.shield_points])
	# 5. 坦克分擔
	var tank: Unit = null if target is Tank else _guarding_tank(target)
	var shared: int = amount * Rules.TANK_SHARE_PERCENT / 100 if tank else 0
	var taken: int = amount - shared

	# 6. 扣血
	var hurt: Array = []
	var before: int = target.hp
	_write(target, "hp", maxi(0, target.hp - taken))
	_log("%s %s %s，造成 %d 傷害（剩 %d）" % [_n(source), verb, _n(target), taken, target.hp])
	if taken > 0:
		unit_damaged.emit(target, taken)
		hurt.append([target, taken, before - target.hp])
	if shared > 0:
		before = tank.hp
		_write(tank, "hp", maxi(0, tank.hp - shared))
		_log("%s 替 %s 擋下 %d 傷害（剩 %d）" % [_n(tank), _n(target), shared, tank.hp])
		unit_damaged.emit(tank, shared)
		hurt.append([tank, shared, before - tank.hp])
	return hurt


## 算戰士的角色：不是其他職業、不是 Boss、不是召喚的分身（直接 extends Unit 的也算）
func _is_warrior(unit: Unit) -> bool:
	return unit != null and not (unit is Boss or unit is Tank or unit is Archer or unit is Mage or unit is Assassin) \
			and not unit._framework_token


## 狂血 4 隻：血量低於一半的角色普攻 +2
func _fury(unit: Unit) -> bool:
	return unit != null and school_tier(unit._framework_team, Unit.School.BLOOD) >= 2 and unit.hp * 2 < unit.max_hp


## 劇毒 4 隻：中了那一隊的毒的敵人無法被治療
func _heal_blocked(unit: Unit) -> bool:
	for stack: Dictionary in unit._framework_poisons:
		if stack["team"] != unit._framework_team and school_tier(stack["team"], Unit.School.VENOM) >= 2:
			return true
	return false


## 每層毒各算一次傷害（無視護盾）；劇毒 2 隻的隊伍下的毒每次 +VENOM_TICK_BONUS
func _tick_poison(unit: Unit) -> void:
	for stack: Dictionary in unit._framework_poisons.duplicate():
		if not unit.is_alive():
			break
		stack["turns"] -= 1
		var amount: int = stack["amount"]
		if school_tier(stack["team"], Unit.School.VENOM) >= 1:
			amount += Rules.VENOM_TICK_BONUS
		var source: Unit = stack["source"]
		for entry: Array in _apply_damage(unit, amount, source, "的毒侵蝕", KIND_POISON):
			if entry[0].is_alive():
				_fire(entry[0], "on_hurt", [entry[1], source])
	var remaining: Array[Dictionary] = []
	for stack: Dictionary in unit._framework_poisons:
		if stack["turns"] > 0:
			remaining.append(stack)
	unit._framework_poisons = remaining
	unit.queue_redraw()


## 死靈 4 隻：死靈角色的 on_death 結束後，對全體敵人造成 1 點傷害（免費）
func _necro_blast(unit: Unit) -> void:
	var enemies: Array[Unit] = get_alive(1 - unit._framework_team)
	if enemies.is_empty():
		return
	_log("%s 死亡，死靈之力對全體敵人造成 %d 點傷害" % [_n(unit), Rules.NECRO_BLAST])
	var hurt: Array = []
	for enemy: Unit in enemies:
		hurt.append_array(_apply_damage(enemy, Rules.NECRO_BLAST, unit, "的死靈之力波及", KIND_NECRO))
	for entry: Array in hurt:
		if entry[0].is_alive():
			_fire(entry[0], "on_hurt", [entry[1], unit])


## 會替 unit 分擔傷害的坦克：相鄰、還活著、行動順序最前面的那隻
func _guarding_tank(unit: Unit) -> Unit:
	for ally: Unit in adjacent_allies(unit):
		if ally is Tank:
			return ally
	return null


# ---------------------------------------------------------------- 戰鬥 API

func api_deal_damage(caller: Unit, target: Unit, amount: int) -> bool:
	if not _api_begin(caller, "deal_damage") or not _check_target(caller, target, "deal_damage"):
		return false
	amount = _cap(caller, "deal_damage", amount, 1, Rules.DAMAGE_CAP)
	if not _spend(caller, amount, "技能攻擊"):
		return false
	for entry: Array in _apply_damage(target, amount, caller, "用技能打"):
		if entry[0].is_alive():
			_fire(entry[0], "on_hurt", [entry[1], caller])
	return true


func api_heal(caller: Unit, target: Unit, amount: int) -> bool:
	if not _api_begin(caller, "heal") or not _check_target(caller, target, "heal"):
		return false
	amount = _cap(caller, "heal", amount, 1, Rules.HEAL_CAP)
	if target.hp >= target.max_hp:
		_log("%s 想幫 %s 回血，但牠已經滿血了" % [_n(caller), _n(target)])
		return false
	if _heal_blocked(target):
		_log("%s 想幫 %s 回血，但 %s 中了劇毒，無法被治療" % [_n(caller), _n(target), _n(target)])
		return false
	if not _spend(caller, amount, "治療"):
		return false
	_restore(target, amount, "%s 幫 %s 回了 %d 血（%d/%d）" if caller != target else "%s 幫自己回了 %d 血（%d/%d）", caller)
	return true


func api_buff_attack(caller: Unit, target: Unit, amount: int) -> bool:
	if not _api_begin(caller, "buff_attack") or not _check_target(caller, target, "buff_attack"):
		return false
	amount = _cap(caller, "buff_attack", amount, 1, Rules.BUFF_CAP)
	if not caller is Boss:
		amount = mini(amount, Rules.ATTACK_LIMIT - target.attack)
	if amount <= 0:
		_log("%s 想幫 %s 加攻擊，但已經到上限 %d 了" % [_n(caller), _n(target), Rules.ATTACK_LIMIT])
		return false
	var cost: int = amount * Rules.BUFF_ENERGY_PER_POINT
	var paid: String = _cost_note(caller, cost)
	if not _spend(caller, cost, "加攻擊"):
		return false
	_write(target, "attack", target.attack + amount)
	_log("%s 幫 %s 加了 %d 攻擊（變成 %d%s）" % [_n(caller), _n(target), amount, target.attack, paid])
	return true


## 🧪 劇毒：每層毒是獨立的，回合開始時各算一次傷害
func api_poison(caller: Unit, target: Unit, amount: int, turns: int) -> bool:
	if not _api_begin(caller, "poison") or not _check_target(caller, target, "poison"):
		return false
	amount = _cap(caller, "poison", amount, 1, Rules.ENERGY_MAX + Rules.NECRO_SOUL)
	turns = _cap(caller, "poison", turns, 1, Rules.ENERGY_MAX + Rules.NECRO_SOUL)
	var cost: int = _school_cost(caller, Unit.School.VENOM, amount * turns)
	var paid: String = _cost_note(caller, cost)
	if not _spend(caller, cost, "下毒"):
		return false
	target._framework_poisons.append({"amount": amount, "turns": turns, "source": caller, "team": caller._framework_team})
	target.queue_redraw()
	_log("%s 對 %s 施加中毒（%d 傷 × %d 回合%s）" % [_n(caller), _n(target), amount, turns, paid])
	return true


## 🛡️ 聖盾：護盾最多 SHIELD_MAX 點，超過的部分浪費掉
func api_shield(caller: Unit, target: Unit, amount: int) -> bool:
	if not _api_begin(caller, "shield") or not _check_target(caller, target, "shield"):
		return false
	amount = _cap(caller, "shield", amount, 1, Rules.SHIELD_MAX)
	if target.shield_points >= Rules.SHIELD_MAX:
		_log("%s 想給 %s 護盾，但已經滿 %d 點了" % [_n(caller), _n(target), Rules.SHIELD_MAX])
		return false
	var cost: int = _school_cost(caller, Unit.School.AEGIS, amount)
	var paid: String = _cost_note(caller, cost)
	if not _spend(caller, cost, "護盾"):
		return false
	var added: int = mini(amount, Rules.SHIELD_MAX - target.shield_points)
	_write(target, "shield_points", target.shield_points + added)
	_log("%s 給 %s %d 點護盾（現在 %d 點%s）" % [_n(caller), _n(target), added, target.shield_points, paid])
	return true


## 🔥 狂血：照一般傷害結算，回復的血量是目標實際少掉的血（包含坦克分擔的部分）
func api_drain(caller: Unit, target: Unit, amount: int) -> bool:
	if not _api_begin(caller, "drain") or not _check_target(caller, target, "drain"):
		return false
	amount = _cap(caller, "drain", amount, 1, Rules.DAMAGE_CAP)
	var cost: int = _school_cost(caller, Unit.School.BLOOD, amount * 2)
	var paid: String = _cost_note(caller, cost)
	if not _spend(caller, cost, "吸血"):
		return false
	_log("%s 對 %s 吸血%s" % [_n(caller), _n(target), "（%s）" % paid.trim_prefix("，") if paid != "" else ""])
	var hurt: Array = _apply_damage(target, amount, caller, "吸血攻擊")
	var dealt: int = 0
	for entry: Array in hurt:
		dealt += entry[2]
	if dealt > 0 and caller.is_alive():
		_restore(caller, dealt, "%s 吸回 %d 血（%d/%d）", caller)
	for entry: Array in hurt:
		if entry[0].is_alive():
			_fire(entry[0], "on_hurt", [entry[1], caller])
	return true


## 💀 死靈：詛咒會累加，目標下一次受傷時一次用掉
func api_curse(caller: Unit, target: Unit, amount: int) -> bool:
	if not _api_begin(caller, "curse") or not _check_target(caller, target, "curse"):
		return false
	amount = _cap(caller, "curse", amount, 1, Rules.ENERGY_MAX + Rules.NECRO_SOUL)
	var cost: int = _school_cost(caller, Unit.School.NECRO, amount)
	var paid: String = _cost_note(caller, cost)
	if not _spend(caller, cost, "詛咒"):
		return false
	_write(target, "curse_points", target.curse_points + amount)
	_log("%s 對 %s 下了詛咒（下次受傷 +%d，累計 +%d%s）" % [_n(caller), _n(target), amount, target.curse_points, paid])
	return true


func api_summon_token(caller: Unit, token_hp: int, token_attack: int) -> bool:
	if not _api_begin(caller, "summon_token"):
		return false
	if _event != "on_death":
		report_violation(caller, "summon_token() 只能在 on_death 裡用")
		return false
	token_hp = maxi(1, token_hp)
	token_attack = maxi(0, token_attack)
	var cost := Rules.unit_cost(token_hp, token_attack)
	if cost > _token_budget[caller]:
		report_violation(caller, "召喚的 token 太貴（hp %d + 2×attack %d = %d，剩下的額度只有 %d）"
				% [token_hp, token_attack, cost, _token_budget[caller]])
		return false
	var alive: int = get_alive(caller._framework_team).size() + _tokens[caller].size()
	if alive >= Rules.MAX_UNITS:
		_log("%s 想召喚，但隊伍已經滿 %d 隻了" % [_n(caller), Rules.MAX_UNITS])
		return false
	_token_budget[caller] -= cost
	var token := Unit.new()
	token._framework_token = true
	token.unit_name = caller.unit_name + "分身"
	token.max_hp = token_hp
	token.attack = token_attack
	token.color = caller.color.lightened(0.35)
	token.body_radius = 24.0
	_tokens[caller].append(token)
	_log("%s 召喚了 %s（攻 %d、血 %d）" % [_n(caller), token.unit_name, token_attack, token_hp])
	return true


## 流派 API 的價格：和施放者同流派是 base，不同（包含沒有流派）是兩倍
func _school_cost(caller: Unit, school: int, base: int) -> int:
	return base if caller.school == school else base * Rules.OFF_SCHOOL_COST


## 寫在戰鬥紀錄的花費，例如「，花費 6 能量」；Boss 不用能量所以是空字串
func _cost_note(caller: Unit, cost: int) -> String:
	if caller is Boss:
		return ""
	var soul: int = mini(caller._framework_soul, cost)
	if soul > 0:
		return "，花費 %d 能量（其中 %d 點是靈魂能量）" % [cost, soul]
	return "，花費 %d 能量" % cost


## 扣能量：先用靈魂能量，不夠再用一般能量。不夠付就寫進紀錄、回傳 false，一點都不扣
func _spend(caller: Unit, cost: int, action: String) -> bool:
	if caller is Boss:
		return true
	var available: int = caller.energy + caller._framework_soul
	if cost > available:
		_log("%s 能量不足 qonop，%s失敗（需要 %d，只有 %d）" % [_n(caller), action, cost, available])
		return false
	var soul: int = mini(caller._framework_soul, cost)
	caller._framework_soul -= soul
	_write(caller, "energy", caller.energy - (cost - soul))
	return true


func api_say(caller: Unit, text: String) -> void:
	if _actor != caller:
		report_violation(caller, "say() 只能在戰鬥事件裡用（on_frame 不行）")
		return
	_log("%s：「%s」" % [_n(caller), text])


func report_violation(unit: Unit, message: String) -> void:
	_log("[color=#ff5252]⚠ %s：%s[/color]" % [_n(unit), message])


func _api_begin(caller: Unit, api: String) -> bool:
	if _actor != caller:
		report_violation(caller, "%s() 只能在自己的戰鬥事件裡用（on_frame、choose_target 不行）" % api)
		return false
	if caller is Boss:
		return true
	if _calls_left <= 0:
		report_violation(caller, "每個事件最多呼叫 %d 次戰鬥 API，這次 %s() 被略過" % [Rules.CALLS_PER_EVENT, api])
		return false
	_calls_left -= 1
	return true


func _check_target(caller: Unit, target: Unit, api: String) -> bool:
	if target == null or target._framework_battle != self:
		report_violation(caller, "%s() 的目標不存在" % api)
		return false
	if not target.is_alive():
		_log("[color=gray]%s 的 %s() 目標已經倒下了[/color]" % [_n(caller), api])
		return false
	return true


func _cap(caller: Unit, api: String, amount: int, low: int, high: int) -> int:
	if caller is Boss:
		return maxi(0, amount)
	var capped := clampi(amount, low, high)
	if capped != amount:
		_log("[color=#ffb74d]%s 的 %s(%d) 超出範圍，被限制成 %d[/color]" % [_n(caller), api, amount, capped])
	return capped


# ---------------------------------------------------------------- 棋盤查詢

## 還活著的角色，照行動順序（前排 → 後排、左 → 右）
func get_alive(team: int) -> Array[Unit]:
	var alive: Array[Unit] = []
	for unit: Unit in teams[team]:
		if unit.is_alive():
			alive.append(unit)
	return alive


func units_in_row(team: int, row: int) -> Array[Unit]:
	var units: Array[Unit] = []
	for unit: Unit in get_alive(team):
		if unit.grid_position.y == row:
			units.append(unit)
	return units


func units_in_column(team: int, col: int) -> Array[Unit]:
	var units: Array[Unit] = []
	for unit: Unit in get_alive(team):
		if unit.grid_position.x == col:
			units.append(unit)
	return units


func adjacent_allies(unit: Unit) -> Array[Unit]:
	var units: Array[Unit] = []
	for ally: Unit in get_alive(unit._framework_team):
		var diff: Vector2i = (ally.grid_position - unit.grid_position).abs()
		if diff.x + diff.y == 1:
			units.append(ally)
	return units


# ---------------------------------------------------------------- 工具

func _unit_at(team: int, cell: Vector2i) -> Unit:
	for unit: Unit in teams[team]:
		if unit.grid_position == cell:
			return unit
	return null


func _all_units() -> Array[Unit]:
	var units: Array[Unit] = []
	units.append_array(teams[PLAYER])
	units.append_array(teams[ENEMY])
	return units


func _all_alive() -> Array[Unit]:
	var alive := get_alive(PLAYER)
	alive.append_array(get_alive(ENEMY))
	return alive


func _add_unit(unit: Unit, team: int, cell: Vector2i) -> void:
	unit._framework_battle = self
	unit._framework_team = team
	unit.grid_position = cell
	_write(unit, "hp", unit.max_hp)
	_write(unit, "energy", 0 if unit is Boss else Rules.ENERGY_START)
	if unit is Mage and not unit is Healer:
		_write(unit, "energy_regen", Rules.MAGE_ENERGY_REGEN)
	elif _is_warrior(unit):
		unit._framework_passive_icon = "⚡"
	elif unit is Assassin:
		unit._framework_passive_icon = "💨"
	unit._framework_locked = true
	roster.append(unit)
	# 照行動順序插進去，get_alive() 就不用每次排序
	var list: Array = teams[team]
	var index: int = list.size()
	for i: int in list.size():
		if Rules.cell_order(list[i].grid_position) > Rules.cell_order(cell):
			index = i
			break
	list.insert(index, unit)


func _write(unit: Unit, property: StringName, value: Variant) -> void:
	unit._framework_writing = true
	unit.set(property, value)
	unit._framework_writing = false


func _side(team: int) -> String:
	return "[color=%s]%s[/color]" % [TEAM_COLORS[team], side_names[team]]


## 戰鬥紀錄裡的名字，例如「[前排左] 騎士」
func _n(unit: Unit) -> String:
	if unit == null:
		return "？"
	return "[color=%s][lb]%s[rb] %s[/color]" % [TEAM_COLORS[unit._framework_team],
			Rules.cell_name(unit.grid_position), unit.unit_name]


func _log(text: String) -> void:
	logged.emit(text)
