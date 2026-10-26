extends Archer
## 弓手：站在中排左側 (0, 1)，死靈流派。
## 戰術核心：依照回合節奏管理能量，在敵方弱點/蓄力回合全力爆發。

func _init() -> void:
	unit_name = "弓手"
	max_hp = 10
	attack = 4
	color = Color("#ab47bc")
	grid_position = Vector2i(0, 1)   # 中排左
	school = School.NECRO

func on_attack(target: Unit) -> void:
	if not target.is_alive():
		return

	var current_round: int = get_round()
	var current_energy: int = get_energy()

	# 1. 蓄力/弱點回合（第 3, 6, 9... 回合）：全力爆發！
	# 目標此時受到傷害 ×2，技能傷害完全無視護甲，造成毀滅性打擊
	if current_round % 3 == 0:
		if current_energy >= 2:
			curse(target, 2)
			current_energy -= 2
		if current_energy >= 3:
			deal_damage(target, 3)
	else:
		# 2. 平常回合：若能量充裕 (>= 4)，施加技能傷害或詛咒穩健削血
		if current_energy >= 5:
			deal_damage(target, 2)
		elif current_energy >= 3:
			curse(target, 1)
