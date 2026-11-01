class_name StageData
extends Resource
## 一個關卡：背景、波次時間表、Boss。新增關卡：在 data/stages/ 新增 .tres。

@export var id: StringName = &"stage_01"
@export var display_name := "STAGE 1"
@export var sort_order := 0

@export_group("Background")
@export var scroll_speed := 160.0
@export var bg_top_color := Color(0.04, 0.06, 0.16)
@export var bg_bottom_color := Color(0.10, 0.14, 0.30)
@export var bgm: AudioStream

@export_group("Waves")
@export var waves: Array[WaveData] = []

@export_group("Mid Boss")
## 不為空時：波次 → 中階 Boss → waves_after_mid → 最終 Boss
@export var mid_boss: BossData
@export var waves_after_mid: Array[WaveData] = []
## 中階 Boss 之後出現的敵機（含最終 Boss）血量倍率
@export var after_mid_hp_mult := 2.0

@export_group("Boss")
@export var boss: BossData
@export var boss_warning_time := 2.5
