extends SceneTree
## Validator 的回歸測試（講師用）：學員的 _init() 每次執行結果可能不同，要擋的是 Battle 真的建立出來的角色。
##
##   godot --headless --script res://tools/validator_test.gd
##
## 測試用的角色在 tools/fixtures/（不放 teams/，才不會出現在隊伍選單）。結束代碼：0 全部通過、1 有失敗。

const DIR := "res://tools/fixtures"
const BOX := preload("fixtures/box.gd")
const DRIFT := preload("fixtures/drift.gd")
const TWIN := preload("fixtures/twin.gd")

var failed: int = 0


func _init() -> void:
	var boss: Array[Script] = [load(Rules.BOSSES["dummy"]) as Script]

	# 第一次建立是合法的，check_team 會通過；Battle 建立的那一批超出上限，要被擋下
	_expect("drift: check_team sees a legal first instance", Validator.check_team([DRIFT], DIR).is_empty())
	var battle: Battle = Battle.new([DRIFT], boss)
	_expect("drift: battle instance rejected",
			_has(Validator.check_units(battle.created[Battle.PLAYER], DIR), "max_hp 要在"))
	_free(battle)

	# members 裡有不是角色的東西：Battle 不能建到一半就中斷（Boss 那隊會是空的），要交給 Validator 擋
	battle = Battle.new([DRIFT, BOX, null], boss)
	var errors: Array[String] = Validator.check_units(battle.created[Battle.PLAYER], DIR)
	_expect("non-unit: other side still built", battle.teams[Battle.ENEMY].size() == 1)
	_expect("non-unit: rejected", _has(errors, "box.gd 要 extends Unit") and _has(errors, "第 3 個不是角色腳本"))
	_free(battle)

	# 同一個角色檔放兩次，每次站的格子不一樣也要擋
	_expect("duplicate script rejected", _has(Validator.check_team([TWIN, TWIN], DIR), "只能上場一次"))

	_expect("static var rejected by scan", _has(Validator.check_source(DIR + "/static_var.gd"), "static var"))

	print("validator_test：%s" % ("全部通過" if failed == 0 else "%d 項失敗" % failed))
	quit(0 if failed == 0 else 1)


func _expect(label: String, ok: bool) -> void:
	print("%s %s" % ["✓" if ok else "✗", label])
	if not ok:
		failed += 1


func _has(errors: Array[String], text: String) -> bool:
	return errors.any(func(error: String) -> bool: return error.contains(text))


func _free(battle: Battle) -> void:
	for unit: Unit in battle.roster:
		unit.free()
