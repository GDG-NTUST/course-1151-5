---
name: autobattler
description: 幫學員寫「集合！Vibe 出你的自走棋物件大隊」（Godot 4.7 GDScript 自走棋）的隊伍與技能。當學員要新增角色、寫技能、調整站位或數值、組隊伍、通過隊伍檢查，或問 teams/<GitHub 帳號>/ 底下的程式時使用。
---

# 自走棋隊伍與技能

這是 Godot 4.7 的 GDScript 專案。學員的所有程式都放在 `teams/<GitHub 帳號>/`，框架在 `framework/`，**不能改框架**。
上場前會用文字掃描擋掉違規寫法（見「不能做的事」），被擋下的隊伍不能上場，所以寫之前先讀完這份規則。
規則以專案根目錄的 `README.md` 和 `framework/rules.gd` 為準；這份文件和它們衝突時，照 README 和 rules.gd。

## 寫程式的習慣

- 所有變數、參數、回傳值都加型別：`var target: Unit = null`、`func on_attack(target: Unit) -> void:`
- 用 Tab 縮排
- 一隻角色一個 `.gd` 檔；共用的東西寫成同資料夾的另一個檔案，用 `preload("檔名.gd")` 或 `extends "檔名.gd"` 引用
- 寫完一定跑檢查（見最後一節），全部 ✅ 才算完成

## 檔案結構

```
teams/<GitHub 帳號>/       ← 資料夾名稱要和 GitHub 帳號一模一樣（包含大小寫）
├── team.gd                ← 隊伍：隊名、帳號、成員
├── knight.gd              ← 一隻角色一個檔
└── skills/fireball.gd     ← 可以有子資料夾和自己寫的類別
```

學員還沒有資料夾的話，請他複製 `teams/template/`（只有一隻小兵）再改名。不要直接複製 `teams/example/` 這些範例隊伍給學員，階段 1 要他們自己寫角色。

`team.gd`：

```gdscript
extends Team

func _init() -> void:
	team_name = "火鍋隊"
	github = "你的GitHub帳號"        # 要和資料夾名稱一樣
	members = [
		preload("knight.gd"),
		preload("archer.gd"),
	]
```

角色：選一個職業 `extends`，在 `_init()` 設定數值、站位、流派，再覆寫事件寫技能：

```gdscript
extends Archer
## 毒蛇射手：攻擊後幫目標疊一層毒

func _init() -> void:
	unit_name = "毒蛇射手"
	max_hp = 10
	attack = 2
	color = Color("#8bc34a")
	grid_position = Vector2i(0, 2)   # 後排左
	school = School.VENOM            # 可以不寫，預設 School.NONE

func on_attack(target: Unit) -> void:
	if target.is_alive() and get_energy() >= 3:
		poison(target, 1, 3)
```

- 同一個角色檔只能上場一次。要兩隻一樣的，就再寫一個檔案 `extends "archer.gd"`，在 `_init()` **第一行寫 `super()`**，再改 `grid_position`。Godot 4 的子類別 `_init()` 不會自動呼叫父類別的 `_init()`，忘了 `super()` 數值會變回預設值
- 自己寫的父類別也一樣，子類別的 `_init()` 第一行要 `super()`

## 棋盤

每隊 3×3，角色站好就不會移動。`grid_position = Vector2i(行, 排)`：x 是行（0 左、1 中、2 右），y 是排（0 前排、1 中排、2 後排），前排面對敵人。每隻要站不同格。

## 職業（決定普攻打誰和被動）

