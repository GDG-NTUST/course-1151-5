extends Healer


func _init() -> void:
	unit_name = "3"
	max_hp = 10
	attack = 3
	color = Color("#f8bbd0")
	grid_position = Vector2i(1, 1)


func on_hurt(_amount: int, _source: Unit) -> void:
	for ally: Unit in get_adjacent_allies():
		if ally.hp < ally.max_hp:
			heal(ally, 1)
