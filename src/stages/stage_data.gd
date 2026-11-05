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
## 星球關卡的地表圖（往下捲動，上下鏡像接起來）。留空 = 太空背景
@export var terrain: Texture2D
@export var terrain_tint := Color(0.8, 0.8, 0.8)
## 地表上方飄過的裝飾（例如隕石），比地表捲得快，做出視差；碰不到
## 遠景視差層（畫在地表下面，捲得比較慢）
@export var terrain_far: Texture2D
@export var terrain_far_tint := Color(0.6, 0.6, 0.6)
@export var terrain_far_speed := 0.4
@export var float_decor: Array[Texture2D] = []

@export_group("Difficulty")
## 整關敵人（含 Boss）血量倍率，後面的關卡越硬
@export var hp_mult := 1.0
# SMCPKG_SUPPORT>>>CursorM9Bgm
# @export var bgm: AudioStream
## 這個關卡的 BGM。留空就用 MusicCatalog 的 stage。換成同名音檔即可替換。
@export var bgm: AudioStream
# SMCPKG_SUPPORT<<<CursorM9BgmEnd

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
