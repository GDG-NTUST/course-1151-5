extends Tank
## 荊棘盾衛：保護相鄰隊友，受傷時反擊
## 花費 = 28 + 2 × 1 = 30 點

func _init() -> void:
	unit_name = "荊棘盾衛"
	max_hp = 28
	attack = 1
	color = Color("#78909c")
	grid_position = Vector2i(1, 0)   # 前排中

func on_hurt(amount: int, source: Unit) -> void:
	if source != null and source.is_alive() and get_energy() >= 1:
		deal_damage(source, 1)
