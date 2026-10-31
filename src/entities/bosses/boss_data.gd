class_name BossData
extends EnemyData
## Boss 設定：在 EnemyData 之上加入多階段彈幕。

@export var boss_name := "BOSS"
## 進場時間，這段時間內無敵、不開火
@export var entry_time := 3.0
@export var phases: Array[BossPhase] = []
