extends Team
## 12 + 20 + 18 + 13 + 37 = 100


func _init() -> void:
	team_name = "penguin"
	github = "xinshoutw"
	members = [
		preload("decoy_tank.gd"),
		preload("mage_front.gd"),
		preload("mage_left.gd"),
		preload("mage_right.gd"),
		preload("mage_king.gd"),
	]
