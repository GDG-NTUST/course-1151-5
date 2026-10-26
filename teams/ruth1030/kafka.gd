extends Mage
## 範例角色：見習法師（法師）
## 一次打中敵方同一行的所有角色。
## 花費 = 10 + 2 × 3 = 16 點


func _init() -> void:
	unit_name = "卡芙卡"
	max_hp = 10
	attack = 3
	color = Color("ae1657ff")
	grid_position = Vector2i(2, 1)   # 中排右
	school = School.BLOOD

func on_attack(target: Unit) -> void:
	if target.is_alive() and get_energy() >= 3:
		deal_damage(target, 3)
