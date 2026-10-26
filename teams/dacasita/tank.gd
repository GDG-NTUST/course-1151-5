extends Tank
## 鐵壁（坦克・劇毒）：前排中吃雷神的普攻，順便疊毒。
## 雷神前 3 回合只出手 2 次（回合 1、2 普攻 5 傷害），鐵壁血厚撐得住，第 3 回合它就蓄力倒下。
## 花費 = max_hp + 2 × attack = 24 + 2 × 1 = 26 點


func _init() -> void:
	unit_name = "鐵壁"
	max_hp = 24
	attack = 1
	color = Color("#b0bec5")
	grid_position = Vector2i(1, 0)   # 前排中：和雷神同一行，負責坦傷害
	school = School.VENOM


func on_battle_start() -> void:
	_spread_poison()


func on_attack(_target: Unit) -> void:
	_spread_poison()


## 把能量拆成最多 3 層毒（每個事件最多 3 次 API）。劇毒 2 隻以上每層每回合 +2，
## 所以 1 點能量能換到 3 點傷害，而且毒無視雷甲。
func _spread_poison() -> void:
	var enemies: Array[Unit] = get_enemies()
	if enemies.is_empty():
		return
	var target: Unit = enemies[0]
	var budget: int = get_energy()
	for calls_left: int in range(3, 0, -1):
		if budget <= 0:
			return
		var turns: int = ceili(float(budget) / calls_left)
		if poison(target, 1, turns):
			budget -= turns
