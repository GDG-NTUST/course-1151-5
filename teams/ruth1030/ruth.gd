extends Assassin
## Ruth（刺客）
## 特殊技能「嗜血收割」：看到快死的敵人，就用吸血把它收掉，順便把血吸回來

func _init() -> void:
	unit_name = "Ruth"
	max_hp = 8
	attack = 5
	color = Color("#951030")
	grid_position = Vector2i(0, 1) # 中排左
	school = School.BLOOD

func on_attack(target: Unit) -> void:
	if get_energy() < 2:
		return
	
	# 尋找快死的敵人（優先斬殺血量低於等於 3 的目標）
	var victim: Unit = null
	for enemy: Unit in get_enemies():
		if enemy.is_alive() and enemy.hp <= 3:
			victim = enemy
			break
	
	# 若沒有能直接斬殺的小怪，但目標血量偏低（低於一半）、或是自身受傷需要吸血，亦或是 Boss 蓄力時
	if victim == null and target != null and target.is_alive():
		if target.hp * 2 <= target.max_hp or hp < max_hp or get_round() % 3 == 0:
			victim = target
	
	if victim != null:
		var drain_amount: int = mini(get_energy() / 2, mini(victim.hp, 3))
		if drain_amount >= 1:
			say("嗜血收割！")
			drain(victim, drain_amount)
