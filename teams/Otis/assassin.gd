extends Assassin
## 毒霧刺客：切入敵方後排上毒，具備一次閃避

func _init() -> void:
	unit_name = "毒霧刺客"
	max_hp = 10
	attack = 1
	color = Color("#66bb6a")
	grid_position = Vector2i(2, 0)
	school = School.VENOM

func on_attack(target: Unit) -> void:
	if target.is_alive() and get_energy() >= 3:
		poison(target, 1, 3)
