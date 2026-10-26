# 集合！Vibe 出你的自走棋物件大隊

用 Godot 4 做的迷你自走棋。你要用**物件**組出一支隊伍，先打倒 Boss 練功，最後發 PR 把隊伍合併進專案，和全班在擂台上對戰。

一路上你會用到物件導向的幾個核心概念：

| 概念 | 在這個專案裡長什麼樣子 |
|---|---|
| 物件 | 每隻角色、整支隊伍都是一個物件 |
| 繼承 | 角色 `extends Archer`、`extends Tank`，隊伍 `extends Team` |
| 覆寫 | 覆寫 `on_hurt()`、`on_death()` 這些事件，做出角色的技能 |
| 多型 | 同一場戰鬥裡，每隻角色對同一個事件的反應都不一樣 |
| 封裝 | 不能直接改 `hp`，只能透過 `deal_damage()`、`heal()` |
| 幀與 delta | 用 `on_frame(delta)` 做動畫，邏輯和畫面分開 |

## 快速開始

1. 安裝 **Godot 4.7**
2. 用 Godot 打開這個資料夾（選 `project.godot`）
3. 按 **F5** 打開**陣型預覽**，隊伍選 `example`、挑戰選 `dummy`，按「試打」

### 建立自己的隊伍

1. 複製 `teams/template/` 整個資料夾，改名成**你的 GitHub 帳號**，例如 `teams/zyzy0826/`
2. 打開裡面的 `team.gd`，把 `github` 改成你的帳號、`team_name` 改成你的隊名
3. 回到陣型預覽，隊伍選單就會出現你的隊伍

