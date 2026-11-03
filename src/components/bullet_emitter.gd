class_name BulletEmitter
extends Node2D
## 發射組件：依照 BulletPattern 定時開火。敵機和 Boss 共用。

@export var pattern: BulletPattern
@export var interval := 1.0
var enabled := true
## 打到玩家時扣的血；-1 = 用彈幕本身的設定
var bullet_damage := -1

var _timer := 0.5
var _shot_index := 0
var _burst_left := 0
var _burst_timer := 0.0


## 開火音效大小（-1 = 不出聲）
var sfx_size := -1

func configure(p: BulletPattern, fire_interval: float, first_delay: float) -> void:
	pattern = p
	interval = fire_interval
	_timer = first_delay
	_shot_index = 0
	_burst_left = 0


func _physics_process(delta: float) -> void:
	if not enabled or pattern == null:
		return
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_shoot()
			_burst_left -= 1
			_burst_timer = pattern.burst_interval
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval
		_burst_left = maxi(pattern.burst_count, 1)
		_burst_timer = 0.0


func _shoot() -> void:
	var target := global_position + Vector2.DOWN * 100.0
	if Player.instance and Player.instance.alive:
		target = Player.instance.global_position
	pattern.fire(global_position, target, _shot_index, bullet_damage)
	if sfx_size >= 0:
		Events.enemy_fired.emit(sfx_size)
	_shot_index += 1
