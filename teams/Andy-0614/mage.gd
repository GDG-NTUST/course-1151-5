extends Mage


func _init() -> void:
	unit_name = "2"
	max_hp = 10
	attack = 2
	color = Color("#9ccc65")
	grid_position = Vector2i(0, 1)
	school = School.VENOM


func on_attack(target: Unit) -> void:
	if get_energy() >= 6:
		poison(target, 2, 3)
	elif get_energy() >= 3:
		poison(target, 1, 3)
