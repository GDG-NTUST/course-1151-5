extends Healer

func _init() -> void:
	unit_name = "風堇"
	max_hp = 12
	attack = 2
	color = Color("e36e90ff")
	grid_position = Vector2i(1, 1)   # 中排中
	school = School.BLOOD

func on_hurt(amount: int, source: Unit) -> void:
	for ally in get_adjacent_allies():
		if ally.hp < ally.max_hp:   # 只幫有受傷的
			heal(ally, 1)
