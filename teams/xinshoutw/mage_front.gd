extends "venom_mage.gd"
## 毒霧前鋒（劇毒法師）
## 20 + 2 × 0 = 20


func _init() -> void:
	super()
	unit_name = "毒霧前鋒"
	max_hp = 20
	attack = 0
	grid_position = Vector2i(1, 0)   # 前排中
