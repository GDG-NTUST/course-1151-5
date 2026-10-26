extends Healer
## 你的第一隻角色：改職業、名字、數值和站位看看
## 花費 = max_hp + 2 × attack = 10 + 2 × 2 = 14 點


func _init() -> void:
	unit_name = "吟遊詩人"
	max_hp = 1
	attack = 0
	grid_position = Vector2i(1, 1)   # 前排中

func on_hurt(amount: int, source: Unit) -> void:
	for i in get_adjacent_allies():
		heal(i, 2)

func on_death() -> void:
	summon_token(4, 3)
