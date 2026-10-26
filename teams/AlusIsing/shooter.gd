extends Archer
## 你的第一隻角色：改職業、名字、數值和站位看看
## 花費 = max_hp + 2 × attack = 10 + 2 × 2 = 14 點


func _init() -> void:
	unit_name = "biu biu"
	max_hp = 10
	attack = 10
	grid_position = Vector2i(1, 2)   # 前排中

func on_hurt(amount: int, source: Unit) -> void:
	deal_damage(source, 3)

func on_death() -> void:
	summon_token(4, 3)
