extends Tank
## 你的第一隻角色：改職業、名字、數值和站位看看
## 花費 = max_hp + 2 × attack = 10 + 2 × 2 = 14 點


func _init() -> void:
	unit_name = "大肉"
	max_hp = 40
	attack = 1
	grid_position = Vector2i(1, 0)
	school = School.AEGIS

func on_hurt(amount: int, source: Unit) -> void:
	if source != null and source.is_alive():
		deal_damage(source, 1)
