extends "venom_mage.gd"
## 毒王（劇毒法師）
## 35 + 2 × 1 = 37


func _init() -> void:
	super()
	unit_name = "毒王"
	max_hp = 35
	attack = 1
	grid_position = Vector2i(2, 2)   # 後排右
