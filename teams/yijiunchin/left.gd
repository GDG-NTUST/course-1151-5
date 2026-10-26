extends "venom_mage.gd"
## 毒霧：中排左，被守衛掩護
## 花費 = 20 + 2 × 1 = 22 點


func _init() -> void:
	unit_name = "赤靈龍王"
	max_hp = 20
	attack = 1                       # 至少 1 才會普攻、觸發 on_attack（對手不攻擊時也能出手）
	color = Color("#7cb342")
	grid_position = Vector2i(0, 1)
	school = School.VENOM
