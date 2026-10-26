extends "venom_mage.gd"
## 毒蛛：中排右，被守衛掩護
## 花費 = 20 + 2 × 1 = 22 點


func _init() -> void:
	unit_name = "狂風武王"
	max_hp = 20
	attack = 1                       # 至少 1 才會普攻、觸發 on_attack（對手不攻擊時也能出手）
	color = Color("#689f38")
	grid_position = Vector2i(2, 1)
	school = School.VENOM
