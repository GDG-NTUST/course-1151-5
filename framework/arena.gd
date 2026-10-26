extends Node2D
## 一場戰鬥的畫面：檢查隊伍、建立 Battle，一回合一回合播放。
## 上半部是右邊隊伍（或 Boss）的棋盤，前排在下面；下半部是左邊隊伍（或我方）的棋盤，前排在上面。
##
## 由 arena_screen.gd 建立後呼叫 setup_boss() 或 setup_versus()；
## 擂台賽同時播好幾場時會縮小，並切換成 compact 模式（只顯示最近幾行戰鬥紀錄）。

const STEP_TIME: float = 0.9      # 每回合至少停這麼久
const ACTION_GAP: float = 0.16    # 同一回合裡，每隻角色行動之間的間隔
const BOARD_X: float = 320.0      # 棋盤中心的 x
const BOARD_TOP: float = 56.0
const CELL_W: float = 180.0
const ROW_H: float = 84.0
const MID_GAP: float = 40.0       # 兩個棋盤中間的空隙（下半部隊伍的流派加成寫在這裡）
const UNIT_SCALE: float = 0.62
const LUNGE: float = 26.0         # 攻擊時往目標衝多遠
const COMPACT_LINES: int = 8      # compact 模式顯示幾行戰鬥紀錄

@onready var units_root: Node2D = $Units
@onready var title_label: Label = $UI/Title
@onready var banner: Label = $UI/Banner
@onready var log_label: RichTextLabel = $UI/Log
@onready var help_label: Label = $UI/Help

var battle: Battle
var holders: Dictionary = {}      # Unit -> 包住它的 Node2D（框架移動 holder，學員的 on_frame 只動 Unit 自己）
var speed: float = 1.0
var paused: bool = false
var compact: bool = false
var _lines: Array[String] = []    # 全部的戰鬥紀錄，切換 compact 時重畫
var _timer: float = 0.0
var _wait: float = STEP_TIME
var _fx_delay: float = 0.0        # 這回合下一個畫面效果要延遲多久才播
var _copy_button: Button


func _ready() -> void:
	# 複製整場戰鬥紀錄到剪貼簿，方便貼給 AI 或同學看
	_copy_button = Button.new()
	_copy_button.text = "複製紀錄"
	_copy_button.focus_mode = Control.FOCUS_NONE   # 不搶焦點，空白鍵才會是暫停而不是按按鈕
	_copy_button.position = Vector2(1032.0, 614.0)
	_copy_button.size = Vector2(108.0, 30.0)
	_copy_button.pressed.connect(_copy_log)
	$UI.add_child(_copy_button)


## 我方隊伍挑戰 Boss
func setup_boss(github: String, boss_key: String) -> void:
	if not Rules.BOSSES.has(boss_key):
		show_errors(["Boss 要是 %s 其中一個，現在是 \"%s\"" % [", ".join(Rules.BOSSES.keys()), boss_key]])
		return
	var errors: Array[String] = Validator.check_team_folder(github)
	if not errors.is_empty():
		show_errors(errors)
		return

	var team: Team = Team.load_folder(github)
	var boss_script: Script = load(Rules.BOSSES[boss_key])
	var new_battle: Battle = Battle.new(team.members, [boss_script])
	errors = Validator.check_side(new_battle, Battle.PLAYER, github)
	if not errors.is_empty():
		_discard(new_battle)
		show_errors(errors)
		return
	var cost: String = Validator.describe_cost(new_battle.created[Battle.PLAYER])   # 開打前算，on_battle_start 可能加攻擊
	_start(new_battle)
	var boss_name: String = battle.teams[Battle.ENEMY][0].unit_name
	title_label.text = "挑戰：%s　　%s：%s" % [boss_name, team.label(), cost]


## 兩隊對戰：left 在下半部（藍）、right 在上半部（紅）
func setup_versus(left: String, right: String) -> void:
	var errors: Array[String] = []
	for github: String in [left, right]:
		for error: String in Validator.check_team_folder(github):
			errors.append("%s：%s" % [github, error])
	if not errors.is_empty():
		show_errors(errors)
		title_label.text = "%s vs %s：有隊伍沒通過檢查" % [left, right]
		return

	var left_team: Team = Team.load_folder(left)
	var right_team: Team = Team.load_folder(right)
	var new_battle: Battle = Battle.new(left_team.members, right_team.members)
	var sides: Array[String] = [left, right]
	for side: int in [Battle.PLAYER, Battle.ENEMY]:
		for error: String in Validator.check_side(new_battle, side, sides[side]):
			errors.append("%s：%s" % [sides[side], error])
	if not errors.is_empty():
		_discard(new_battle)
		show_errors(errors)
		title_label.text = "%s vs %s：有隊伍沒通過檢查" % [left, right]
		return
	new_battle.setup_versus(left, right)
	_start(new_battle)
	title_label.text = "藍 %s　vs　紅 %s　　先手：%s" % [left_team.label(), right_team.label(),
			new_battle.side_names[new_battle.first_team]]


