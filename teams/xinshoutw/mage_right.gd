extends "venom_mage.gd"
## 毒霧右翼（劇毒法師）
## 11 + 2 × 1 = 13


func _init() -> void:
	super()
	unit_name = "毒霧右翼"
	max_hp = 11
	attack = 1
	grid_position = Vector2i(2, 1)   # 中排右
