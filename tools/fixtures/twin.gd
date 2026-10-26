extends Warrior
## validator_test 用：每次建立站不同格，放兩次也不會被「同一格」擋下
const BOX = preload("box.gd")


func _init() -> void:
	var box: Object = BOX
	var count: int = box.get_meta("twin", 0) + 1
	box.set_meta("twin", count)
	unit_name = "twin"
	max_hp = 10
	attack = 1
	grid_position = Vector2i(count % 2, 0)
