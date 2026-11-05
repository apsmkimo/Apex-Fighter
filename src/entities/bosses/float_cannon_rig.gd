class_name FloatCannonRig
extends Node2D
## 大 Boss 背後的浮游砲：每座是一個獨立的 Enemy（可被打掉），平常跟在 Boss 身後的固定位置、
## 砲口自動追蹤玩家射擊；絕招時由 BlackGoldUlt 接管位置（override）。

var boss: Boss
var drones: Array = []          # Enemy 或 null（已被打掉）
## 絕招接管：每座的目標位置（世界座標）；空的 = 回到身後
var override_targets: Array[Vector2] = []
## 接管時砲口朝向這個點（INF = 照常朝玩家）
var face_point := Vector2.INF
var _t := 0.0


func _ready() -> void:
	_spawn.call_deferred()


func _spawn() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var bd := boss.boss_data()
	for slot in bd.float_slots:
		var e := Enemy.spawn_enemy(bd.float_cannon, boss.global_position + slot, boss.get_parent())
		if e:
			e.persistent = true
			e.z_index = 2   # Boss 本體（z 3）後面
		drones.append(e)


func alive_count() -> int:
	var n := 0
	for i in drones.size():
		if _alive(i):
			n += 1
	return n


func _alive(i: int) -> bool:
	var e: Variant = drones[i]
	return e != null and is_instance_valid(e) and not (e as Enemy).health.dead


func drone_pos(i: int) -> Vector2:
	return (drones[i] as Enemy).global_position if _alive(i) else Vector2.INF


func _physics_process(delta: float) -> void:
	_t += delta
	if boss == null or boss.health.dead:
		return
	var bd := boss.boss_data()
	var pl := Player.instance
	var overriding := not override_targets.is_empty()
	for i in drones.size():
		if not _alive(i):
			continue
		var e := drones[i] as Enemy
		var target: Vector2
		if overriding:
			target = override_targets[i % override_targets.size()]
		else:
			target = boss.global_position + bd.float_slots[i] + Vector2(sin(_t * 1.7 + i) * 6.0, cos(_t * 1.3 + i * 0.7) * 8.0)
		e.global_position = e.global_position.lerp(target, minf(1.0, (4.0 if overriding else 7.0) * delta))
		e.hold_fire = overriding or boss.age < bd.entry_time
		var look := face_point if overriding and face_point != Vector2.INF else (pl.global_position if pl and pl.alive else e.global_position + Vector2.DOWN)
		e.sprite.rotation = lerp_angle(e.sprite.rotation, (look - e.global_position).angle() - PI / 2.0, minf(1.0, 6.0 * delta))


func _exit_tree() -> void:
	# Boss 倒下：剩下的浮游砲一起爆炸
	for i in drones.size():
		if _alive(i):
			var e := drones[i] as Enemy
			if NeonFx.instance:
				NeonFx.instance.explode(e.global_position, 1.4)
			e.queue_free()