## 沒通過檢查、不會開打的戰鬥：角色還沒放進場景，要自己釋放
func _discard(rejected: Battle) -> void:
	for unit: Unit in rejected.roster:
		unit.free()


func _start(new_battle: Battle) -> void:
	battle = new_battle
	battle.logged.connect(_on_logged)
	battle.unit_added.connect(_add_holder)
	battle.unit_died.connect(_on_unit_died)
	battle.unit_damaged.connect(_on_unit_damaged)
	battle.unit_healed.connect(_on_unit_healed)
	battle.unit_acted.connect(_on_unit_acted)
	battle.finished.connect(_on_finished)
	for team_units: Array in battle.teams:
		for unit: Unit in team_units:
			_add_holder(unit)
	_fx_delay = 0.0
	battle.start()
	queue_redraw()


func set_compact(value: bool) -> void:
	compact = value
	help_label.visible = not compact
	_copy_button.visible = not compact
	title_label.add_theme_font_size_override("font_size", 34 if compact else 20)
	log_label.add_theme_font_size_override("normal_font_size", 26 if compact else 16)
	log_label.add_theme_font_size_override("bold_font_size", 26 if compact else 16)
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE if compact else Control.MOUSE_FILTER_STOP
	_redraw_log()


func _process(delta: float) -> void:
	if battle == null or battle.result != "" or paused:
		return
	_timer += delta * speed
	if _timer >= _wait:
		_timer = 0.0
		_fx_delay = 0.0
		battle.step()
		_wait = maxf(STEP_TIME, _fx_delay + 0.4)


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for team: int in [Battle.PLAYER, Battle.ENEMY]:
		var tint: Color = Color(Battle.TEAM_COLORS[team])
		for row: int in Rules.GRID_ROWS:
			for col: int in Rules.GRID_COLS:
				var center: Vector2 = cell_position(team, Vector2i(col, row))
				var rect: Rect2 = Rect2(center - Vector2(CELL_W - 10.0, ROW_H - 8.0) / 2.0, Vector2(CELL_W - 10.0, ROW_H - 8.0))
				draw_rect(rect, Color(tint, 0.06))
				draw_rect(rect, Color(tint, 0.18), false, 1.0)
			var y: float = cell_position(team, Vector2i(0, row)).y
			draw_string(font, Vector2(8.0, y + 5.0), Rules.ROW_NAMES[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.35))
	var mid_y: float = BOARD_TOP + ROW_H * Rules.GRID_ROWS + MID_GAP / 2.0
	draw_line(Vector2(40.0, mid_y), Vector2(BOARD_X * 2.0 - 10.0, mid_y), Color(1, 1, 1, 0.12), 2.0)

	# 每隊棋盤上方：啟動中的流派加成，例如「🧪 劇毒 2/4」
	if battle == null:
		return
	for team: int in [Battle.PLAYER, Battle.ENEMY]:
		var parts: Array[String] = []
		for school: int in range(1, Rules.SCHOOL_NAMES.size()):
			if battle.school_tier(team, school) > 0:
				parts.append("%s %s %d/%d" % [Rules.SCHOOL_ICONS[school], Rules.SCHOOL_NAMES[school],
						battle.school_count(team, school), Rules.SCHOOL_TIERS[-1]])
		if parts.is_empty():
			continue
		var top: float = cell_position(team, Vector2i(0, Rules.GRID_ROWS - 1 if team == Battle.ENEMY else 0)).y - ROW_H / 2.0
		draw_string(font, Vector2(40.0, top - 6.0), "　".join(parts), HORIZONTAL_ALIGNMENT_RIGHT,
				BOARD_X * 2.0 - 50.0, 15, Color(Battle.TEAM_COLORS[team]))


## 格子在畫面上的中心點
func cell_position(team: int, cell: Vector2i) -> Vector2:
	var x: float = BOARD_X + (cell.x - 1) * CELL_W
	var row_from_top: int = (Rules.GRID_ROWS - 1 - cell.y) if team == Battle.ENEMY else cell.y
	var top: float = BOARD_TOP if team == Battle.ENEMY else BOARD_TOP + ROW_H * Rules.GRID_ROWS + MID_GAP
	return Vector2(x, top + (row_from_top + 0.5) * ROW_H)


