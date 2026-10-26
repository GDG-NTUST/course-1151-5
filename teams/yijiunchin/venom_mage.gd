extends Mage
## 劇毒法師（共用父類別，本身不上場）
## 開場、受傷（包含毒發的時候）、攻擊後、隊友倒下、自己倒下，每個時機都把能量變成毒。
## 毒發階段一受傷就出手，下的毒在「這回合還沒毒發」的敵人身上會馬上生效，比等到攻擊時快一整回合。
const Toxin = preload("toxin.gd")


func on_battle_start() -> void:
	Toxin.cast(self, true)


func on_hurt(_amount: int, _source: Unit) -> void:
	Toxin.cast(self, false)


func on_attack(_target: Unit) -> void:
	Toxin.cast(self, true)


func on_ally_death(_ally: Unit) -> void:
	Toxin.cast(self, false)


func on_death() -> void:
	Toxin.cast(self, true)
