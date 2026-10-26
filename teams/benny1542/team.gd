extends Team
## 你的隊伍：把 github 改成你的帳號，再把角色加進 members


func _init() -> void:
	team_name = "benny"
	github = "benny1542"            # 要和資料夾名稱一樣
	members = [
		preload("tank_left.gd"),
		preload("tank.gd"),
		preload("tank_right.gd"),
		preload("archer.gd"),
		preload("healer.gd"),
	]
