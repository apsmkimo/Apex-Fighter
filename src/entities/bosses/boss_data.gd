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
