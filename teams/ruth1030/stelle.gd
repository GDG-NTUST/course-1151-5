extends Warrior

func _init() -> void:
	unit_name = "星"
	max_hp = 10
	attack = 6
	color = Color("eac483ff")
	grid_position = Vector2i(1, 0)   # 前排中
	school = School.BLOOD

func on_death() -> void: # 召喚分身
	summon_token(4, 3)
