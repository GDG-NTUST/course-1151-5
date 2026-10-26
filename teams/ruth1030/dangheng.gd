extends Tank
## 範例角色：盾兵（坦克）
## 站在隊友旁邊，替他們分擔一半的傷害。
## 花費 = 30 + 2 × 1 = 32 點


func _init() -> void:
	unit_name = "丹恆"
	max_hp = 25
	attack = 1
	color = Color("2e7578ff")
	grid_position = Vector2i(0, 0)   # 前排左
	school = School.BLOOD

func on_hurt(amount: int, source: Unit) -> void:
	if source != null and source.is_alive():
		deal_damage(source, 1)
