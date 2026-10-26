extends "tank.gd"
## 鐵衛左盾：站前排左，繼承聖盾連鎖能力
## 花費 = 20 + 2 × 0 = 20 點

func _init() -> void:
	super()
	unit_name = "左盾"
	max_hp = 20
	grid_position = Vector2i(0, 0)   # 前排左
