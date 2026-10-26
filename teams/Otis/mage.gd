extends Mage
## 毒師（法師・劇毒）：中排中，普攻後把能量全拆成毒。
## 法師「法力湧流」每回合回 4 能量（其他職業 3），疊毒最快。
## 花費 = max_hp + 2 × attack = 16 + 2 × 1 = 18 點


func _init() -> void:
	unit_name = "毒師"
	max_hp = 16
	attack = 1
	color = Color("#8bc34a")
	grid_position = Vector2i(1, 1)   # 中排中
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
