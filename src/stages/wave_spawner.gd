class_name WaveSpawner
extends Node
## 讀取 StageData 的波次時間表，時間到就生成敵機。

signal all_spawned

const ENEMY_SCENE := preload("res://src/entities/enemies/enemy.tscn")
const SPAWN_Y := -50.0

var _queue: Array[Dictionary] = []
var _time := 0.0
var _target: Node
var running := false
var done := false


func start(stage: StageData, target: Node) -> void:
	_target = target
	_time = 0.0
	_queue.clear()
	for wave in stage.waves:
		if wave.enemy == null:
			continue
		for i in wave.count:
			var x := wave.start_x + wave.step_x * i
			_queue.append({ "t": wave.time + wave.interval * i, "wave": wave, "x": x, "flip": false })
			if wave.mirror:
				_queue.append({ "t": wave.time + wave.interval * i, "wave": wave, "x": 1.0 - x, "flip": true })
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	running = true
	done = _queue.is_empty()


func _physics_process(delta: float) -> void:
	if not running or done:
		return
	_time += delta
	while not _queue.is_empty() and _queue[0].t <= _time:
		_spawn(_queue.pop_front())
	if _queue.is_empty():
		done = true
		all_spawned.emit()


func _spawn(entry: Dictionary) -> void:
	var wave: WaveData = entry.wave
	var width := _target.get_viewport().get_visible_rect().size.x
	var pos := Vector2(clampf(entry.x, 0.0, 1.0) * width, SPAWN_Y)
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.setup(wave.enemy, pos, wave.movement_override, entry.flip)
	_target.add_child(enemy)