# ---------------------------------------------------------------- 畫面

func _add_holder(unit: Unit) -> void:
	var holder: Node2D = Node2D.new()
	holder.position = cell_position(unit._framework_team, unit.grid_position)
	holder.scale = Vector2.ONE * UNIT_SCALE
	holder.add_child(unit)
	units_root.add_child(holder)
	holders[unit] = holder


## 等 delay 秒（會跟著倍速變快）再呼叫 callback；綁在擂台上，重新開始時會一起取消
func _later(delay: float, callback: Callable) -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(maxf(0.001, delay / speed))
	tween.tween_callback(callback)


func _popup(unit: Unit, text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = holders[unit].position + Vector2(-12.0, -unit.body_radius * UNIT_SCALE - 30.0)
	add_child(label)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 34.0, 0.8 / speed)
	tween.tween_property(label, "modulate:a", 0.0, 0.8 / speed).set_delay(0.3 / speed)
	tween.chain().tween_callback(label.queue_free)


func _on_unit_acted(unit: Unit, target: Unit) -> void:
	_fx_delay += ACTION_GAP
	_later(_fx_delay, _play_lunge.bind(unit, target))


func _play_lunge(unit: Unit, target: Unit) -> void:
	var holder: Node2D = holders[unit]
	var home: Vector2 = cell_position(unit._framework_team, unit.grid_position)
	var to_target: Vector2 = holders[target].position - home
	var offset: Vector2 = to_target.normalized() * minf(LUNGE, to_target.length() * 0.5)
	var tween: Tween = create_tween()
	tween.tween_property(holder, "position", home + offset, 0.08 / speed).set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "position", home, 0.14 / speed).set_ease(Tween.EASE_IN)


func _on_unit_damaged(unit: Unit, amount: int) -> void:
	_later(_fx_delay + 0.08, _play_hurt.bind(unit, amount))


func _play_hurt(unit: Unit, amount: int) -> void:
	_popup(unit, "-%d" % amount, Color("#ff6b5e"))
	var holder: Node2D = holders[unit]
	holder.modulate = Color(1.0, 0.3, 0.3)
	create_tween().tween_property(holder, "modulate", Color.WHITE, 0.3 / speed)


func _on_unit_healed(unit: Unit, amount: int) -> void:
	_later(_fx_delay + 0.08, _popup.bind(unit, "+%d" % amount, Color("#6ee36e")))


func _on_unit_died(unit: Unit) -> void:
	_later(_fx_delay + 0.3, _play_death.bind(unit))


func _play_death(unit: Unit) -> void:
	var holder: Node2D = holders[unit]
	var tween: Tween = create_tween()
	tween.tween_property(holder, "modulate:a", 0.0, 0.4 / speed)
	tween.tween_callback(holder.hide)


func _on_logged(text: String) -> void:
	_lines.append(text)
	if compact:
		_redraw_log()
	else:
		log_label.append_text(text + "\n")


func _redraw_log() -> void:
	log_label.clear()
	var shown: Array[String] = _lines.slice(-COMPACT_LINES) if compact else _lines
	for line: String in shown:
		log_label.append_text(line + "\n")


## 去掉顏色、粗體等 BBCode，標題放第一行
func _copy_log() -> void:
	var tags: RegEx = RegEx.create_from_string(r"\[/?(b|i|u|color)(=[^\]]*)?\]")
	var text: String = tags.sub("\n".join(_lines), "", true).replace("[lb]", "[").replace("[rb]", "]")
	DisplayServer.clipboard_set("%s\n%s" % [title_label.text, text])
	_copy_button.text = "已複製 douob"
	var tween: Tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(func() -> void: _copy_button.text = "複製紀錄")


func _on_finished(result: String) -> void:
	if battle.versus:
		banner.text = "%s 獲勝！douob" % battle.side_names[battle.winner]
		banner.add_theme_color_override("font_color", Color("#ffd75e"))
	else:
		banner.text = "勝利！douob" if result == "win" else "落敗…qonop"
		banner.add_theme_color_override("font_color", Color("#ffd75e") if result == "win" else Color("#ff8a80"))
	_later(_fx_delay + 0.4, banner.show)


func show_errors(errors: Array[String]) -> void:
	title_label.text = "隊伍沒有通過檢查，改好程式後按 Esc 回陣型預覽"
	banner.text = "無法上場 qonop"
	banner.add_theme_color_override("font_color", Color("#ff8a80"))
	banner.show()
	for error: String in errors:
		_on_logged("[color=#ff5252]✗ %s[/color]" % error)
