extends Archer
## 毒蛇射手：鎖定中毒最多者，集中疊加毒素
## 花費 = 12 + 2 × 4 = 20 點

func _init() -> void:
	unit_name = "毒蛇射手"
	max_hp = 12
	attack = 4
	color = Color("#4caf50")
	grid_position = Vector2i(0, 2)   # 後排左
	school = School.VENOM

func choose_target(enemies: Array[Unit]) -> Unit:
	var best_target: Unit = null
	var max_stacks: int = -1

	for enemy: Unit in enemies:
		var stacks: int = enemy.get_poison_stacks()

		if stacks > max_stacks:
			max_stacks = stacks
			best_target = enemy
		elif stacks == max_stacks and best_target != null and enemy.hp < best_target.hp:
			best_target = enemy

	return best_target

func on_attack(target: Unit) -> void:
	if target != null and target.is_alive() and get_energy() >= 3:
		poison(target, 1, 3)
