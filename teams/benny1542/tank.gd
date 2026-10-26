extends Tank
## 聖盾連鎖：站前排中 (1, 0)，聖盾流派。
## 每次受傷時，把受到的傷害量轉成護盾，加給相鄰隊友裡血量比例最低的那隻。
## 透過能量控管保留底牌，避免一回合把能量耗光，以應對雷神的致命雷擊。
## 花費 = 24 + 2 × 0 = 24 點

func _init() -> void:
	unit_name = "聖盾連鎖"
	max_hp = 24
	attack = 0
	color = Color("#4fc3f7")
	grid_position = Vector2i(1, 0)   # 前排中
	school = School.AEGIS

func on_hurt(amount: int, source: Unit) -> void:
	# 尋找相鄰隊友中血量比例最低者
	var target_ally: Unit = null
	var lowest_ratio: float = 2.0
	for ally: Unit in get_adjacent_allies():
		if not ally.is_alive():
			continue
		var ratio: float = float(ally.hp) / float(ally.max_hp)
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			target_ally = ally

	if target_ally == null:
		return

	# 能量防禦控管（避免一回合耗光）：
	# 1. 至少保留 1 點能量作為安全儲備
	var current_energy: int = get_energy()
	if current_energy <= 1:
		return

	# 2. 單次轉盾上限為 2 點（避免單次大傷害把能量抽乾）
	# 3. 確保不超過可用儲備（保留 1 點）與目標護盾上限（最多 10 點）
	var shield_amount: int = mini(amount, 2)
	shield_amount = mini(shield_amount, current_energy - 1)
	var max_addable_shield: int = 10 - target_ally.shield_points
	shield_amount = mini(shield_amount, max_addable_shield)

	if shield_amount > 0:
		shield(target_ally, shield_amount)
