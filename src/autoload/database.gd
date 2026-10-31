extends Node
## 資料庫（Autoload: Database）
## 啟動時自動掃描 data/ships 與 data/stages。
## 新增戰機或關卡：把新的 .tres 放進資料夾即可，不必改程式。

const SHIP_DIR := "res://data/ships/"
const STAGE_DIR := "res://data/stages/"
const DIFFICULTY_DIR := "res://data/difficulty/"

var ships: Array[ShipData] = []
var stages: Array[StageData] = []
var difficulties: Array[DifficultyData] = []


func _ready() -> void:
	for res in _load_dir(SHIP_DIR):
		if res is ShipData:
			ships.append(res)
	for res in _load_dir(STAGE_DIR):
		if res is StageData:
			stages.append(res)
	for res in _load_dir(DIFFICULTY_DIR):
		if res is DifficultyData:
			difficulties.append(res)
	difficulties.sort_custom(func(a: DifficultyData, b: DifficultyData) -> bool: return a.sort_order < b.sort_order)
	ships.sort_custom(func(a: ShipData, b: ShipData) -> bool: return a.sort_order < b.sort_order)
	stages.sort_custom(func(a: StageData, b: StageData) -> bool: return a.sort_order < b.sort_order)


func get_ship(id: StringName) -> ShipData:
	for s in ships:
		if s.id == id:
			return s
	return null


func get_difficulty(id: StringName) -> DifficultyData:
	for d in difficulties:
		if d.id == id:
			return d
	return null


## 預設難度：NORMAL，找不到就用第一個
func default_difficulty() -> DifficultyData:
	var d := get_difficulty(&"normal")
	if d == null and not difficulties.is_empty():
		d = difficulties[0]
	return d


func first_stage() -> StageData:
	return stages[0] if not stages.is_empty() else null


func _load_dir(path: String) -> Array:
	var out := []
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Database: cannot open %s" % path)
		return out
	for file in dir.get_files():
		# 匯出成 APK 後檔名會變成 .tres.remap，要去掉後綴再 load
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(path + file)
			if res:
				out.append(res)
	return out
