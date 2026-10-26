extends Archer
## 劇毒引爆者：蓄滿 5 點能量，鎖定疊滿 3 層中毒的目標進行 5 點致命引爆

func _init() -> void:
	unit_name = "劇毒引爆者"
	max_hp = 14
	attack = 2
	color = Color("#8bc34a")
	grid_position = Vector2i(2, 2)
	school = School.VENOM

func choose_target(enemies: Array[Unit]) -> Unit:
	var best_target: Unit = null

	# 第一優先：已達 3 層毒且血量最低的目標
	for enemy: Unit in enemies:
		if enemy.get_poison_stacks() >= 3:
			if best_target == null or enemy.hp < best_target.hp:
				best_target = enemy

	if best_target != null:
		return best_target

	# 第二優先：中毒層數最多（若一樣多，選血量最少）
	var max_stacks: int = -1
	for enemy: Unit in enemies:
		var stacks: int = enemy.get_poison_stacks()
		if stacks > max_stacks:
			max_stacks = stacks
			best_target = enemy
		elif stacks == max_stacks and best_target != null and enemy.hp < best_target.hp:
			best_target = enemy

	return best_target if best_target != null else enemies[0]

func on_attack(target: Unit) -> void:
	if target.is_alive() and target.get_poison_stacks() >= 3 and get_energy() >= 5:
		say("引爆！")
		deal_damage(target, 5)