模板裡只有一隻小兵 `my_unit.gd`，連史萊姆王都打不贏。照[階段 1](#階段-1宣告物件)自己加角色、調數值和站位；`teams/example/` 可以參考，但請自己重寫一隊。

你寫的所有東西（角色、技能、自己的父類別）都放在這個資料夾裡。

### 陣型預覽

- 左邊列出隊伍成員，右邊的 3×3 棋盤顯示每隻角色站在哪一格
- 右上角顯示用掉的預算，下面列出所有沒通過檢查的地方
- 改完程式**切回遊戲視窗就會自動更新**，也可以按「重新讀取」
- 通過檢查之後才能按「試打」

### 擂台

上半部是 Boss 的棋盤、下半部是你的棋盤，兩邊的前排面對面。右邊是**戰鬥紀錄**，每一次攻擊、技能、倒下都會寫在這裡，名字前面會標格子，例如「[前排左] 騎士 攻擊 [前排中] 木樁」。角色沒照你想的動，先來這裡找原因。

| 按鍵 | 功能 |
|---|---|
| R | 重新開始 |
| Esc | 回陣型預覽 |
| 空白鍵 | 暫停 / 繼續 |
| 1 / 2 / 3 | 1 倍 / 2 倍 / 4 倍速 |

右下角的「複製紀錄」按鈕會把整場戰鬥紀錄（含標題）複製到剪貼簿，可以直接貼給 AI 問「為什麼我的技能沒觸發」。

## 三個階段

| 階段 | 你要做的事 | 建議挑戰 |
|---|---|---|
| 1. 宣告物件 | 選職業、設定數值和站位，把角色放進 `team.gd` | 木樁、史萊姆王 |
| 2. 寫基礎技能 | 覆寫事件，用 `heal()`、`deal_damage()` 這些 API 做技能 | 刺甲龜、雷神 |
| 3. 和 AI 一起寫技能 | 自己設計技能類別、共用的父類別，組出最強的隊伍 | 擂台賽 |

每個階段都可以隨時換隊員、改站位。

### 階段 1：宣告物件

一隻角色就是一個 `.gd` 檔。選一個職業 `extends`，在 `_init()` 裡設定數值和站位：

```gdscript
extends Archer
## 弓手：站在後排中間，可以打任何一格

func _init() -> void:
	unit_name = "弓手"
	max_hp = 10
	attack = 4
	color = Color("#ffcc80")
	grid_position = Vector2i(1, 2)   # 中間那一行、後排
```

再把它加進 `team.gd` 的 `members`：

```gdscript
extends Team

func _init() -> void:
	team_name = "火鍋隊"
	github = "zyzy0826"            # 要和資料夾名稱一樣
	members = [
		preload("knight.gd"),
		preload("archer.gd"),     # 同一個資料夾的檔案，直接寫檔名
	]
```

`grid_position = Vector2i(行, 排)`：

|  | 行 0（左） | 行 1（中） | 行 2（右） |
|---|---|---|---|
| **排 0（前排）** | `(0, 0)` | `(1, 0)` | `(2, 0)` |
| **排 1（中排）** | `(0, 1)` | `(1, 1)` | `(2, 1)` |
| **排 2（後排）** | `(0, 2)` | `(1, 2)` | `(2, 2)` |

前排面對敵人。每隻角色要站不同格，同一個角色檔只能上場一次。想要兩個弓手，就再寫一個檔案繼承第一個，只改站位：

```gdscript
extends "archer.gd"

func _init() -> void:
	super()                          # 先用 archer.gd 的設定
	grid_position = Vector2i(0, 2)   # 再改站位
```

### 階段 2：寫基礎技能

覆寫事件，在裡面呼叫戰鬥 API：

```gdscript
extends Unit
## 小護士：受傷時，幫相鄰的隊友各回 1 血

func _init() -> void:
	unit_name = "小護士"
	max_hp = 16
	attack = 3
	color = Color("#ff9ecf")
	grid_position = Vector2i(1, 1)

func on_hurt(amount: int, source: Unit) -> void:
	for ally in get_adjacent_allies():
		heal(ally, 1)
```

可以用的事件、API 和查詢都列在下面的 [角色 API](#角色-api)。

### 階段 3：和 AI 一起寫技能

可以在自己的資料夾裡新增任何類別，用 `preload` 引用：

```gdscript
# teams/zyzy0826/skills/fireball.gd
extends RefCounted
## 火球：對目標造成傷害

var power: int = 2

func cast(caster: Unit, target: Unit) -> void:
	caster.deal_damage(target, power)
```

```gdscript
# teams/zyzy0826/mage.gd
extends Mage
## 火球法師：普攻之後再丟一顆火球
const Fireball = preload("skills/fireball.gd")

var fireball = Fireball.new()

func _init() -> void:
	unit_name = "火球法師"
	max_hp = 10
	attack = 3
	color = Color("#9575cd")
	grid_position = Vector2i(2, 2)   # 後排右

func on_attack(target: Unit) -> void:
	fireball.cast(self, target)
```

每個角色檔都要有 `_init()` 設定名字、數值和站位，不然會出現「請設定 grid_position」。

也可以讓好幾隻角色繼承自己寫的父類別：`extends "my_base.gd"`。這時子類別的 `_init()` **第一行要寫 `super()`**，不然父類別 `_init()` 裡設定的數值不會生效。

技能還是只能透過戰鬥 API 生效，數值上限和[不能做的事](#不能做的事)也都一樣。請 AI 幫忙時，記得把這份 README 給它看。

## 戰鬥規則

- 雙方各有 **3×3 棋盤**：前排、中排、後排，每排有左、中、右三格。角色站好就**不會移動**
- 每回合每隻角色輪流行動一次，**順序固定**：我方先、Boss 隊伍後；同一隊從前排到後排、每排從左到右。輪到時已經倒下的角色不會行動
- 每回合開始：先回復[能量](#能量)，接著 Boss 發動回合開始的能力（例如雷神蓄力），再結算[中毒](#流派)，然後才輪到角色行動
- 每個動作（一次行動、一層毒發）結束後**馬上**結算倒下的角色：`on_death` → 死靈加成 → 隊友的 `on_ally_death`，全部結算完才輪到下一個動作
- 一方全滅就結束；**打完 30 回合**還沒打倒 Boss 算你輸，同歸於盡也算你輸
- 隨機用固定種子，同樣的隊伍打同樣的 Boss，結果永遠一樣

### 傷害怎麼算

每一次傷害都照這個順序結算：

0. 刺客的閃避：每場第一次被普攻打中時，這一次整個不算（詛咒、護盾都不會用掉）
1. 基礎傷害：普攻是 `attack`，技能是指定的 `amount`
2. 加上攻擊者的增傷，**只對普攻有效**：狂血 4 隻的 +2、戰士衝鋒的 +2、射手弱點射擊的 +1
3. 加上目標身上的詛咒，並用掉詛咒
4. 扣掉目標的護盾（**毒傷跳過這一步**）
5. 坦克分擔：目標相鄰有我方坦克時，坦克承受一半（無條件捨去）；目標本身是坦克時不分擔
6. 扣血

### 職業

角色 `extends` 哪個職業，就照那個職業的規則普攻，也會自動有那個職業的**被動**（不用寫程式）。直接 `extends Unit` 的角色算戰士。

| 職業 | 繼承 | 普攻 | 被動 |
|---|---|---|---|
| 戰士 | `Warrior`（或 `Unit`） | 近戰：打敵方**最前排**，優先打**同一行** | ⚡ **衝鋒**：每場第一次普攻傷害 +2 |
| 坦克 | `Tank` | 近戰，同戰士 | **掩護**：替**上下左右相鄰**的隊友分擔 **50%** 傷害 |
| 射手 | `Archer` | 遠程：可以打**任何一格**，預設打血最少的；覆寫 `choose_target(enemies)` 自己挑 | **弱點射擊**：普攻血量低於一半的目標傷害 +1 |
| 法師 | `Mage` | 打敵方**同一行的所有角色** | **法力湧流**：每回合回復 4 能量（一般是 3） |
| 補師 | `Healer`（法師的子類別） | 不攻擊，幫**相鄰**有受傷的隊友回 `attack` 點血 | **淨化**：普通治療有回到血時，移除目標 1 層中毒 |
| 刺客 | `Assassin` | 打敵方**最後排**，優先打**同一行** | 💨 **閃避**：每場第一次被普攻打中時不受傷害 |

- 「最前排」「最後排」指**還有角色活著**的那一排：前排全滅，近戰就改打中排
- 「同一行」沒有敵人時，改打**最近的一行**，一樣近就打左邊
- 補師不會觸發 `on_attack`；坦克分擔的傷害會觸發坦克自己的 `on_hurt`
- 坦克自己被打時，不會被旁邊的另一隻坦克分擔
- 衝鋒、閃避每場各一次，還沒用掉時角色左下角會顯示 ⚡ / 💨；召喚的分身沒有被動
- 被動的數值寫在 `framework/rules.gd`，陣型預覽的成員清單也會列出每隻角色的被動

### 預算

每隊**最多 5 隻**，**總預算 100 點**：

```
花費 = max_hp + 2 × attack
```

| 屬性 | 範圍 |
|---|---|
| `max_hp` | 1–40 |
| `attack` | 0–10 |

技能不花點數，但要花[能量](#能量)，戰鬥 API 也有數值上限（見下方）。超過預算或違規的隊伍不能上場，陣型預覽會列出原因。

### 能量

- 每隻角色有 `energy`（唯讀），開場 **3 點**，每回合開始回復 **3 點**（法師 4 點），最多存 **6 點**
- 普攻和補師的普通治療**不花能量**；技能 API 要花能量（見[戰鬥 API](#戰鬥-api)）
- 能量不夠時 API 回傳 `false`、技能不生效、也不扣能量，戰鬥紀錄會寫「能量不足」
- 用 `get_energy()` 查現在能用多少（死靈角色在 `on_death` 裡會包含靈魂能量）
- Boss 不用能量

### 流派

在 `_init()` 設定 `school`，不寫就是沒有流派：

```gdscript
func _init() -> void:
	unit_name = "毒蛇射手"
	max_hp = 10
	attack = 2
	grid_position = Vector2i(0, 2)
	school = School.VENOM
```

| 流派 | `school` | 專屬 API | 同隊 2 隻 | 同隊 4 隻（包含 2 隻的效果） |
|---|---|---|---|---|
| 🧪 劇毒 | `School.VENOM` | `poison` | 我方施加的毒傷每回合 +2 | 中毒的敵人**無法被治療**（`heal`、吸血、狂血回血都無效） |
| 🛡️ 聖盾 | `School.AEGIS` | `shield` | 開場全隊 3 點護盾 | 開場全隊 4 點護盾（取代 3 點，不疊加） |
| 🔥 狂血 | `School.BLOOD` | `drain` | 我方普攻命中後，攻擊者回 1 血（免費） | 我方血量低於一半的角色普攻 +2 |
| 💀 死靈 | `School.NECRO` | `curse` | 我方死靈角色死亡時，獲得 6 點**靈魂能量** | 我方死靈角色死亡時，對全體敵人造成 1 點傷害（免費） |

- 流派加成看**開場時**同流派的隻數，之後有人陣亡也不會失去加成；召喚的分身沒有流派
- 誰都能用四個流派 API，但施放者**和 API 同流派是正常價，不同（包含沒有流派）是兩倍價**
- 靈魂能量只在那隻角色的 `on_death()` 裡能用，會先用靈魂能量、不夠再用一般能量，`on_death` 結束就清空
- 死靈 4 隻的全體傷害在 `on_death()` 執行完之後才結算
- 擂台上每隊棋盤上方會顯示啟動的流派加成（例如「🧪 劇毒 4/4」），角色身上會顯示護盾（左邊）、中毒層數和詛咒（右邊）

`teams/` 底下有四個流派的範例隊伍：`example_venom`、`example_aegis`、`example_blood`、`example_necro`。

## 角色 API

### 事件（覆寫這些來做技能）

| 方法 | 什麼時候觸發 |
|---|---|
| `on_battle_start()` | 戰鬥開始時 |
| `on_attack(target)` | 自己攻擊之後 |
| `on_hurt(amount, source)` | 自己受傷之後 |
| `on_death()` | 自己倒下時 |
| `on_ally_death(ally)` | 有隊友倒下時 |
| `on_frame(delta)` | 每一幀，**只能做畫面效果** |

觸發順序和行動順序一樣。血量歸零的角色只會再觸發 `on_death`。

### 戰鬥 API

| 方法 | 效果 | 能量 | 上限 |
|---|---|---|---|
| `deal_damage(target, amount)` | 造成傷害 | `amount` | 每次 1–5 |
| `heal(target, amount)` | 回血 | `amount` | 每次 1–5，不超過 `max_hp` |
| `buff_attack(target, amount)` | 加攻擊 | `amount × 2` | 每次 1–3，最多加到 15 |
| `summon_token(hp, attack)` | 召喚沒有技能的分身到自己的位置（第二隻起放在附近的空格） | 免費 | 只能在 `on_death` 用，合計 `hp + 2×attack ≤ 10` |
| `poison(target, amount, turns)` | 🧪 中毒：目標每回合開始受到 `amount` 傷害，持續 `turns` 回合；**無視護盾**，多次施放會疊成好幾層 | `amount × turns` | — |
| `shield(target, amount)` | 🛡️ 護盾：受到傷害時先扣護盾 | `amount` | 每隻最多 10 點 |
| `drain(target, amount)` | 🔥 吸血：造成 `amount` 傷害，自己回復**實際造成的傷害**那麼多血 | `amount × 2` | 每次 1–5 |
| `curse(target, amount)` | 💀 詛咒：目標下一次受傷時傷害 +`amount`；好幾個詛咒會加總，觸發一次就全部用掉 | `amount` | — |
| `say(text)` | 在戰鬥紀錄說一句話 | 免費 | — |

- 除了 `say`，API 都會回傳 `bool`：`true` 代表生效，能量不足或目標已經倒下等情況回傳 `false`
- 流派 API（`poison`、`shield`、`drain`、`curse`）的能量是**同流派**的價格，不同流派要兩倍
- 每隻角色在**每個事件裡最多呼叫 3 次** API
- 技能造成的傷害會觸發對方的 `on_hurt`，連鎖最多 3 層
- 超出範圍的數值會被自動限制，戰鬥紀錄會用橘字提醒

### 查詢

| 方法 | 回傳 |
|---|---|
| `get_allies()` | 還活著的隊友（包含自己），照行動順序排，最前排在前面 |
| `get_enemies()` | 還活著的敵人，照行動順序排 |
| `get_slot()` | 自己在 `get_allies()` 裡排第幾個 |
| `get_grid_position()` | 自己的格子 `Vector2i(行, 排)` |
| `get_adjacent_allies()` | 上下左右相鄰、還活著的隊友（不含自己） |
| `get_units_in_row(row, enemy)` | 某一排還活著的角色，由左到右；`enemy` 為 `true` 查敵方 |
| `get_units_in_column(col, enemy)` | 某一行還活著的角色，由前排到後排 |
| `get_role()` | 職業名稱，例如 `"射手"` |
| `get_energy()` | 現在能用的能量（`on_death` 裡包含靈魂能量） |
| `get_school_count(school)` | 自己隊伍開場時有幾隻這個流派的角色 |
| `get_poison_stacks()` | 身上有幾層中毒（查別人：`target.get_poison_stacks()`） |
| `energy`、`shield_points`、`curse_points` | 能量、護盾、身上累積的詛咒（唯讀） |
| `get_round()` | 現在第幾回合 |
| `is_alive()` | 是否還活著 |
| `random_int(a, b)`、`random_pick(array)` | 固定種子的隨機 |

### 外觀

`color`、`body_radius`、`status_text`、`position`、`modulate`、`scale` 這些都可以隨便改，不影響戰鬥。動畫請寫在 `on_frame(delta)`：

```gdscript
var t := 0.0

func on_frame(delta: float) -> void:
	t += delta
	position.y = sin(t * 4.0) * 6.0   # 上下浮動
```

## 不能做的事

擂台賽會在講師的電腦上執行全班的程式，所以上場前會掃描你資料夾裡**每一個** `.gd` 檔，出現下面這些就不能上場：

- 用到自己資料夾以外的檔案（`preload`、`extends "路徑"` 都只能指向自己的資料夾）
- `class_name`：全班的類別名稱會撞在一起，自己寫的類別請用 `preload("檔名.gd")`
- `@tool`
- `static var`：每次建立的角色都要一樣，也不能把資料帶到下一場戰鬥
- 系統、檔案、網路、引擎的功能：`OS`、`FileAccess`、`DirAccess`、`load()`、`Engine`、`ProjectSettings`、`Input`、各種 `Server`、`Thread`、`HTTPRequest` 等
- `_process`、`_ready`、`_input` 這類引擎方法：動畫請改用 `on_frame(delta)`
- 在 `on_frame` 裡呼叫戰鬥 API
- 在射手的 `choose_target()` 裡呼叫戰鬥 API（它只負責挑目標）
- `get_tree`、`get_node`、`get_parent`、`$節點`：請用 `get_allies()` / `get_enemies()` 和棋盤查詢
- `set()`、`call()` 這類方法，或任何 `_framework` 開頭的東西
- `randi()`、`randf()`、`shuffle()` 等內建隨機：請用 `random_int()` / `random_pick()`
- `queue_free()`、`add_child()` 等新增或刪除節點的方法
- 在 `_init()` 以外改 `hp`、`max_hp`、`attack`、`grid_position`、`school`（包括 `enemy.hp = 0`）：戰鬥中請用 `deal_damage()`、`heal()`、`buff_attack()`
- 改 `energy`、`energy_regen`、`shield_points`、`curse_points`（連 `_init()` 裡也不行）：護盾請用 `shield()`、詛咒請用 `curse()`
- 三個引號的多行字串
- 繼承 `Boss`

就算繞過掃描，戰鬥中直接改 `hp` 也不會成功，戰鬥紀錄會出現紅字。想想看為什麼要這樣設計？

## Boss

在陣型預覽上方選想挑戰的對象。每隻 Boss 的能力寫在 `bosses/<代號>/boss.gd` 的開頭，打之前先讀一下。

Boss 也站在 3×3 棋盤上，預設站**前排中**，行為和戰士一樣（打你的最前排、優先同一行）。雷神的「雷擊」會打中你**所有**角色。

| 代號 | 名稱 | 能力 | 適合 |
|---|---|---|---|
| `dummy` | 木樁 | 不會反擊，練習看戰鬥紀錄 | 階段 1 |
| `lv1` | 史萊姆王 | 沒有能力，就是一個大血包 | 階段 1：只靠數值和站位就打得贏 |
| `lv2` | 刺甲龜 | 被**普攻**打中會把傷害**全額反彈**；技能和毒不會被反彈 | 階段 2：要用技能打 |
| `lv3` | 雷神 | 平常普攻只造成**一半**傷害；每 3 回合蓄力一次（不攻擊、受傷 ×2），下一回合雷擊打中你所有角色 | 階段 2：把能量留到蓄力回合，還要撐過雷擊 |

Lv2、Lv3 是設計成**只調數值打不贏**的關卡，打輸了就看戰鬥紀錄，想想看要加什麼技能。

卡在 Lv2 的話，可以參考 `teams/example_stage2/`：只用 `deal_damage()` 一招就打得贏刺甲龜，整個資料夾複製過去、改成自己的帳號就能用。

講師可以用 `tools/boss_check.gd` 檢查 Boss 難度：它會產生上千支只有數值的隨機隊伍去打每隻 Boss，再讓同樣數值的隊伍加上基礎技能打一次：

```sh
godot --headless --script res://tools/boss_check.gd
```

## 擂台賽

### 交隊伍

1. Fork 這個專案，在 `teams/<你的 GitHub 帳號>/` 寫好隊伍（資料夾名稱要和帳號一模一樣，包含大小寫）
2. 在自己電腦上跑檢查，全部 ✅ 再發 PR：

   ```sh
   godot --headless --script res://tools/validate.gd -- 你的GitHub帳號
   ```

   這份 README 裡的 `godot` 指的是 Godot 執行檔，要在**專案資料夾**裡執行。沒有把 Godot 加進 PATH 的話，請換成完整路徑：

   **Windows（PowerShell）**：要用檔名有 `console` 的那個，才看得到輸出

   ```powershell
   & "C:\你放Godot的地方\Godot_v4.7.2-stable_win64_console.exe" --headless --script res://tools/validate.gd -- 你的GitHub帳號
   ```

   **Mac（終端機）**：執行檔在 `Godot.app` 裡面，Godot 放在「應用程式」的話是

   ```sh
   /Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/validate.gd -- 你的GitHub帳號
   ```

   Mac 想直接打 `godot` 的話，先執行一次 `echo 'alias godot="/Applications/Godot.app/Contents/MacOS/Godot"' >> ~/.zshrc`，再開一個新的終端機視窗。

   不在專案資料夾裡的話，在 `--headless` 後面加上 `--path "專案資料夾路徑"`。

3. 發 PR，**只改自己的資料夾**

發 PR 後 GitHub Actions 會自動跑同一套檢查（第一次發 PR 要等講師按「Approve and run」）。結果在 PR 的 **Checks** 分頁，點進「檢查學員隊伍」看 Summary，沒通過的地方會寫出檔案、行號和修法：

| 檢查 | 內容 |
|---|---|
| 1. 只修改自己的資料夾 | PR 改到 `teams/<你的帳號>/` 以外的檔案就失敗 |
| 2. 程式碼掃描 | [不能做的事](#不能做的事)；沒通過的話後面都不會執行 |
| 3. 語法 | 每個 `.gd` 都要能編譯 |
| 4. 隊伍設定 | `team.gd`、站位、數值範圍、預算 |
| 5. 試打 Boss Lv1 | 戰鬥要能跑完、技能執行時不能出錯；**輸贏不影響** |

技能裡有無窮迴圈的話，檢查會在 10 分鐘後被中止。

### 對戰規則

- 兩隊交錯行動：先手 1 號 → 後手 1 號 → 先手 2 號 → 後手 2 號 …（號碼照各隊的行動順序），一隊沒人了另一隊就繼續
- 先手由兩隊的 GitHub 帳號決定，同一組對戰每次都是同一隊先手
- 雙方同時全滅，**後手獲勝**
- 超過 30 回合還沒分出勝負，比**剩餘血量比例**（還活著的角色血量總和 ÷ 開場時的 max_hp 總和，召喚的分身不算），一樣多也是後手獲勝

### 開打（講師）

在 `framework/matches.gd` 填入對戰組合，最多 4 組同時開打：

```gdscript
const MATCHES := [
	["帳號A", "帳號B"],
	["帳號C", "帳號D"],
]
```

在陣型預覽按「擂台賽」開始。多組時畫面分成 2×2，點其中一場可以放大，Esc 縮回來。

## 無畫面模擬

不開視窗、直接在終端機印出整場戰鬥紀錄：

```sh
godot --headless --script res://framework/simulate.gd                     # example 打木樁
godot --headless --script res://framework/simulate.gd -- 帳號 lv3         # 指定隊伍和 Boss
godot --headless --script res://framework/simulate.gd -- 帳號A vs 帳號B   # 隊伍對戰
```

- 打 Boss 的結束代碼：`0` 勝利、`2` 落敗、`1` 隊伍沒通過檢查
- 隊伍對戰的最後一行是 JSON，可以給賽程工具讀：

  ```json
  {"left": "帳號A", "right": "帳號B", "first": "帳號A", "winner": "帳號B", "rounds": 12, "reason": "帳號A 全滅"}
  ```

  一隊沒通過檢查時，另一隊不戰而勝；兩隊都沒通過時 `winner` 是空字串，結束代碼為 `1`

### 流派平衡測試

讓隊伍兩兩對戰、每個組合打 100 場（每場用不同的種子決定先手），印出勝率矩陣，並標出整體勝率超過 65% 或低於 35% 的隊伍：

```sh
godot --headless --script res://tools/balance.gd                          # 四個流派範例
godot --headless --script res://tools/balance.gd -- 帳號A 帳號B 帳號C      # 指定隊伍
godot --headless --script res://tools/balance.gd -- --games=200
```

隊伍沒用 `random_int()` / `random_pick()` 的話，同一組對戰只會有「A 先手」「B 先手」兩種結果，勝率會落在 0%、50%、100% 附近，差一滴血就整組翻盤。所以流派範例的射手會在血最少的幾隻敵人裡隨機挑目標，讓 100 場真的有變化。

目前四個流派範例的整體勝率都在 44%–56%，彼此相剋：劇毒剋聖盾（毒無視護盾）、聖盾剋狂血和死靈、狂血剋死靈、死靈剋劇毒。

## 專案結構

```
├── framework/                ← 框架，不要改
│   ├── rules.gd              ← 所有規則數值
│   ├── unit.gd               ← Unit 父類別
│   ├── roles/                ← 職業：Warrior、Tank、Archer、Mage、Healer、Assassin
│   ├── team.gd               ← Team 父類別
│   ├── boss.gd               ← Boss 父類別
│   ├── battle.gd             ← 戰鬥流程
│   ├── validator.gd          ← 程式碼掃描、站位和預算檢查
│   ├── preview/              ← 陣型預覽（主場景）
│   ├── arena_screen.tscn     ← 擂台畫面（一場或 2×2 四場）
│   ├── arena.tscn            ← 單場擂台
│   ├── matches.gd            ← 擂台賽對戰組合（講師用）
│   └── simulate.gd           ← 無畫面模擬
├── tools/validate.gd         ← 隊伍檢查（本機和 GitHub Actions 共用）
├── tools/balance.gd          ← 流派平衡測試
├── tools/boss_check.gd       ← Boss 難度檢查（純數值隊伍 vs 加上技能）
├── .github/workflows/        ← PR 自動檢查
├── bosses/<代號>/boss.gd     ← Boss
└── teams/
    ├── template/             ← 模板：複製這個資料夾開始寫自己的隊伍
    ├── example/              ← 範例隊伍，每種職業都有
    ├── example_stage2/       ← 只用基礎技能打贏 Lv2 的範例
    ├── example_<流派>/       ← 四個流派的範例隊伍（venom、aegis、blood、necro）
    └── <你的 GitHub 帳號>/   ← 你只需要改這裡
        └── team.gd           ← 隊名、帳號、成員
```
