extends RefCounted
## 劇毒大腦（法師、坦克共用）：把能量拆成「1 傷 × 1 回合」的毒。
## 劇毒 2 隻以上每層毒每回合 +2，所以 1 點能量 = 3 點傷害，而且毒無視護盾。
##
## 選目標：扣掉敵人身上已經排定的毒傷後，「還差幾層就毒死」最少的優先，
## 會算對方坦克分擔（被掩護的角色一層毒只少 2 血），並優先毒死劇毒法師這類高威脅角色。

## 不是最後一個事件時，最多留幾點能量給這回合後面的事件（受傷、攻擊）
const KEEP_MAX := 2
## 威脅權重：每 1 點威脅抵掉幾層「還差幾層」
const THREAT_W := 4
## 敵人沒中毒、血量 ≤ 這個值時，直接用技能補刀
const KILL_SHOT := 3


## dump = true 時把能量全部花完（最後一發把多的能量拉長回合數）
static func cast(caster: Unit, dump: bool) -> void:
	for calls_left: int in range(3, 0, -1):
		var budget: int = caster.get_energy()
		if budget <= 0:
			return
		if _kill_shot(caster):
			continue
		var turns: int = 1
		if calls_left == 1:
			var spare: int = budget if dump else budget - KEEP_MAX
			if spare > 1:
				turns = spare
		var target: Unit = _pick(caster)
		if target == null or not caster.poison(target, 1, turns):
			return


static func _kill_shot(caster: Unit) -> bool:
	for enemy: Unit in caster.get_enemies():
		var dmg: int = enemy.hp * 2 if _guarded(enemy) else enemy.hp
		if enemy.get_poison_stacks() == 0 and enemy.hp <= KILL_SHOT and dmg <= mini(5, caster.get_energy()):
			return caster.deal_damage(enemy, dmg)
	return false


## 敵人旁邊有活著的敵方坦克（自己不是坦克）時，傷害會被分擔一半
static func _guarded(enemy: Unit) -> bool:
	if enemy.get_role() == "坦克":
		return false
	for other: Unit in enemy.get_adjacent_allies():
		if other.get_role() == "坦克":
			return true
	return false


## 我方一層毒打在這個敵人身上，實際少多少血
static func _tick_taken(caster: Unit, enemy: Unit) -> int:
	var per: int = 1 + (2 if caster.get_school_count(Unit.School.VENOM) >= 2 else 0)
	return per - per / 2 if _guarded(enemy) else per


static func _threat(enemy: Unit) -> int:
	var t: int = 0
	if enemy.school == Unit.School.VENOM:
		t += 2
	if enemy.get_role() == "法師":
		t += 1
	if enemy.get_role() == "坦克" or enemy.get_role() == "補師":
		t -= 1
	return t


static func _pick(caster: Unit) -> Unit:
	var best: Unit = null
	var best_score: float = 1.0e9
	var fallback: Unit = null
	for enemy: Unit in caster.get_enemies():
		if fallback == null or enemy.hp > fallback.hp:
			fallback = enemy
		var per: int = _tick_taken(caster, enemy)
		var left: int = enemy.hp - enemy.get_poison_stacks() * per
		if left <= 0:
			continue          # 身上的毒已經夠毒死，不浪費
		var score: float = ceilf(float(left) / per) - THREAT_W * _threat(enemy)
		if score < best_score:
			best = enemy
			best_score = score
	return best if best != null else fallback
