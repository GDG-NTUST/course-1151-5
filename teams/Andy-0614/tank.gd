extends Tank


func _init() -> void:
	unit_name = "1"
	max_hp = 40
	attack = 1
	color = Color("#558b2f")
	grid_position = Vector2i(1, 0)
	school = School.VENOM


func on_attack(target: Unit) -> void:
	if get_energy() >= 6:
		poison(target, 2, 3)
	elif get_energy() >= 3:
		poison(target, 1, 3)
