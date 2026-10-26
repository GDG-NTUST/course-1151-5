extends Team
## Otis 的隊伍：4 隻劇毒疊毒 + 1 隻引爆者收割。
## 前 4 隻每回合把能量全拆成毒，引爆者等雷神身上毒夠多時用 deal_damage 收頭。
## 核心：毒傷不吃雷甲、蓄力回合對毒也 ×2，第 3 回合毒發 + 引爆一次收掉雷神。


func _init() -> void:
	team_name = "Otis 隊"
	github = "Otis"            # 要和資料夾名稱一樣
	members = [
		preload("my_unit.gd"),     # 戰士・劇毒：前排左
		preload("tank.gd"),        # 坦克・劇毒：前排中，擋住雷神
		preload("mage.gd"),        # 法師・劇毒：中排中，回能快疊毒快
		preload("archer.gd"),      # 射手・劇毒：中排左
		preload("detonator.gd"),   # 引爆者：後排右，毒夠多時 deal_damage 收頭
	]
