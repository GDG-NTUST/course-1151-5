extends Warrior
## 新兵（戰士・劇毒）：前排左，普攻後把能量全拆成毒。
## 花費 = max_hp + 2 × attack = 18 + 2 × 1 = 20 點


func _init() -> void:
	unit_name = "新兵"
	max_hp = 18
	attack = 1
	color = Color("#8fa3c7")
	grid_position = Vector2i(0, 0)   # 前排左
	school = School.VENOM


func on_battle_start() -> void:
	_spread_poison()


func on_attack(_target: Unit) -> void:
	_spread_poison()


func _spread_poison() -> void:
	var enemies: Array[Unit] = get_enemies()
	if enemies.is_empty():
		return
	var target: Unit = enemies[0]
	var budget: int = get_energy()
	for calls_left: int in range(3, 0, -1):
		if budget <= 0:
			return
		var turns: int = ceili(float(budget) / calls_left)
		if poison(target, 1, turns):
			budget -= turns
