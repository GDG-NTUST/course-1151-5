extends RefCounted
## 劇毒大腦（法師、坦克共用，每隻角色各帶一個）：把能量拆成「1 傷 × 1 回合」的毒。
## 劇毒 2 隻以上每層毒每回合 +2，所以 1 點能量 = 3 點傷害，而且毒無視護盾。
##
## 選目標：扣掉敵人身上已經排定的毒傷後，「還差幾層就毒死」最少的優先，
## 會算對方坦克分擔（被掩護的角色一層毒只少 2 血），並優先毒死劇毒法師這類高威脅角色。
## 毒發階段出手時，優先毒「這回合還沒輪到毒發」的敵人，毒會當回合生效。
## 倒下時召喚分身：分身不花能量，等於每倒一隻多一具身體，拖到同時全滅就是後手贏。

## 不是最後一個事件時，最多留幾點能量給這回合後面的事件（受傷、攻擊）
const KEEP_MAX := 2
## 威脅權重：每 1 點威脅抵掉幾層「還差幾層」
const THREAT_W := 4
## 敵人沒中毒、血量 ≤ 這個值時，直接用技能補刀
const KILL_SHOT := 3
## 毒發階段：這回合已經毒發過的敵人，要多算幾層
const PEND_W := 6
## 倒下時召喚的分身（hp + 2 × attack ≤ 10）
const TOKEN_HP := 6
const TOKEN_ATK := 2

var unit: Unit
var acted_round: int = -1     # 這回合普攻過了沒（之後就不是毒發階段）
var first_flag: int = -1      # 1 我方先手、0 我方後手、-1 看不出來
var flag_round: int = -1


func _init(owner_unit: Unit) -> void:
	unit = owner_unit


func on_attack() -> void:
	acted_round = unit.get_round()
	cast(true)


func on_death() -> void:
	var calls: int = 3
	if unit.get_allies().size() < 5 and unit.summon_token(TOKEN_HP, TOKEN_ATK):
		calls -= 1
	cast(true, calls)


## dump = true 時把能量全部花完（最後一發把多的能量拉長回合數）
func cast(dump: bool, calls: int = 3) -> void:
	for calls_left: int in range(calls, 0, -1):
		var budget: int = unit.get_energy()
		if budget <= 0:
			return
		if _kill_shot():
			continue
		var turns: int = 1
		if calls_left == 1:
			var spare: int = budget if dump else budget - KEEP_MAX
			if spare > 1:
				turns = spare
		var target: Unit = _pick()
		if target == null or not unit.poison(target, 1, turns):
			return


func _kill_shot() -> bool:
	for enemy: Unit in unit.get_enemies():
		var dmg: int = enemy.hp * 2 if _guarded(enemy) else enemy.hp
		if enemy.get_poison_stacks() == 0 and enemy.hp <= KILL_SHOT and dmg <= mini(5, unit.get_energy()):
			return unit.deal_damage(enemy, dmg)
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
func _tick_taken(enemy: Unit) -> int:
	var per: int = 1 + (2 if unit.get_school_count(Unit.School.VENOM) >= 2 else 0)
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


func _pick() -> Unit:
	var best: Unit = null
	var best_score: float = 1.0e9
	var fallback: Unit = null
	var ticking: bool = unit.get_round() > 0 and acted_round != unit.get_round()
	for enemy: Unit in unit.get_enemies():
		if fallback == null or enemy.hp > fallback.hp:
			fallback = enemy
		var per: int = _tick_taken(enemy)
		var left: int = enemy.hp - enemy.get_poison_stacks() * per
		if left <= 0:
			continue          # 身上的毒已經夠毒死，不浪費
		var score: float = ceilf(float(left) / per) - THREAT_W * _threat(enemy)
		if ticking and not _pending(enemy):
			score += PEND_W
		if score < best_score:
			best = enemy
			best_score = score
	return best if best != null else fallback


## 這回合的毒發還沒輪到這個敵人（兩隊照順位交錯：先手 1 → 後手 1 → 先手 2 …）
func _pending(enemy: Unit) -> bool:
	var ref: int = unit.get_slot()
	if unit.get_role() == "坦克":
		for ally: Unit in unit.get_adjacent_allies():
			ref = mini(ref, ally.get_slot())   # 坦克是在相鄰隊友毒發、替牠分擔時受傷的
	if _detect_first() == 1:
		return enemy.get_slot() >= ref
	return enemy.get_slot() > ref


## 看敵方和我同順位的那隻，這回合是不是已經花過能量（比順位更後面的同職業少）：
## 花過就代表牠已經毒發、出過手，我方是後手。看不出來時問隊友。
func _detect_first() -> int:
	if flag_round == unit.get_round():
		return first_flag
	flag_round = unit.get_round()
	var me: int = unit.get_slot()
	var foes: Array[Unit] = unit.get_enemies()
	if me >= 0 and me < foes.size():
		var twin: Unit = foes[me]
		var top: int = -1
		for j: int in range(me + 1, foes.size()):
			if foes[j].get_role() == twin.get_role():
				top = maxi(top, foes[j].energy)
		if top >= 0:
			first_flag = 0 if twin.energy < top else 1
			return first_flag
	for ally: Unit in unit.get_allies():
		var other: Variant = ally
		if ally != unit and "brain" in other:
			var f: int = other.brain.first_flag_of_round(unit.get_round())
			if f >= 0:
				first_flag = f
				return f
	return first_flag


func first_flag_of_round(r: int) -> int:
	return first_flag if flag_round == r else -1
