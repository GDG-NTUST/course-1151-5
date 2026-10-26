extends Team
## 你的隊伍：把 github 改成你的帳號，再把角色加進 members


func _init() -> void:
	team_name = "直鏈澱粉不會輸"
	github = "amy-hungry"            # 要和資料夾名稱一樣
	members = [
		preload("Archer.gd"),
		preload("Mage.gd"),
		preload("Healer.gd"),
		preload("Tank.gd"),
		preload("Warrior.gd"),
	]
