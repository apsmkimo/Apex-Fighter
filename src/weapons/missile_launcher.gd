class_name MissileLauncher
extends Node2D
## 副武器：自動追蹤導彈。等級 0 = 沒有；拿到 M 道具升級（最高 MAX_LEVEL）。

const MAX_LEVEL := 3
## 各等級每輪發射數
const SHOTS := [0, 2, 4, 6]
const INTERVAL := 0.75
const DAMAGE := 3

var level := 0
var firing := false
var _cooldown := 0.4


func _physics_process(delta: float) -> void:
	if level <= 0 or not firing:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = INTERVAL
	# 導彈放在玩家所在的節點（Actors），才不會跟著戰機移動
	var stage := get_parent().get_parent()
	var n: int = SHOTS[clampi(level, 0, MAX_LEVEL)]
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := i / 2
		Missile.launch(stage, global_position + Vector2(side * (22 + row * 8), 10 + row * 10), side * (1.0 - row * 0.25), DAMAGE)
