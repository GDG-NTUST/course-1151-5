extends Team
## 你的隊伍：把 github 改成你的帳號，再把角色加進 members


func _init() -> void:
	team_name = "Alus"
	github = "AlusIsing"            # 要和資料夾名稱一樣
	members = [
		preload("my_unit.gd"),
		preload("pig.gd"),
		preload("healer.gd"),
		preload("shooter.gd"),
		preload("douob.gd")
	]