| 職業 | `extends` | 普攻 | 被動（自動生效，不用寫程式） |
|---|---|---|---|
| 戰士 | `Warrior` 或 `Unit` | 打敵方**最前排**，優先同一行，沒有就打最近的一行（一樣近打左邊） | 衝鋒：每場第一次普攻傷害 +2 |
| 坦克 | `Tank` | 同戰士 | 掩護：替上下左右相鄰的隊友分擔 50% 傷害（無條件捨去）。坦克自己被打不會被別的坦克分擔 |
| 射手 | `Archer` | 任何一格，預設打血最少的；覆寫 `choose_target(enemies: Array[Unit]) -> Unit` 自己挑（要回傳 `enemies` 裡的一隻，裡面不能呼叫戰鬥 API） | 弱點射擊：普攻血量低於一半的目標傷害 +1 |
| 法師 | `Mage` | 敵方同一行的所有角色 | 法力湧流：每回合回復 4 能量（一般是 3） |
| 補師 | `Healer`（法師的子類別） | 不攻擊，幫相鄰有受傷的隊友回 `attack` 點血（免費）；**不會觸發 `on_attack`** | 淨化：普通治療有回到血時，移除目標 1 層中毒（沒有法力湧流） |
| 刺客 | `Assassin` | 打敵方**最後排**，優先同一行 | 閃避：每場第一次被普攻打中時不受傷害 |

被動只對普攻有效（法力湧流、淨化除外），召喚的分身沒有被動。

「最前排」「最後排」指還有角色活著的那一排。`attack` 是 0 的角色不會普攻，也不會觸發 `on_attack`。

## 預算

每隊 1–5 隻，總預算 **100 點**，每隻花費 = `max_hp + 2 × attack`。`max_hp` 1–40，`attack` 0–10。技能不花點數。

## 回合流程

- 行動順序固定：同一隊從前排到後排、每排從左到右。打 Boss 時我方先；隊伍對戰時兩隊交錯（先手 1 → 後手 1 → 先手 2 …）
- 每回合開始：每隻角色回復能量 → Boss 回合開始的能力（例如雷神蓄力）→ 中毒的角色毒發 → 角色輪流行動
- 每個動作結束後馬上結算倒下的角色：`on_death` →（死靈 4 隻的全體傷害）→ 隊友的 `on_ally_death`
- 打 Boss 最多 30 回合，打不完算輸，同歸於盡也算輸。隊伍對戰超過 30 回合比剩餘血量比例（召喚的分身不算）；同時全滅或比例一樣，後手獲勝
- 隨機用固定種子，同樣的隊伍結果永遠一樣

傷害照這個順序結算：刺客閃避（整次不算）→ 基礎傷害 → 攻擊者增傷（只有普攻：狂血 4 隻、戰士衝鋒、射手弱點射擊）→ 加上目標的詛咒並用掉 → 扣護盾（毒跳過）→ 坦克分擔 → 扣血。

## 能量

- 開場 3 點，每回合開始回復 3 點（法師 4 點），最多存 6 點；`energy` 唯讀，用 `get_energy()` 查
- 普攻、補師的普通治療免費；技能 API 要花能量，不夠時回傳 `false`、不生效、不扣能量
- 能量存到 6 之後，每回合回復的會浪費掉

## 流派

`school` 在 `_init()` 設定：`School.NONE`、`School.VENOM`（劇毒）、`School.AEGIS`（聖盾）、`School.BLOOD`（狂血）、`School.NECRO`（死靈）。
流派 API 誰都能用，但施放者和 API **同流派是正常價，不同（包含 NONE）是兩倍價**。開場時同隊同流派的隻數決定加成（之後陣亡也不會失去）：

| 流派 | API | 2 隻 | 4 隻（包含 2 隻的效果） |
|---|---|---|---|
| 劇毒 | `poison` | 我方施加的毒傷每回合 +2 | 中毒的敵人無法被治療（heal、吸血、狂血回血都無效） |
| 聖盾 | `shield` | 開場全隊 3 點護盾 | 開場全隊 4 點護盾（取代 3 點） |
| 狂血 | `drain` | 普攻命中後攻擊者回 1 血 | 血量低於一半的角色普攻 +2 |
| 死靈 | `curse` | 死靈角色死亡時獲得 6 點靈魂能量 | 死靈角色死亡時對全體敵人造成 1 點傷害 |

靈魂能量只在那隻角色的 `on_death()` 裡能用，先用靈魂能量再用一般能量；`get_energy()` 在 `on_death` 裡會包含它。數字以 `framework/rules.gd` 為準。

