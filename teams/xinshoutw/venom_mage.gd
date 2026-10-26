extends Mage
## 劇毒法師（父類別）：回 4 能量每回合
## 以事件區動行為

const Brain = preload("brain.gd")

var brain = Brain.new(self)


func _init() -> void:
	school = School.VENOM
	color = Color("#8bc34a")


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
