extends Tank
## 荊棘右盾：站前排右 (2, 0)，專門吸收敵方右路傷害並進行反傷。
## 花費 = 20 + 2 × 0 = 20 點

func _init() -> void:
	unit_name = "右盾"
	max_hp = 20
	attack = 0
	color = Color("#78909c")
	grid_position = Vector2i(2, 0)   # 前排右
	school = School.AEGIS

func on_hurt(amount: int, source: Unit) -> void:
	# 荊棘反傷：受傷時，回敬攻擊者 1 點技能傷害
	# 技能傷害無視雷甲，且花費僅 1 點能量
	if source != null and source.is_alive() and get_energy() >= 1:
		deal_damage(source, 1)
