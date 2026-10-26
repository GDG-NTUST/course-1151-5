extends Archer


func _init() -> void:
	unit_name = "4"
	max_hp = 10
	attack = 2
	color = Color("#8bc34a")
	grid_position = Vector2i(0, 2)
	school = School.VENOM


func on_attack(target: Unit) -> void:
	if get_energy() >= 6:
		poison(target, 2, 3)
	elif get_energy() >= 3:
		poison(target, 1, 3)
