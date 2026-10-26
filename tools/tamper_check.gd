extends SceneTree
## 回歸檢查：學員不能改 Boss 或別隻角色的狀態（講師用）
##
##   godot --headless --script res://tools/tamper_check.gd
##
## 會印出幾行預期中的 ERROR（Boss 擋下的寫入）。結束代碼：0 全部通過、1 有失敗。

const CASE_PATH := "user://tamper_case.gd"

## [程式碼, 要不要被掃描擋下]
const SCAN_CASES := [
	["func on_attack(t: Unit) -> void:\n\tvar o = t\n\to.charging = false", true],
	["func on_attack(t: Unit) -> void:\n\tget_enemies()[0].mood += 1", true],
	["func on_attack(t: Unit) -> void:\n\tif true: t.memory[\"k\"] = 1", true],
	["func is_alive() -> bool:\n\treturn true", true],
	["var t := 0.0\nvar s: Unit.School = Unit.School.NONE\nfunc on_frame(delta: float) -> void:\n\tt += delta\n\tposition.y = t\n\tmodulate.a = 0.5\n\tself.t = 1.0", false],
	["func on_attack(t: Unit) -> void:\n\tvar v := Vector2.ZERO\n\tv.x = 1\n\tif t.hp == 1 or t.max_hp <= 2: say(\"x\")", false],
]

var failures := 0


func _init() -> void:
	for entry: Array in SCAN_CASES:
		var file := FileAccess.open(CASE_PATH, FileAccess.WRITE)
		file.store_string("extends Unit\n" + entry[0])
		file.close()
		var errors: Array[String] = Validator.check_source(CASE_PATH)
		_expect(errors.is_empty() != entry[1], "掃描 %s → %s" % [entry[0].c_escape(), errors])

	# 繞過掃描（用 [] 寫）也改不到 Boss：雷神照常攻擊、受到的傷害倍率不變
	var cheat := GDScript.new()
	cheat.source_code = "extends Unit\nfunc _init():\n\tmax_hp = 20\n\tgrid_position = Vector2i(1, 0)\n" \
			+ "func on_attack(_t):\n\tfor e in get_enemies():\n\t\te[\"skip_attack\"] = true\n" \
			+ "\t\te[\"damage_taken_multiplier\"] = 20\n\t\te[\"charging\"] = true"
	cheat.reload()
	var battle := Battle.new([cheat], [load(Rules.BOSSES["lv3"]) as Script])
	battle.start()
	battle.step()
	var boss: Boss = battle.teams[Battle.ENEMY][0]
	_expect(not boss.skip_attack and boss.damage_taken_multiplier == 1 and not boss.get("charging"), "Boss 欄位被改掉了")
	for unit: Unit in battle.roster:
		unit.free()

	print("tamper_check：%s" % ("全部通過" if failures == 0 else "%d 項失敗" % failures))
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("✗ ", message)
