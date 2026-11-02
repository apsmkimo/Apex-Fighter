class_name MissileLauncher
extends Node2D
## 副武器：自動追蹤導彈。等級 0 = 沒有；每拿一個 M 道具 +1 級，沒有上限。
## 每級每輪多 2 發，最多 MAX_SHOTS 發；之後每級導彈傷害 +1。

const MAX_SHOTS := 12
const INTERVAL := 0.75
const DAMAGE := 3

var level := 0
var firing := false
var _cooldown := 0.4


static func shots_for(lv: int) -> int:
	return mini(lv * 2, MAX_SHOTS)


static func damage_for(lv: int) -> int:
	return DAMAGE + maxi(lv - MAX_SHOTS / 2, 0)


func _physics_process(delta: float) -> void:
	if level <= 0 or not firing:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = INTERVAL
	# SMCPKG_SUPPORT>>>CursorM9Missile
	Events.missile_fired.emit()
	# SMCPKG_SUPPORT<<<CursorM9MissileEnd
	# 導彈放在玩家所在的節點（Actors），才不會跟著戰機移動
	var stage := get_parent().get_parent()
	var n := shots_for(level)
	var dmg := damage_for(level)
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := i / 2
		Missile.launch(stage, global_position + Vector2(side * (22 + row * 8), 10 + row * 10), side * maxf(1.0 - row * 0.15, 0.2), dmg)
