class_name BossData
extends EnemyData
## Boss 設定：在 EnemyData 之上加入多階段彈幕。

@export var boss_name := "BOSS"
## 進場時間，這段時間內無敵、不開火
@export var entry_time := 3.0
@export var phases: Array[BossPhase] = []

@export_group("Ultimate")
## 大絕招：先儲備能量，再往下發射大範圍雷射
@export var ult_enabled := true
## 進場後第一次大絕招的時間
@export var ult_first_delay := 9.0
## 兩次大絕招間隔（從上一次結束算起）
@export var ult_interval := 14.0
@export var ult_charge_time := 2.6
@export var ult_fire_time := 1.6
## 雷射寬度（像素）
@export var ult_width := 210.0
## 打到玩家扣的血（玩家 6 血：滿血只擋得住一次）
@export var ult_damage := 4
## 砲口位置（相對 Boss 中心）
@export var ult_origin := Vector2(0, 80)
@export var ult_color := Color(1.0, 0.25, 0.85)
## 大絕招種類，依序輪流使用：beam = 往下大範圍雷射、eye_laser = 紅眼掃射雷射、web = 吐絲封住行動
@export var ult_kinds: Array[StringName] = [&"beam"]

@export_subgroup("Eye Laser")
## 眼睛位置（相對 Boss 中心）
@export var ult_eye_offset := Vector2(0, -20)
@export var ult_eye_width := 44.0
## 掃射角度範圍（度）
@export var ult_eye_sweep_deg := 34.0
@export var ult_eye_charge := 2.0
@export var ult_eye_fire := 1.8

@export_subgroup("Web")
## 吐絲位置（相對 Boss 中心）
@export var ult_web_origin := Vector2(0, 90)
@export var ult_web_count := 5
@export var ult_web_spread_deg := 60.0
@export var ult_web_speed := 270.0
## 被絲網黏住無法移動的秒數（左右滑動可以提早掙脫）
@export var ult_web_stun := 2.2
@export var ult_web_charge := 1.2
