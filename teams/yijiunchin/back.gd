extends "venom_mage.gd"
## 毒蠍：後排中，被守衛掩護
## 花費 = 15 + 2 × 1 = 17 點


func _init() -> void:
	unit_name = "誓約刀客"
	max_hp = 15
	attack = 1                       # 至少 1 才會普攻、觸發 on_attack（對手不攻擊時也能出手）
	color = Color("#9ccc65")
	grid_position = Vector2i(1, 2)
	school = School.VENOM
