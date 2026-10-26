extends Archer
## 你的第一隻角色：改職業、名字、數值和站位看看
## 花費 = max_hp + 2 × attack = 10 + 2 × 2 = 14 點


func _init() -> void:
	unit_name = "野豬騎士"
	max_hp = 5
	attack = 10
	grid_position = Vector2i(0, 1)   # 前排中

func on_hurt(amount: int, source: Unit) -> void:
	deal_damage(source, 3)

func on_death() -> void:
	summon_token(4, 3)
