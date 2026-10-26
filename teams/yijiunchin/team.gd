extends Team
## 🧪 劇毒 5 隻：毒心守衛站正中央，四隻劇毒法師上下左右包圍。
## 劇毒 2 隻：毒傷每回合 +2；4 隻：中毒的敵人無法被治療。
## 總花費 = 守衛 12 + 毒牙 27 + 毒霧 22 + 毒蛛 22 + 毒蠍 17 = 100 點


func _init() -> void:
	team_name = "sixseven"
	github = "yijiunchin"            # 要和資料夾名稱一樣
	members = [
		preload("front.gd"),
		preload("left.gd"),
		preload("warden.gd"),
		preload("right.gd"),
		preload("back.gd"),
	]
