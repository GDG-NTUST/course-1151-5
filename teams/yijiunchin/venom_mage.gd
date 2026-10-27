extends Mage
## 劇毒法師（共用父類別，本身不上場）
## 開場、受傷（包含毒發的時候）、攻擊後、隊友倒下、自己倒下，每個時機都把能量變成毒；
## 倒下時再召喚一隻分身。大腦在 toxin.gd。
const Toxin = preload("toxin.gd")

var brain = Toxin.new(self)


func on_battle_start() -> void:
	brain.cast(true)


func on_hurt(_amount: int, _source: Unit) -> void:
	brain.cast(false)


func on_attack(_target: Unit) -> void:
	brain.on_attack()


func on_ally_death(_ally: Unit) -> void:
	brain.cast(false)


func on_death() -> void:
	brain.on_death()
