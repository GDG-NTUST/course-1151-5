extends "venom_mage.gd"
## 毒霧左翼（劇毒法師）
## 18 + 2 × 0 = 18


func _init() -> void:
	super()
	unit_name = "毒霧左翼"
	max_hp = 18
	attack = 0
	grid_position = Vector2i(0, 1)   # 中排左
