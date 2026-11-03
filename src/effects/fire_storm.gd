class_name FireStorm
extends Node2D
## 炸彈的全螢幕特效。七台戰機各有一種風格（ShipData.bomb_style），
## 效果都一樣：持續期間清除敵彈並持續灼燒畫面內所有敵機。
## 0 烈焰（火牆往上燒）1 日冕新星（火環從戰機擴散）2 雷暴（落雷滿天）
## 3 神盾衝擊波（多層六角衝擊環）4 海嘯（巨浪往上沖）5 毒霧（綠色毒雲擴散）6 虛空坍縮（黑洞吸入後爆開）

const DURATION := 1.8
const TICK := 0.15

var burn_damage := 8
var style := 0
var origin := Vector2(360, 1000)
var _t := 0.0
var _tick := 0.0
var _parts: Array = []   # 各風格用的粒子：[x, 相位, 大小, 速度]
var _bolts: Array = []   # 雷暴：[折線, 剩餘時間]
var _bolt_cd := 0.0
var _size := Vector2(720, 1280)


func _ready() -> void:
	_size = get_viewport_rect().size
	z_index = 50
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	for i in 90:
		_parts.append([randf() * _size.x, randf(), randf_range(40, 110), randf_range(0.7, 1.4)])


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
	if style == 2:
		_update_bolts(delta)
	queue_redraw()


func _fade() -> float:
	return 1.0 - clampf((_t / DURATION - 0.7) / 0.3, 0.0, 1.0)


func _draw() -> void:
	match style:
		1: _draw_nova()
		2: _draw_storm()
		3: _draw_aegis()
		4: _draw_tide()
		5: _draw_toxic()
		6: _draw_void()
		_: _draw_fire()


# ---------- 0 烈焰 ----------
func _draw_fire() -> void:
	var k := _t / DURATION
	var front := _size.y * (1.0 - clampf(k / 0.35, 0.0, 1.0)) - 120.0
	var fade := _fade()
	draw_rect(Rect2(Vector2(0, maxf(front, 0)), _size), Color(0.9, 0.25, 0.05, 0.35 * fade))
	for f in _parts:
		var phase := fmod(f[1] + _t * f[3], 1.0)
		var y: float = lerpf(_size.y + 60.0, front, phase)
		if y < front:
			continue
		var x: float = f[0] + sin(_t * 6.0 + f[1] * 10.0) * 18.0
		var s: float = f[2] * (1.0 - phase * 0.6)
		draw_circle(Vector2(x, y), s, Color(0.8, 0.15, 0.02, 0.35 * fade))
		draw_circle(Vector2(x, y - s * 0.3), s * 0.65, Color(1.0, 0.5, 0.08, 0.4 * fade))
		draw_circle(Vector2(x, y - s * 0.5), s * 0.3, Color(1.0, 0.9, 0.5, 0.45 * fade))
	if front > -100.0:
		draw_rect(Rect2(0, front - 30, _size.x, 60), Color(1.0, 0.7, 0.3, 0.35 * fade))


# ---------- 1 日冕新星：火環從戰機往外擴散 ----------
func _draw_nova() -> void:
	var fade := _fade()
	var maxr := _size.length()
	draw_rect(Rect2(Vector2.ZERO, _size), Color(1.0, 0.3, 0.1, 0.22 * fade))
	for ring in 3:
		var k := clampf((_t - ring * 0.18) / 0.8, 0.0, 1.0)
		if k <= 0.0:
			continue
		var r := maxr * k
		draw_arc(origin, r, 0, TAU, 64, Color(1.0, 0.45, 0.1, 0.55 * fade), 90.0 * (1.0 - k * 0.5))
		draw_arc(origin, r, 0, TAU, 64, Color(1.0, 0.85, 0.4, 0.7 * fade), 24.0)
	for f in _parts:
		var ang: float = f[1] * TAU
		var r2: float = maxr * clampf(_t * f[3] / 1.0, 0.0, 1.2)
		var p := origin + Vector2.RIGHT.rotated(ang) * r2
		draw_circle(p, f[2] * 0.4, Color(1.0, 0.6, 0.2, 0.4 * fade))
	draw_circle(origin, 120.0 * (1.0 - _t / DURATION), Color(1.0, 0.95, 0.7, 0.8 * fade))


# ---------- 2 雷暴：落雷滿天 ----------
func _update_bolts(delta: float) -> void:
	_bolt_cd -= delta
	if _bolt_cd <= 0.0 and _t < DURATION * 0.8:
		_bolt_cd = 0.05
		for n in 2:
			var x := randf() * _size.x
			var pts := PackedVector2Array([Vector2(x, -20)])
			var y := -20.0
			while y < _size.y:
				y += randf_range(50, 110)
				x += randf_range(-50, 50)
				pts.append(Vector2(x, y))
			_bolts.append([pts, 0.22])
	for i in range(_bolts.size() - 1, -1, -1):
		_bolts[i][1] -= delta
		if _bolts[i][1] <= 0.0:
			_bolts.remove_at(i)


func _draw_storm() -> void:
	var fade := _fade()
	var flash := 0.25 + 0.2 * absf(sin(_t * 37.0))
	draw_rect(Rect2(Vector2.ZERO, _size), Color(0.9, 0.85, 0.3, flash * fade))
	for b in _bolts:
		var pts: PackedVector2Array = b[0]
		var a: float = b[1] / 0.22 * fade
		draw_polyline(pts, Color(1.0, 0.9, 0.3, 0.35 * a), 26.0)
		draw_polyline(pts, Color(1.0, 0.95, 0.6, 0.8 * a), 9.0)
		draw_polyline(pts, Color(1, 1, 1, a), 3.0)


