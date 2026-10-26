extends Team
## 你的隊伍：把 github 改成你的帳號，再把角色加進 members


func _init() -> void:
	team_name = "等於等於不能加空白=="
	github = "Michael3858"            # 要和資料夾名稱一樣
	members = [
		preload("archer.gd"),
		preload("assassin.gd"),
		preload("healer.gd"),
		preload("tank.gd"),
	]
