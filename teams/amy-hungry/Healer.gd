extends Healer
## 苗圃醫師：治療相鄰隊友，受傷時追加少量治療
## 花費 = 8 + 2 × 2 = 12 點

func _init() -> void:
	unit_name = "苗圃醫師"
	max_hp = 8
	attack = 2
	color = Color("#26a69a")
	grid_position = Vector2i(1, 1)   # 中排中
	school = School.VENOM

func on_hurt(amount: int, source: Unit) -> void:
	var healed_count: int = 0

	for ally: Unit in get_adjacent_allies():
		if healed_count >= 3 or get_energy() < 1:
			break

		if ally.hp < ally.max_hp:
			heal(ally, 1)
			healed_count += 1
