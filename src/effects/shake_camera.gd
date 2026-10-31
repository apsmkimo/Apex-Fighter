class_name ShakeCamera
extends Camera2D
## 畫面震動。透過 Events.screen_shake 觸發。

var _strength := 0.0
var _time := 0.0
var _duration := 0.0


func shake(strength: float, duration: float) -> void:
	if strength >= _strength * (_time / maxf(_duration, 0.001)):
		_strength = strength
		_duration = duration
		_time = duration


func _process(delta: float) -> void:
	if _time <= 0.0:
		offset = Vector2.ZERO
		return
	_time -= delta
	var k := _time / _duration
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _strength * k
