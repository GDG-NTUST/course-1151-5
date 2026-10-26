extends Mage
## validator_test 用：第一次建立時合法，之後每次都超出數值上限
const BOX = preload("box.gd")


func _init() -> void:
	var box: Object = BOX
	var count: int = box.get_meta("drift", 0) + 1
	box.set_meta("drift", count)
	unit_name = "drift"
	max_hp = 10 if count == 1 else 99
	attack = 1 if count == 1 else 30
	grid_position = Vector2i(1, 0)
