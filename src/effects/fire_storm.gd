class_name FireStorm
extends Node2D
## 炸彈的全螢幕火焰：火牆從畫面下方往上燒滿整個畫面，持續期間清除敵彈並持續灼燒敵機。

const DURATION := 1.8
const TICK := 0.15

var burn_damage := 8
var _t := 0.0
var _tick := 0.0
var _flames: Array = []   # 每個火舌：[x, 相位, 大小, 速度]
var _size := Vector2(720, 1280)


func _ready() -> void:
	_size = get_viewport_rect().size
	z_index = 50
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	for i in 90:
		_flames.append([randf() * _size.x, randf(), randf_range(40, 110), randf_range(0.7, 1.4)])


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	_tick -= delta
	if _tick <= 0.0 and _t < DURATION * 0.85:
		_tick = TICK
		if BulletPool.instance:
			BulletPool.instance.clear_enemy_bullets()
		for node in get_tree().get_nodes_in_group(&"enemies"):
			var e := node as Enemy
			if e and e.is_on_screen():
				e.take_damage(burn_damage)
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	# 火線往上推進（前 35% 時間燒滿畫面），最後 30% 淡出
	var front := _size.y * (1.0 - clampf(k / 0.35, 0.0, 1.0)) - 120.0
	var fade := 1.0 - clampf((k - 0.7) / 0.3, 0.0, 1.0)
	# 整體橘紅色底光
	draw_rect(Rect2(Vector2(0, maxf(front, 0)), _size), Color(0.9, 0.25, 0.05, 0.35 * fade))
	for f in _flames:
		var phase := fmod(f[1] + _t * f[3], 1.0)
		var y: float = lerpf(_size.y + 60.0, front, phase)
		if y < front:
			continue
		var x: float = f[0] + sin(_t * 6.0 + f[1] * 10.0) * 18.0
		var s: float = f[2] * (1.0 - phase * 0.6)
		draw_circle(Vector2(x, y), s, Color(0.8, 0.15, 0.02, 0.35 * fade))
		draw_circle(Vector2(x, y - s * 0.3), s * 0.65, Color(1.0, 0.5, 0.08, 0.4 * fade))
		draw_circle(Vector2(x, y - s * 0.5), s * 0.3, Color(1.0, 0.9, 0.5, 0.45 * fade))
	# 火線前緣的亮帶
	if front > -100.0:
		draw_rect(Rect2(0, front - 30, _size.x, 60), Color(1.0, 0.7, 0.3, 0.35 * fade))
