extends Healer

func _init() -> void:
	unit_name = "奶媽"
	max_hp = 6
	attack = 2
	color = Color("#ffcc80")
	grid_position = Vector2i(1, 1)
	school = School.AEGIS

func on_death() -> void:
	summon_token(2, 4)
