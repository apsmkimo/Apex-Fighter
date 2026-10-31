class_name Explosion
extends Node2D
## 程式繪製的爆炸：火球 + 擴散光環 + 碎片。之後可以換成序列圖或粒子。

const DURATION := 0.45

var size_scale := 1.0
var _t := 0.0
var _debris: Array = []


func _ready() -> void:
	for i in 10:
		_debris.append(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80, 220))


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	var s := size_scale
	draw_circle(Vector2.ZERO, 34.0 * s * (0.4 + k), Color(1.0, 0.75, 0.3, 1.0 - k))
	draw_circle(Vector2.ZERO, 18.0 * s * (1.0 - k * 0.5), Color(1, 1, 0.9, 1.0 - k))
	draw_arc(Vector2.ZERO, 70.0 * s * k, 0, TAU, 32, Color(1, 0.6, 0.3, 1.0 - k), 3.0)
	for d in _debris:
		draw_circle(d * k * s, 3.0, Color(1, 0.8, 0.4, 1.0 - k))