# ---------- 3 神盾衝擊波：多層六角環 ----------
func _draw_aegis() -> void:
	var fade := _fade()
	draw_rect(Rect2(Vector2.ZERO, _size), Color(0.5, 0.75, 1.0, 0.18 * fade))
	var maxr := _size.length()
	for ring in 5:
		var k := clampf((_t - ring * 0.12) / 0.9, 0.0, 1.0)
		if k <= 0.0:
			continue
		var r := maxr * k
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(origin + Vector2.RIGHT.rotated(TAU * i / 6.0 + _t * 0.6) * r)
		draw_polyline(pts, Color(0.6, 0.85, 1.0, 0.45 * fade), 40.0 * (1.0 - k * 0.6))
		draw_polyline(pts, Color(0.95, 1.0, 1.0, 0.8 * fade), 8.0)
	# 六角格護盾紋
	var cell := 80.0
	var a := 0.12 * fade * (0.6 + 0.4 * sin(_t * 12.0))
	for gy in int(_size.y / cell) + 2:
		for gx in int(_size.x / cell) + 2:
			var c := Vector2(gx * cell + (cell * 0.5 if gy % 2 else 0.0), gy * cell * 0.86)
			draw_arc(c, cell * 0.5, 0, TAU, 6, Color(0.6, 0.9, 1.0, a), 2.0)


# ---------- 4 海嘯：巨浪從下往上沖 ----------
func _draw_tide() -> void:
	var k := _t / DURATION
	var fade := _fade()
	var front := _size.y * (1.0 - clampf(k / 0.4, 0.0, 1.0)) - 80.0
	var poly := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var x := _size.x * i / steps
		poly.append(Vector2(x, front + sin(x * 0.02 + _t * 9.0) * 40.0))
	poly.append(Vector2(_size.x, _size.y + 20))
	poly.append(Vector2(0, _size.y + 20))
	draw_colored_polygon(poly, Color(0.1, 0.5, 1.0, 0.4 * fade))
	var crest := poly.slice(0, steps + 1)
	draw_polyline(crest, Color(0.6, 0.95, 1.0, 0.8 * fade), 18.0)
	draw_polyline(crest, Color(1, 1, 1, 0.9 * fade), 5.0)
	for f in _parts:
		var phase := fmod(f[1] + _t * f[3] * 1.4, 1.0)
		var y: float = lerpf(_size.y + 40.0, front, phase)
		draw_circle(Vector2(f[0], y), f[2] * 0.18, Color(0.7, 0.95, 1.0, 0.45 * fade))


# ---------- 5 毒霧：綠色毒雲從戰機擴散 ----------
func _draw_toxic() -> void:
	var fade := _fade()
	var k := clampf(_t / 0.7, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, _size), Color(0.2, 0.8, 0.15, 0.2 * fade * k))
	var maxr := _size.length()
	for f in _parts:
		var ang: float = f[1] * TAU * 3.0
		var dist: float = maxr * 0.75 * k * (0.3 + 0.7 * fmod(f[1] * 7.0, 1.0))
		var p := origin + Vector2.RIGHT.rotated(ang + _t * 0.5) * dist
		var s: float = f[2] * (0.8 + 0.4 * sin(_t * 4.0 + f[1] * 20.0))
		draw_circle(p, s, Color(0.25, 0.9, 0.15, 0.22 * fade))
		draw_circle(p, s * 0.5, Color(0.7, 1.0, 0.3, 0.2 * fade))
	for i in 12:
		var bp := Vector2(fmod(i * 157.0 + _t * 40.0, _size.x), fmod(i * 311.0 - _t * 260.0, _size.y))
		if bp.y < 0:
			bp.y += _size.y
		draw_arc(bp, 14.0, 0, TAU, 16, Color(0.8, 1.0, 0.4, 0.6 * fade), 3.0)


# ---------- 6 虛空坍縮：黑洞吸入後爆開 ----------
func _draw_void() -> void:
	var fade := _fade()
	var center := Vector2(_size.x / 2.0, _size.y * 0.4)
	var implode := clampf(_t / 0.6, 0.0, 1.0)
	var burst := clampf((_t - 0.6) / 0.6, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, _size), Color(0.45, 0.15, 0.9, 0.25 * fade))
	var maxr := _size.length() * 0.7
	for f in _parts:
		var ang: float = f[1] * TAU + _t * 4.0 * f[3]
		var r: float
		if burst <= 0.0:
			r = maxr * (1.0 - implode) * (0.3 + 0.7 * fmod(f[1] * 5.0, 1.0))
		else:
			r = maxr * burst * (0.5 + 0.5 * fmod(f[1] * 5.0, 1.0))
		var p := center + Vector2.RIGHT.rotated(ang) * r
		draw_circle(p, f[2] * 0.15, Color(0.75, 0.45, 1.0, 0.6 * fade))
	var core := 40.0 + 140.0 * implode * (1.0 - burst)
	draw_circle(center, core * 1.6, Color(0.6, 0.2, 1.0, 0.35 * fade))
	draw_circle(center, core, Color(0.15, 0.0, 0.3, 0.9 * fade))
	if burst > 0.0:
		draw_arc(center, maxr * 1.4 * burst, 0, TAU, 64, Color(0.85, 0.6, 1.0, 0.7 * fade), 60.0 * (1.0 - burst) + 6.0)
