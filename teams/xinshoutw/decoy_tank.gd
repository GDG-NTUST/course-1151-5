extends Tank
## 毒餌（劇毒坦克）
## 10 + 2 × 1 = 12

const Brain = preload("brain.gd")

var brain = Brain.new(self)


func _init() -> void:
	unit_name = "毒餌"
	max_hp = 10
	attack = 1
	color = Color("#33691e")
	grid_position = Vector2i(1, 1)   # 中排中
	school = School.VENOM


func on_battle_start() -> void:
	brain.act(Brain.START)


func on_attack(_target: Unit) -> void:
	brain.act(Brain.ATTACK)


func on_hurt(_amount: int, _source: Unit) -> void:
	brain.act(Brain.HURT)


func on_ally_death(_ally: Unit) -> void:
	brain.act(Brain.ALLY)


func on_death() -> void:
	brain.on_death()
