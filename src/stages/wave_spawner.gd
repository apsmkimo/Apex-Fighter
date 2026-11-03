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
## 砲台封鎖中：時間表暫停，地圖暫停捲動
var holding := false
signal hold_started
var _gate: Array[Enemy] = []


func start(stage: StageData, target: Node) -> void:
	start_waves(stage.waves, target)


## 從頭開始跑一組波次（中階 Boss 之後的第二段也用這個）
func start_waves(waves: Array[WaveData], target: Node) -> void:
	_target = target
	_time = 0.0
	_queue.clear()
	for wave in waves:
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
	_gate = _gate.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and not e.health.dead)
	var was := holding
	holding = false
	for e in _gate:
		if e.ground_stopped:
			holding = true
	if holding and not was:
		hold_started.emit()
	if not _gate.is_empty():
		# 封鎖砲台還沒全滅：不往下排程
		if holding:
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
	if wave.hold:
		var h := _target.get_viewport().get_visible_rect().size.y
		enemy.ground_stop_y = h * (0.22 + 0.06 * float(_gate.size() % 2))
		_gate.append(enemy)
	_target.add_child(enemy)
