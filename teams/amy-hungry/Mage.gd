extends Mage
## 瘟疫法師：整行普攻，並對攻擊目標附加毒素
## 花費 = 10 + 2 × 3 = 16 點

func _init() -> void:
	unit_name = "瘟疫法師"
	max_hp = 10
	attack = 3
	color = Color("#ab47bc")
	grid_position = Vector2i(1, 2)   # 後排中
	school = School.VENOM

func on_attack(target: Unit) -> void:
	if target != null and target.is_alive() and get_energy() >= 3:
		poison(target, 1, 3)