## 事件（覆寫這些）

| 方法 | 觸發時機 |
|---|---|
| `on_battle_start() -> void` | 戰鬥開始 |
| `on_attack(target: Unit) -> void` | 自己普攻之後 |
| `on_hurt(amount: int, source: Unit) -> void` | 自己受傷之後（全部被護盾擋下就不會觸發） |
| `on_death() -> void` | 自己倒下時 |
| `on_ally_death(ally: Unit) -> void` | 有隊友倒下時 |
| `on_frame(delta: float) -> void` | 每一幀，**只能做畫面效果**，不能呼叫戰鬥 API |

沒有「每回合開始」的事件給學員用；想每回合做事，就寫在 `on_attack`（補師沒有 `on_attack`，可以用 `on_hurt`、`on_ally_death`）。

## 戰鬥 API（技能只能透過這些生效）

| 方法 | 效果 | 能量 | 上限 |
|---|---|---|---|
| `deal_damage(target, amount) -> bool` | 造成傷害 | amount | 每次 1–5 |
| `heal(target, amount) -> bool` | 回血，不超過 max_hp | amount | 每次 1–5 |
| `buff_attack(target, amount) -> bool` | 加攻擊 | amount × 2 | 每次 1–3，attack 最多 15 |
| `summon_token(hp, attack) -> bool` | 召喚沒有技能的分身 | 免費 | 只能在 `on_death` 用，同一次死亡合計 `hp + 2×attack ≤ 10`，隊伍最多 5 隻 |
| `poison(target, amount, turns) -> bool` | 目標每回合開始受到 amount 傷害，持續 turns 回合；無視護盾，可疊好幾層 | amount × turns | — |
| `shield(target, amount) -> bool` | 護盾，受傷時先扣 | amount | 每隻最多 10 點 |
| `drain(target, amount) -> bool` | 造成傷害，自己回復實際造成的傷害 | amount × 2 | 每次 1–5 |
| `curse(target, amount) -> bool` | 目標下一次受傷 +amount，多個詛咒加總，觸發一次用光 | amount | — |
| `say(text) -> void` | 在戰鬥紀錄說話 | 免費 | — |

- 流派 API 的能量是同流派價，不同流派兩倍
- 每隻角色**每個事件最多呼叫 3 次** API，第 4 次會被略過
- 技能傷害會觸發對方的 `on_hurt`，連鎖最多 3 層
- 超出範圍的數值會被自動限制（例如 `deal_damage(target, 9)` 變成 5）
- API 只能在自己的事件裡呼叫；`on_frame`、`choose_target` 裡不行

## 查詢

`get_allies()`、`get_enemies()`（還活著的，照行動順序，最前排在前）、`get_slot()`、`get_grid_position()`、`get_adjacent_allies()`、
`get_units_in_row(row: int, enemy: bool)`、`get_units_in_column(col: int, enemy: bool)`、`get_role()`（"戰士"、"坦克"…）、
`get_energy()`、`get_school_count(school)`、`get_poison_stacks()`、`get_round()`、`is_alive()`、
`random_int(a, b)`、`random_pick(array)`（固定種子的隨機）。
唯讀屬性（戰鬥中不能改）：`hp`、`max_hp`、`attack`、`energy`、`shield_points`、`curse_points`、`school`、`grid_position`。

可以隨便改、不影響戰鬥的外觀：`color`、`body_radius`、`status_text`、`position`、`modulate`、`scale`。

## 不能做的事（掃描會擋下，整隊不能上場）

掃描的是程式碼（註解和字串內容不算，但 `_framework` 寫在字串裡也會擋）。資料夾裡**每一個** `.gd` 都會掃：

