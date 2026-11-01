class_name PowerAura
extends Node2D
## 火力等級的視覺變化（掛在玩家身上，加亮混合）。
## level 是 GameManager.power_level（0 = POWER 1）。等級越高疊加越多效果：
##   POWER 2+：翼端閃爍燈
##   POWER 3+：繞機身旋轉的能量線
##   POWER 4+：機身核心脈動光
##   POWER 5+：淡淡的六角能量護罩
##   POWER 7+：環繞能量球（每 2 級多一顆，最多 4 顆）

var level := 0:
	set(v):
		level = v
		visible = v > 0
var color := Color(0.35, 0.8, 1.0)
## 機身大小（貼圖尺寸），決定燈與光環的位置
var hull := Vector2(64, 100)
var _t := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	visible = level > 0


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var tex := NeonFx.get_glow_tex()
	var c := color
	var w := hull.x * 0.5
	var h := hull.y * 0.5
	# 翼端燈：左右交替閃
	if level >= 1:
		for side: float in [-1.0, 1.0]:
			var on := 0.35 + 0.65 * maxf(0.0, sin(_t * 8.0 + (0.0 if side < 0.0 else PI)))
			var p := Vector2(side * w * 0.82, h * 0.25)
			draw_texture_rect(tex, Rect2(p - Vector2(9, 9), Vector2(18, 18)), false, Color(c.r, c.g, c.b, on))
			draw_texture_rect(tex, Rect2(p - Vector2(3, 3), Vector2(6, 6)), false, Color(1, 1, 1, on))
	# 能量線：兩段弧線繞著機身轉
	if level >= 2:
		var r := maxf(w, h) * 0.95
		for i in 2:
			var a := _t * 2.4 + PI * i
			draw_arc(Vector2.ZERO, r, a, a + 0.9, 14, Color(c.r, c.g, c.b, 0.55), 2.5)
			draw_arc(Vector2.ZERO, r + 5.0, a + 0.2, a + 0.6, 8, Color(1, 1, 1, 0.35), 1.5)
	# 核心脈動光
	if level >= 3:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		var s := 16.0 + 8.0 * pulse
		draw_texture_rect(tex, Rect2(Vector2(-s, -s + h * 0.1), Vector2(s * 2.0, s * 2.0)), false, Color(c.r, c.g, c.b, 0.35 + 0.25 * pulse))
	# 六角能量護罩（純裝飾，不影響判定）
	if level >= 4:
		var r2 := maxf(w, h) * 1.15
		var pts := PackedVector2Array()
		for i in 7:
			var a := -_t * 0.6 + TAU * i / 6.0
			pts.append(Vector2(cos(a), sin(a)) * r2)
		draw_polyline(pts, Color(c.r, c.g, c.b, 0.18 + 0.08 * sin(_t * 3.0)), 2.0, true)
	# 環繞能量球
	if level >= 6:
		var n := mini(1 + (level - 6) / 2 + 1, 4)
		var r3 := maxf(w, h) * 1.25
		for i in n:
			var a := _t * 3.0 + TAU * i / n
			var p := Vector2(cos(a), sin(a) * 0.8) * r3
			draw_texture_rect(tex, Rect2(p - Vector2(10, 10), Vector2(20, 20)), false, Color(c.r, c.g, c.b, 0.8))
			draw_texture_rect(tex, Rect2(p - Vector2(4, 4), Vector2(8, 8)), false, Color(1, 1, 1, 0.9))
