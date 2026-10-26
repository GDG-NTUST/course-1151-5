extends Team


func _init() -> void:
	team_name = "Andy-0614"
	github = "Andy-0614"
	members = [
		preload("tank.gd"),
		preload("nurse.gd"),
		preload("mage.gd"),
		preload("archer.gd"),
		preload("archer2.gd"),
	]
