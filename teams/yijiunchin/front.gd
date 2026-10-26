extends "venom_mage.gd"
## 毒牙：前排中，血最厚，最先被盯上
## 花費 = 25 + 2 × 1 = 27 點


func _init() -> void:
	unit_name = "深海狂魔"
	max_hp = 25
	attack = 1                       # 至少 1 才會普攻、觸發 on_attack（對手不攻擊時也能出手）
	color = Color("#8bc34a")
	grid_position = Vector2i(1, 0)
	school = School.VENOM
