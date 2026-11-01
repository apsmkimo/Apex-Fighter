extends Node
## 遊戲狀態（Autoload: GameManager）
## 負責：目前選擇的戰機與關卡、分數、殘機、炸彈、火力、存檔、切換畫面。

const SAVE_PATH := "user://save.cfg"

const SCENE_TITLE := "res://src/ui/menus/title_screen.tscn"
const SCENE_SHIP_SELECT := "res://src/ui/menus/ship_select.tscn"
const SCENE_STAGE := "res://src/stages/stage.tscn"
const SCENE_RESULT := "res://src/ui/menus/result_screen.tscn"

var selected_ship: ShipData
var current_stage: StageData
var difficulty: DifficultyData

var score := 0
var hi_score := 0
## 每個難度各自的最高分 { 難度 id: 分數 }
var hi_scores := {}
var lives := 0
var bombs := 0
var power_level := 0
## 目前主武器（開局是戰機預設武器，吃武器道具會換）
var weapon: WeaponData
## 追蹤導彈等級，0 = 沒有
var missile_level := 0
const MAX_MISSILE_LEVEL := 3
## 掉寶輪替計數 { 敵機 id: 次數 }
var drop_counters := {}
var last_run_cleared := false


func _ready() -> void:
	_setup_input_map()
	_load_save()


func set_difficulty(d: DifficultyData) -> void:
	if d == null:
		return
	difficulty = d
	hi_score = int(hi_scores.get(String(d.id), 0))
	Events.hi_score_changed.emit(hi_score)


# ---------- 一局遊戲 ----------

func start_run(ship: ShipData, stage: StageData) -> void:
	selected_ship = ship
	current_stage = stage
	score = 0
	lives = ship.start_lives
	bombs = ship.start_bombs
	power_level = 0
	weapon = ship.weapon
	missile_level = 0
	drop_counters.clear()
	emit_all()


func emit_all() -> void:
	Events.score_changed.emit(score)
	Events.hi_score_changed.emit(hi_score)
	Events.lives_changed.emit(lives)
	Events.bombs_changed.emit(bombs)
	Events.power_changed.emit(power_level, max_power())
	Events.weapon_changed.emit(weapon)
	Events.missile_changed.emit(missile_level)


func max_power() -> int:
	if weapon:
		return weapon.max_level()
	if selected_ship and selected_ship.weapon:
		return selected_ship.weapon.max_level()
	return 1


func add_score(value: int) -> void:
	score += value
	Events.score_changed.emit(score)
	if score > hi_score:
		hi_score = score
		if difficulty:
			hi_scores[String(difficulty.id)] = hi_score
		Events.hi_score_changed.emit(hi_score)


## 被擊落時呼叫。回傳 true 代表還有殘機可以繼續。
func lose_life() -> bool:
	lives -= 1
	power_level = maxi(power_level - 1, 0)
	if missile_level > 0:
		missile_level -= 1
		Events.missile_changed.emit(missile_level)
	Events.lives_changed.emit(maxi(lives, 0))
	Events.power_changed.emit(power_level, max_power())
	return lives > 0


## 火力升級。已經滿級時回傳 false（呼叫端可以改給分數）。
func add_power() -> bool:
	if power_level >= max_power() - 1:
		return false
	power_level += 1
	Events.power_changed.emit(power_level, max_power())
	return true


## 換主武器。拿到同一種武器時改成火力升級。回傳 false 代表全滿（呼叫端改給分數）。
func pick_weapon(w: WeaponData) -> bool:
	if w == null:
		return false
	if weapon == w:
		return add_power()
	weapon = w
	power_level = mini(power_level, max_power() - 1)
	Events.weapon_changed.emit(weapon)
	Events.power_changed.emit(power_level, max_power())
	return true


func add_missile() -> bool:
	if missile_level >= MAX_MISSILE_LEVEL:
		return false
	missile_level += 1
	Events.missile_changed.emit(missile_level)
	return true


## 掉寶輪替：同一種敵機依序掉 pool 裡的道具
func next_drop(enemy_id: StringName, pool: Array) -> Resource:
	if pool.is_empty():
		return null
	var n: int = drop_counters.get(enemy_id, 0)
	drop_counters[enemy_id] = n + 1
	return pool[n % pool.size()]


func add_bomb() -> bool:
	if bombs >= selected_ship.max_bombs:
		return false
	bombs += 1
	Events.bombs_changed.emit(bombs)
	return true


func use_bomb() -> bool:
	if bombs <= 0:
		return false
	bombs -= 1
	Events.bombs_changed.emit(bombs)
	return true


func end_run(cleared: bool) -> void:
	last_run_cleared = cleared
	_save()


# ---------- 畫面切換 ----------

func change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func goto_title() -> void:
	change_scene(SCENE_TITLE)


func goto_ship_select() -> void:
	change_scene(SCENE_SHIP_SELECT)


func goto_stage() -> void:
	change_scene(SCENE_STAGE)


func goto_result() -> void:
	change_scene(SCENE_RESULT)


# ---------- 存檔 ----------

func _load_save() -> void:
	var cfg := ConfigFile.new()
	var last_diff := "normal"
	if cfg.load(SAVE_PATH) == OK:
		# 舊版存檔只有一個 hi_score，視為 NORMAL 的紀錄
		hi_scores["normal"] = int(cfg.get_value("score", "hi_score", 0))
		if cfg.has_section("hi_scores"):
			for key in cfg.get_section_keys("hi_scores"):
				hi_scores[key] = int(cfg.get_value("hi_scores", key, 0))
		last_diff = String(cfg.get_value("settings", "difficulty", "normal"))
	var d := Database.get_difficulty(StringName(last_diff))
	set_difficulty(d if d else Database.default_difficulty())


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "hi_score", int(hi_scores.get("normal", 0)))
	for key in hi_scores:
		cfg.set_value("hi_scores", key, hi_scores[key])
	if difficulty:
		cfg.set_value("settings", "difficulty", String(difficulty.id))
	cfg.save(SAVE_PATH)


# ---------- 按鍵設定（電腦測試用；手機用觸控） ----------

func _setup_input_map() -> void:
	_add_keys(&"move_left", [KEY_LEFT, KEY_A])
	_add_keys(&"move_right", [KEY_RIGHT, KEY_D])
	_add_keys(&"move_up", [KEY_UP, KEY_W])
	_add_keys(&"move_down", [KEY_DOWN, KEY_S])
	_add_keys(&"bomb", [KEY_X, KEY_SPACE])
	_add_keys(&"pause", [KEY_ESCAPE, KEY_P])


func _add_keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
