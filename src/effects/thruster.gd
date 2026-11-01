class_name Thruster
extends Node2D
## 引擎火焰（程式繪製、加亮混合）。throttle：0 = 熄火只剩餘光，1 = 一般，約 1.8 = 全力衝刺。

var color := Color(0.3, 0.9, 1.0)
var width := 10.0
var length := 26.0
## 火焰噴出的方向（玩家朝下、Boss 朝上）
var direction := Vector2.DOWN
var throttle := 1.0

var _t := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = -1   # 畫在機身後面
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, direction.angle() - PI / 2.0)
	# 引擎口餘光（熄火也會有）
	draw_circle(Vector2.ZERO, width * 0.4, Color(color.r, color.g, color.b, 0.35))
	if throttle < 0.05:
		return
	var flick := 0.88 + 0.12 * sin(_t * 47.0) + 0.06 * sin(_t * 113.0)
	var l := length * throttle * flick
	var bright := clampf(throttle, 0.0, 1.6)
	_flame(width * 1.5, l, Color(color.r, color.g, color.b, 0.28 * bright))
	_flame(width, l * 0.8, Color(color.r, color.g, color.b, 0.75 * minf(bright, 1.0)))
	_flame(width * 0.45, l * 0.5, Color(1, 1, 1, 0.9))


## 一層水滴形火焰：引擎口寬、尾端尖。往 +Y 方向畫（外面已經旋轉好）
func _flame(w: float, l: float, c: Color) -> void:
	var h := w / 2.0
	var pts := PackedVector2Array([
		Vector2(-h, 0), Vector2(-h * 0.9, l * 0.25), Vector2(-h * 0.55, l * 0.6), Vector2(0, l),
		Vector2(h * 0.55, l * 0.6), Vector2(h * 0.9, l * 0.25), Vector2(h, 0)])
	draw_colored_polygon(pts, c)
