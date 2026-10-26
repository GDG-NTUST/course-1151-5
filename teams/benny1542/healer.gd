extends Healer
## 小護士：相鄰中排左弓手與前排中坦克。
## 開場為輸出核心加攻擊，受傷時為相鄰受傷隊友治療。

func _init() -> void:
	unit_name = "小護士"
	max_hp = 14
	attack = 2
	grid_position = Vector2i(1, 1)   # 中排中

func on_battle_start() -> void:
	# 開場為我方核心輸出（弓手）永久強化 1 點攻擊力
	for ally: Unit in get_allies():
		if ally is Archer and ally.attack < 15:
			buff_attack(ally, 1)
			break

func on_hurt(amount: int, source: Unit) -> void:
	for ally: Unit in get_adjacent_allies():
		if ally.hp < ally.max_hp and get_energy() >= 1:
			heal(ally, 1)

func on_death() -> void:
	summon_token(6, 2)
