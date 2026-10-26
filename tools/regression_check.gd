extends SceneTree
## 框架回歸檢查（講師用）：重現修過的規則邊角，有一項不符就結束代碼 1。
##
##   godot --headless --script res://tools/regression_check.gd
##
## 1. 雷神蓄力的「受傷 ×2」只算在蓄力那回合：第 3 回合的毒發 ×2，第 4 回合的毒發不會 ×2
## 2. 召喚的分身不算進對戰的剩餘血量比例：比例不會超過 100%，也不會因此贏下打滿 30 回合的對戰

var _failed := false


func _init() -> void:
	_check_lv3_charge()
	_check_token_hp_ratio()
	print("✗ 有檢查沒通過" if _failed else "✓ 全部通過")
	quit(1 if _failed else 0)


## 攻擊力 0 的坦克打雷神，雷神身上一層每回合 1 點的毒，所以雷神受到的傷害只來自毒發
func _check_lv3_charge() -> void:
	var battle: Battle = Battle.new([_unit("Tank", 60, Vector2i(1, 0))], [load(Rules.BOSSES["lv3"]) as Script])
	var boss: Unit = battle.teams[Battle.ENEMY][0]
	_add_poison(boss, battle.teams[Battle.PLAYER][0], 4)
	var taken: Dictionary = {}   # 回合 -> 雷神這回合受到的傷害
	var record: Callable = func(unit: Unit, amount: int) -> void:
		if unit == boss:
			taken[battle.round_number] = taken.get(battle.round_number, 0) + amount
	battle.unit_damaged.connect(record)
	battle.start()
	for _i: int in 4:
		battle.step()
	battle.unit_damaged.disconnect(record)   # lambda 抓著 battle，不斷開會互相參照、釋放不掉
	var got: Array = [taken.get(1), taken.get(2), taken.get(3), taken.get(4)]
	_expect("雷神第 1–4 回合受到的毒傷是 [1, 1, 2, 1]", got == [1, 1, 2, 1], str(got))
	_free(battle)


## 左隊 11 血：A 10 血、B 1 血（第 1 回合毒死，倒下時召喚 10 血的分身）；右隊 10 血。誰都不攻擊，打滿 30 回合
func _check_token_hp_ratio() -> void:
	var dies: GDScript = _unit("Unit", 1, Vector2i(1, 0), "\nfunc on_death() -> void:\n\tsummon_token(10, 0)\n")
	var battle: Battle = Battle.new([_unit("Unit", 10, Vector2i(1, 2)), dies], [_unit("Unit", 10, Vector2i(1, 0))])
	battle.setup_versus("left", "right")
	var victim: Unit = battle.teams[Battle.PLAYER][0]
	_add_poison(victim, victim, 1)
	battle.start()
	battle.step()
	var ratio: float = battle.hp_ratio(Battle.PLAYER)
	_expect("召喚分身後左隊的剩餘血量比例不超過 100%", battle.get_alive(Battle.PLAYER).size() == 2 and ratio <= 1.0, "%.2f" % ratio)
	while battle.result == "":
		battle.step()
	_expect("打滿 30 回合比血量，右隊（100%）贏左隊（10/11）", battle.winner == Battle.ENEMY, battle.result_reason)
	_free(battle)


## 直接掛一層每回合 1 點、持續 turns 回合的毒（不經過 poison()，不用能量）
func _add_poison(target: Unit, source: Unit, turns: int) -> void:
	target._framework_poisons.append({"amount": 1, "turns": turns, "source": source, "team": source._framework_team})


## 攻擊力 0 的角色腳本；extra 是附加在後面的程式碼
func _unit(base: String, max_hp: int, cell: Vector2i, extra: String = "") -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "extends %s\n\nfunc _init() -> void:\n\tmax_hp = %d\n\tattack = 0\n\tgrid_position = Vector2i(%d, %d)\n%s" \
			% [base, max_hp, cell.x, cell.y, extra]
	script.reload()
	return script


func _expect(label: String, ok: bool, detail: String) -> void:
	print("%s %s（%s）" % ["✓" if ok else "✗", label, detail])
	_failed = _failed or not ok


func _free(battle: Battle) -> void:
	for unit: Unit in battle.roster:
		unit.free()
