extends Warrior
## 毒刃戰士：衝鋒前排，普攻後施加毒素

func _init() -> void:
	unit_name = "毒刃戰士"
	max_hp = 18
	attack = 2
	color = Color("#2e7d32")
	grid_position = Vector2i(0, 0)
	school = School.VENOM

func on_attack(target: Unit) -> void:
	if target.is_alive() and get_energy() >= 3:
		poison(target, 1, 3)
