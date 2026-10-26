class_name Boss
extends Unit
## Boss 的父類別（講師用，學員的角色不能繼承這個）。
##
## Boss 呼叫戰鬥 API 時不受數值上限和呼叫次數限制，
## 另外可以在 on_round_start() 設定下面這些欄位來改變這回合的行為。

var skip_attack := false            # true：這回合不普攻
var pierce := false                 # true：這回合普攻打整排
var pierce_damage := 0              # 打整排時每隻受到的傷害
var damage_taken_multiplier := 1    # 受到的傷害倍率
var attack_damage_percent := 100    # 被普攻打到時只受到幾 %（無條件捨去），技能和毒不受影響


func _init() -> void:
	body_radius = 52.0
	color = Color("#d9534f")
	grid_position = Vector2i(1, 0)      # 預設站前排中，子類別可以在 _init() 改


## 每回合開始呼叫：回復能量之後、毒發和攻擊之前
func on_round_start(_round_number: int) -> void: pass

## 被普攻打中時呼叫（技能、毒傷不算），在 on_hurt 之前
func on_attacked(_amount: int, _attacker: Unit) -> void: pass
