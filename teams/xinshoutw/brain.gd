extends RefCounted
## 毒術大腦

const START := 0
const ATTACK := 1
const HURT := 2
const DEATH := 3
const ALLY := 4

const TICK := 3              # 1 點毒 + 劇毒加成 2
const TOKEN_HP := 8          # 倒下時召喚的分身：hp + 2×attack ≤ 10
const TOKEN_ATK := 1
const SECOND_RESERVE := 1    # 後手時每個事件留 1 點能量

var unit: Unit
var start_allies: Array[Unit] = []
var start_enemies: Array[Unit] = []
var probed := false          # 開場時同號的敵人身上有我方的毒
var mode := -1               # -1 不知道、0 先手、1 後手
var attacked_round := 0


func _init(owner_unit: Unit) -> void:
	unit = owner_unit


func on_death() -> void:
	var calls := 3
	if unit.get_allies().size() < Rules.MAX_UNITS:
		unit.summon_token(TOKEN_HP, TOKEN_ATK)
		calls -= 1
	act(DEATH, calls)


func act(event: int, calls: int = 3) -> void:
	if event == START:
		start_allies = unit.get_allies()
		start_enemies = unit.get_enemies()
	elif event == ATTACK:
		attacked_round = unit.get_round()
	elif event == HURT:
		detect()
	var keep: int = SECOND_RESERVE if event != DEATH and current_mode() == 1 else 0
	while calls > 0:
		var budget: int = unit.get_energy() - keep
		if budget <= 0:
			break
		var turns := 1
		if event == DEATH:
			turns = ceili(float(budget) / calls)
		elif calls == 1:
			var regen := Rules.MAGE_ENERGY_REGEN if unit.get_role() == "法師" else Rules.ENERGY_REGEN
			turns = clampi(budget + regen - Rules.ENERGY_MAX, 1, budget)
		var target := pick()
		if event == START and calls == 1:
			target = probe_target(target)
		if target == null or not unit.poison(target, 1, turns):
			break
		calls -= 1
	if event == START:
		var e := twin()
		probed = e != null and e.get_poison_stacks() > 0


func probe_target(target: Unit) -> Unit:
	var e := twin()
	if e != null and e.get_poison_stacks() == 0:
		return e
	return target


func twin() -> Unit:
	var i: int = start_allies.find(unit)
	if i < 0 or i >= start_enemies.size():
		return null
	return start_enemies[i]


func detect() -> void:
	if mode != -1 or not probed or unit.get_round() != 1 or unit.get_role() == "坦克" \
			or unit.get_poison_stacks() == 0 or team_attacked():
		return
	var e := twin()
	mode = 1 if (not e.is_alive() or e.get_poison_stacks() == 0) else 0


func team_attacked() -> bool:
	for a: Unit in unit.get_allies():
		var o = a
		if "brain" in o and o.brain.attacked_round >= unit.get_round():
			return true
	return false


func current_mode() -> int:
	if mode == -1:
		for a: Unit in unit.get_allies():
			var o = a
			if "brain" in o and o.brain.mode != -1:
				mode = o.brain.mode
				break
	return mode


static func per_tick(e: Unit, enemies: Array[Unit]) -> int:
	if e.get_role() == "坦克":
		return TICK
	for o: Unit in enemies:
		if o != e and o.get_role() == "坦克":
			var d: Vector2i = (o.get_grid_position() - e.get_grid_position()).abs()
			if d.x + d.y == 1:
				return TICK - TICK / 2
	return TICK


static func need(e: Unit, enemies: Array[Unit]) -> int:
	return ceili(float(e.hp) / per_tick(e, enemies)) - e.get_poison_stacks()


static func threat(e: Unit) -> int:
	if e.get_role() == "戰士" and e.max_hp + 2 * e.attack <= 10 and e.unit_name.ends_with("分身"):
		return 1
	if e.get_role() == "法師":
		return 4
	return 3 if e.attack > 0 else 2


func pick() -> Unit:
	var enemies := unit.get_enemies()
	var best: Unit = null
	var best_need := 0
	for e: Unit in enemies:
		var n: int = need(e, enemies)
		if n <= 0:
			continue
		if best == null:
			best = e
			best_need = n
			continue
		var lhs: int = threat(e) * best_need
		var rhs: int = threat(best) * n
		if lhs > rhs or (lhs == rhs and n < best_need):
			best = e
			best_need = n
	return best
