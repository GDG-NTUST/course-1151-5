extends Team
## 你的隊伍：把 github 改成你的帳號，再把角色加進 members


func _init() -> void:
	team_name = "輸了幫沫沫加班"
	github = "ruth1030"            # 要和資料夾名稱一樣
	members = [
		preload("ruth.gd"),
		preload("hycaine.gd"),
		preload("stelle.gd"),
		preload("kafka.gd"),
		preload("dangheng.gd")
	]