- `class_name`（全班會撞名，自己的類別用 `preload("檔名.gd")`）、`@tool`、三個引號的多行字串
- `preload` / `extends "路徑"` 指到自己資料夾以外的檔案
- `load()`、`get_script()`、`get_property_list()`、`get_method_list()`、`instance_from_id()`、`str_to_var()`
- 系統、檔案、網路、引擎類別：`OS`、`FileAccess`、`DirAccess`、`ResourceLoader`、`Engine`、`ProjectSettings`、`ClassDB`、`Input`、`Thread`、`HTTPRequest`、`IP`、`DisplayServer`、名字以 `Server` 結尾的類別等
- 引擎方法：`_process`、`_physics_process`、`_ready`、`_enter_tree`、`_exit_tree`、`_notification`、`_input` 等（動畫用 `on_frame`）
- `get_tree`、`get_node`、`get_parent`、`get_child(ren)`、`find_child(ren)`、`$節點`
- `set()`、`set_deferred()`、`call()`、`callv()`、`call_deferred()`、`set_script()`、`Callable(...)`、`Expression`
- `free()`、`queue_free()`、`add_child()`、`remove_child()`、`reparent()`
- 內建隨機：`randi`、`randf`、`randi_range`、`randf_range`、`randomize`、`seed`、`.pick_random()`、`.shuffle()`、`RandomNumberGenerator`（改用 `random_int` / `random_pick`）
- 任何 `_framework` 開頭的東西、`Boss` 類別
- 在 `_init()` 以外指定 `hp`、`max_hp`、`attack`、`grid_position`、`school`（包括 `target.hp = 0`、`attack += 1`）
- 在任何地方（連 `_init()` 也不行）指定 `energy`、`energy_regen`、`shield_points`、`curse_points`
- `on_frame` 裡呼叫戰鬥 API

容易踩到的地方：

- 掃描只看名字，所以**區域變數不要取名 `hp`、`attack`、`energy`、`school` 這些**，之後再指定它就會被當成改屬性。改用 `target_hp`、`dmg` 之類的名字
- `==`、`<`、`>=` 這類比較沒問題，只有 `=`、`+=` 這類指定會被擋
- 不要寫 `while` 無窮迴圈，PR 檢查超過 10 分鐘會被中止

## Boss（練習用，擂台賽不會出現）

| 代號 | 能力 | 怎麼打 |
|---|---|---|
| `dummy` 木樁 | 不反擊 | 練習 |
| `lv1` 史萊姆王 | 大血包 | 只靠數值就打得贏 |
| `lv2` 刺甲龜 | 被普攻打中會全額反彈；技能、毒不會被反彈 | 降低攻擊、改用技能打（`deal_damage`、`poison`…） |
| `lv3` 雷神 | 平常普攻只造成一半傷害；每 3 回合蓄力（不攻擊、受傷 ×2、雷甲消失），下一回合雷擊全體 8 點 | 把能量存到蓄力回合一起用，用補血或護盾撐過雷擊 |

學員卡在 Lv2 時，可以參考 `teams/example_stage2/`：盾兵 attack 0 擋前排，四個弓手 attack 1、`on_attack` 裡 `deal_damage(target, 3)`，只用基礎技能就打得贏。

## 檢查與測試

在**專案根目錄**執行。`godot` 換成 Godot 執行檔，沒有加進 PATH 就用完整路徑：

- Windows（PowerShell）：要用檔名有 `console` 的那個，前面加 `&`，例如 `& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless ...`
- Mac（終端機）：執行檔在 app 裡面，例如 `/Applications/Godot.app/Contents/MacOS/Godot --headless ...`

先問學員用哪種電腦，再給對應的指令。

```sh
godot --headless --script res://tools/validate.gd -- 帳號              # 和 PR 自動檢查一樣：掃描、語法、隊伍設定、試打 Lv1
godot --headless --script res://framework/simulate.gd -- 帳號 lv3      # 印出整場戰鬥紀錄
godot --headless --script res://framework/simulate.gd -- 帳號A vs 帳號B
```

改完程式後：

1. 跑 `validate.gd`，全部 ✅ 才算完成；❌ 的項目會寫出檔案、行號和修法
2. 用 `simulate.gd` 打目標 Boss，讀戰鬥紀錄確認技能有照預期觸發（紅字 ⚠ 是違規、「能量不足」代表技能沒生效）
3. 發 PR 時只能改 `teams/<帳號>/` 底下的檔案
