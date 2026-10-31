extends Tank
## 毒心守衛（劇毒坦克）：站正中央，替上下左右四隻法師分擔一半傷害（毒傷也算）。
## 分擔傷害時自己也會受傷，就趁機把能量變成毒；倒下時召喚分身。
## 花費 = 12 + 2 × 0 = 12 點
const Toxin = preload("toxin.gd")

var brain = Toxin.new(self)


func _init() -> void:
	unit_name = "暗燄修羅"
	max_hp = 12
	attack = 0
	color = Color("#33691e")
	grid_position = Vector2i(1, 1)   # 中排中
	school = School.VENOM


func on_battle_start() -> void:
	brain.cast(true)


func on_hurt(_amount: int, _source: Unit) -> void:
	brain.cast(false)


func on_ally_death(_ally: Unit) -> void:
	brain.cast(false)


func on_death() -> void:
	brain.on_death()
