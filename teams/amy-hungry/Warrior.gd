extends Warrior
## 毒刃戰士：普攻後讓目標中毒
## 花費 = 16 + 2 × 3 = 22 點

func _init() -> void:
	unit_name = "毒刃戰士"
	max_hp = 16
	attack = 3
	color = Color("#66bb6a")
	grid_position = Vector2i(0, 0)   # 前排左
	school = School.VENOM

func on_attack(target: Unit) -> void:
	if target != null and target.is_alive() and get_energy() >= 3:
		poison(target, 1, 3)
