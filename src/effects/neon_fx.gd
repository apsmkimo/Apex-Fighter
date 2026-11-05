class_name NeonFx
extends Node2D
## 共用霓虹特效層（爆炸、火花、光環、槍口閃光、引擎粒子）。
##
## 效能設計：
## - 全部粒子存在固定大小的 Packed 陣列裡，用「交換刪除」回收，不會一直 new / free 節點。
## - 整層只有一個 CanvasItem、一個加亮材質、一張共用光點貼圖，一次 _draw 畫完，Draw Call 很少。
## - 粒子數量有上限（MAX_PARTICLES），滿了就丟棄新粒子，不會拖垮手機。

static var instance: NeonFx

const MAX_PARTICLES := 700
const MAX_RINGS := 32

## 粒子種類：DOT = 圓形光點，SPARK = 沿速度方向拉長的火花線
enum Kind { DOT, SPARK }

# ---------- 粒子資料（平行陣列） ----------
var _p_pos := PackedVector2Array()
var _p_vel := PackedVector2Array()
var _p_life := PackedFloat32Array()
var _p_max := PackedFloat32Array()
var _p_size := PackedFloat32Array()
var _p_drag := PackedFloat32Array()
var _p_col := PackedColorArray()
var _p_kind := PackedByteArray()
var _p_count := 0

# ---------- 擴散光環 ----------
var _r_pos := PackedVector2Array()
var _r_from := PackedFloat32Array()
var _r_to := PackedFloat32Array()
var _r_life := PackedFloat32Array()
var _r_max := PackedFloat32Array()
var _r_width := PackedFloat32Array()
var _r_col := PackedColorArray()
var _r_count := 0

## 共用的柔邊光點貼圖（程式產生，不需要圖檔）
static var glow_tex: Texture2D
## 子彈貼圖的平均色快取 { Texture2D: Color }
static var _tex_colors := {}

## 文字飛出用（一般混合，不能放在加亮層裡）
var _text_layer: Node2D
## 圖片爆炸層（一般混合：火焰、煙霧的暗部才不會被加亮吃掉）
var _sprites: SpriteLayer
## 通用爆炸三格（閃光 → 火球 → 消散），全遊戲所有爆炸共用
static var explosion_frames: Array[Texture2D] = []
var _was_busy := false


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	z_index = 10
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_p_pos.resize(MAX_PARTICLES)
	_p_vel.resize(MAX_PARTICLES)
	_p_life.resize(MAX_PARTICLES)
	_p_max.resize(MAX_PARTICLES)
	_p_size.resize(MAX_PARTICLES)
	_p_drag.resize(MAX_PARTICLES)
	_p_col.resize(MAX_PARTICLES)
	_p_kind.resize(MAX_PARTICLES)
	_r_pos.resize(MAX_RINGS)
	_r_from.resize(MAX_RINGS)
	_r_to.resize(MAX_RINGS)
	_r_life.resize(MAX_RINGS)
	_r_max.resize(MAX_RINGS)
	_r_width.resize(MAX_RINGS)
	_r_col.resize(MAX_RINGS)
	_text_layer = Node2D.new()
	_text_layer.z_index = 11
	_text_layer.z_as_relative = false
	add_child.call_deferred(_text_layer)
	_sprites = SpriteLayer.new()
	_sprites.z_index = 9
	_sprites.z_as_relative = false
	add_child.call_deferred(_sprites)
	get_glow_tex()
	if explosion_frames.is_empty():
		for i in 3:
			explosion_frames.append(load("res://assets/sprites/fx/explosion_%d.png" % i) as Texture2D)


## 柔邊圓形光點（中心白、往外透明），全遊戲共用一張
static func get_glow_tex() -> Texture2D:
	if glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		glow_tex = t
	return glow_tex


## 取得貼圖的代表色（亮部平均），拿來決定槍口閃光與拖尾顏色。結果會快取。
static func tex_color(tex: Texture2D) -> Color:
	if tex == null:
		return Color(0.6, 0.9, 1.0)
	if _tex_colors.has(tex):
		return _tex_colors[tex]
	var c := Color(0.6, 0.9, 1.0)
	var img := tex.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var sum := Vector3.ZERO
		var n := 0.0
		var step := maxi(1, img.get_width() * img.get_height() / 200)
		var i := 0
		for y in img.get_height():
			for x in img.get_width():
				i += 1
				if i % step != 0:
					continue
				var p := img.get_pixel(x, y)
				if p.a > 0.5:
					sum += Vector3(p.r, p.g, p.b) * p.a
					n += p.a
		if n > 0.0:
			sum /= n
			c = Color(sum.x, sum.y, sum.z)
			# 拉高飽和度與亮度，讓光效更鮮明
			c = Color.from_hsv(c.h, minf(c.s * 1.3, 1.0), maxf(c.v, 0.85))
	_tex_colors[tex] = c
	return c


# ======================================================================
# 基本 API
# ======================================================================

func emit(pos: Vector2, vel: Vector2, life: float, size: float, col: Color, kind := Kind.DOT, drag := 2.0) -> void:
	if _p_count >= MAX_PARTICLES:
		return
	var i := _p_count
	_p_pos[i] = pos
	_p_vel[i] = vel
	_p_life[i] = life
	_p_max[i] = life
	_p_size[i] = size
	_p_drag[i] = drag
	_p_col[i] = col
	_p_kind[i] = kind
	_p_count += 1


func ring(pos: Vector2, from_r: float, to_r: float, life: float, col: Color, width := 3.0) -> void:
	if _r_count >= MAX_RINGS:
		return
	var i := _r_count
	_r_pos[i] = pos
	_r_from[i] = from_r
	_r_to[i] = to_r
	_r_life[i] = life
	_r_max[i] = life
	_r_width[i] = width
	_r_col[i] = col
	_r_count += 1


# ======================================================================
# 組合特效
# ======================================================================

const AMBER := Color(1.0, 0.72, 0.25)
const MAGENTA := Color(1.0, 0.25, 0.85)
const CYAN := Color(0.3, 0.9, 1.0)
const VIOLET := Color(0.6, 0.35, 1.0)


## 敵機爆炸：閃光核心 → 兩道衝擊波 → 火花 → 餘燼。scale 越大粒子越多（有上限）。
func explode(at: Vector2, scale := 1.0) -> void:
	var s := clampf(scale, 0.6, 5.0)
	explosion_anim(at, 74.0 * s, 0.32 + 0.08 * minf(s, 3.0))
	emit(at, Vector2.ZERO, 0.16, 70.0 * s, Color(1, 0.95, 0.85), Kind.DOT, 0.0)
	emit(at, Vector2.ZERO, 0.3, 46.0 * s, AMBER, Kind.DOT, 0.0)
	ring(at, 10.0 * s, 80.0 * s, 0.35, AMBER, 4.0)
	ring(at, 6.0 * s, 120.0 * s, 0.55, MAGENTA, 2.5)
	var sparks := int(clampf(14.0 * s, 10.0, 46.0))
	var spd := 520.0 * sqrt(s)
	for i in sparks:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var c := Color(1, 0.9, 0.6) if i % 3 == 0 else AMBER
		emit(at, dir * randf_range(0.35, 1.0) * spd, randf_range(0.3, 0.55), randf_range(2.0, 3.5), c, Kind.SPARK, 3.5)
	var embers := int(clampf(9.0 * s, 6.0, 34.0))
	for i in embers:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var c: Color = [MAGENTA, VIOLET, CYAN, AMBER][i % 4]
		emit(at + dir * randf() * 12.0 * s, dir * randf_range(40.0, 200.0) * sqrt(s), randf_range(0.5, 1.0), randf_range(5.0, 10.0) * minf(s, 2.0), c, Kind.DOT, 1.6)


## 子彈打中敵機的小火花
func impact(at: Vector2, col: Color) -> void:
	emit(at, Vector2.ZERO, 0.08, 18.0, col, Kind.DOT, 0.0)
	for i in 2:
		var dir := Vector2.DOWN.rotated(randf_range(-1.2, 1.2))
		emit(at, dir * randf_range(150.0, 320.0), 0.18, 2.0, col, Kind.SPARK, 4.0)


## 槍口閃光
func muzzle(at: Vector2, col: Color) -> void:
	emit(at, Vector2(0, -60), 0.06, 20.0, col, Kind.DOT, 0.0)


## 撿道具：光環＋放射光點＋文字飛出
func pickup(at: Vector2, col: Color, text: String) -> void:
	ring(at, 12.0, 70.0, 0.4, col, 3.0)
	ring(at, 6.0, 40.0, 0.3, Color(1, 1, 1, 0.8), 2.0)
	for i in 10:
		var dir := Vector2.RIGHT.rotated(TAU * i / 10.0)
		emit(at, dir * 220.0, 0.35, 6.0, col, Kind.DOT, 3.0)
	if text != "":
		float_text(at + Vector2(0, -20), text, col)


## 護盾擋下攻擊
func shield_burst(at: Vector2) -> void:
	ring(at, 40.0, 110.0, 0.4, CYAN, 4.0)
	ring(at, 50.0, 80.0, 0.25, Color(0.8, 0.95, 1.0), 2.0)
	for i in 16:
		var dir := Vector2.RIGHT.rotated(TAU * i / 16.0)
		emit(at + dir * 55.0, dir * 260.0, 0.3, 3.0, CYAN, Kind.SPARK, 3.0)


## 玩家受擊的紅色火花
func hurt_burst(at: Vector2) -> void:
	ring(at, 10.0, 70.0, 0.3, Color(1, 0.25, 0.3), 3.0)
	for i in 12:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		emit(at, dir * randf_range(180.0, 380.0), 0.35, 2.5, Color(1, 0.35, 0.3), Kind.SPARK, 3.0)


## 飛出的提示文字（例如 POWER UP）。數量很少，直接用 Label 節點。
func float_text(at: Vector2, text: String, col: Color) -> void:
	if _text_layer == null or not _text_layer.is_inside_tree():
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 26)
	l.add_theme_color_override(&"font_color", col.lightened(0.35))
	l.add_theme_color_override(&"font_outline_color", Color(0.02, 0.02, 0.08, 0.95))
	l.add_theme_constant_override(&"outline_size", 8)
	l.add_theme_color_override(&"font_shadow_color", Color(col.r, col.g, col.b, 0.6))
	l.add_theme_constant_override(&"shadow_offset_x", 0)
	l.add_theme_constant_override(&"shadow_offset_y", 0)
	l.add_theme_constant_override(&"shadow_outline_size", 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(240, 40)
	l.position = at - Vector2(120, 20)
	l.pivot_offset = Vector2(120, 20)
	l.scale = Vector2(0.6, 0.6)
	_text_layer.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 70.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


# ======================================================================
# 更新與繪製
# ======================================================================

func _process(delta: float) -> void:
	var i := 0
	while i < _p_count:
		_p_life[i] -= delta
		if _p_life[i] <= 0.0:
			_remove_particle(i)
			continue
		var v := _p_vel[i]
		v *= maxf(0.0, 1.0 - _p_drag[i] * delta)
		_p_vel[i] = v
		_p_pos[i] += v * delta
		i += 1
	i = 0
	while i < _r_count:
		_r_life[i] -= delta
		if _r_life[i] <= 0.0:
			_remove_ring(i)
			continue
		i += 1
	# 沒有粒子時只再重畫一次把畫面清掉，之後不再浪費 CPU
	var busy := _p_count > 0 or _r_count > 0
	if busy or _was_busy:
		queue_redraw()
	_was_busy = busy


func _remove_particle(i: int) -> void:
	var last := _p_count - 1
	if i != last:
		_p_pos[i] = _p_pos[last]
		_p_vel[i] = _p_vel[last]
		_p_life[i] = _p_life[last]
		_p_max[i] = _p_max[last]
		_p_size[i] = _p_size[last]
		_p_drag[i] = _p_drag[last]
		_p_col[i] = _p_col[last]
		_p_kind[i] = _p_kind[last]
	_p_count = last


func _remove_ring(i: int) -> void:
	var last := _r_count - 1
	if i != last:
		_r_pos[i] = _r_pos[last]
		_r_from[i] = _r_from[last]
		_r_to[i] = _r_to[last]
		_r_life[i] = _r_life[last]
		_r_max[i] = _r_max[last]
		_r_width[i] = _r_width[last]
		_r_col[i] = _r_col[last]
	_r_count = last


func _draw() -> void:
	var tex := glow_tex
	for i in _r_count:
		var k := 1.0 - _r_life[i] / _r_max[i]
		var r := lerpf(_r_from[i], _r_to[i], 1.0 - (1.0 - k) * (1.0 - k))
		var c := _r_col[i]
		c.a *= 1.0 - k
		draw_arc(_r_pos[i], r, 0.0, TAU, 36, c, _r_width[i] * (1.0 - k * 0.5))
	for i in _p_count:
		var k := _p_life[i] / _p_max[i]   # 1 → 0
		var c := _p_col[i]
		c.a *= k
		var p := _p_pos[i]
		if _p_kind[i] == Kind.SPARK:
			draw_line(p, p - _p_vel[i] * 0.035, c, _p_size[i])
		else:
			var s := _p_size[i] * (0.5 + 0.5 * k)
			draw_texture_rect(tex, Rect2(p.x - s, p.y - s, s * 2.0, s * 2.0), false, c)


# ======================================================================
# 圖片爆炸
# ======================================================================

## 通用爆炸動畫：三格依序交叉淡入（size = 最大直徑）
func explosion_anim(at: Vector2, size: float, life := 0.4, delay := 0.0) -> void:
	if _sprites and explosion_frames.size() == 3:
		_sprites.add(at, explosion_frames, size, life, delay)


## 單張圖片爆炸：從 0.3 倍放大到 size、旋轉、淡出（孢子爆炸、Boss 爆炸用）
func burst(at: Vector2, tex: Texture2D, size: float, life := 0.6, delay := 0.0) -> void:
	if _sprites and tex:
		var frames: Array[Texture2D] = [tex]
		_sprites.add(at, frames, size, life, delay)


class SpriteLayer extends Node2D:
	const MAX := 48
	# 每筆：[位置, 貼圖陣列, 尺寸, 剩餘時間, 總時間, 延遲, 旋轉]
	var _items: Array = []

	func add(at: Vector2, frames: Array[Texture2D], size: float, life: float, delay: float) -> void:
		if _items.size() >= MAX:
			_items.pop_front()
		_items.append([at, frames, size, life, life, delay, randf() * TAU])

	func _process(delta: float) -> void:
		if _items.is_empty():
			return
		for it in _items:
			if it[5] > 0.0:
				it[5] -= delta
			else:
				it[3] -= delta
		_items = _items.filter(func(it: Array) -> bool: return it[3] > 0.0)
		queue_redraw()

	func _draw() -> void:
		for it in _items:
			if it[5] > 0.0:
				continue
			var frames: Array[Texture2D] = it[1]
			var k := 1.0 - float(it[3]) / float(it[4])   # 0 → 1
			var size: float = it[2]
			var at: Vector2 = it[0]
			var rot: float = it[6] + k * 0.6
			if frames.size() == 1:
				_draw_tex(frames[0], at, size * (0.3 + 0.7 * ease(k, 0.4)), rot, 1.0 - ease(k, 3.0))
				continue
			# 三格：0–0.3 閃光放大，0.15–0.65 火球，0.45–1 消散
			_draw_tex(frames[0], at, size * lerpf(0.25, 0.7, minf(k / 0.3, 1.0)), rot, 1.0 - clampf((k - 0.15) / 0.2, 0.0, 1.0))
			var a1 := clampf((k - 0.1) / 0.1, 0.0, 1.0) * (1.0 - clampf((k - 0.5) / 0.2, 0.0, 1.0))
			_draw_tex(frames[1], at, size * lerpf(0.6, 1.0, clampf((k - 0.1) / 0.5, 0.0, 1.0)), rot, a1)
			var a2 := clampf((k - 0.4) / 0.15, 0.0, 1.0) * (1.0 - clampf((k - 0.7) / 0.3, 0.0, 1.0))
			_draw_tex(frames[2], at, size * lerpf(0.9, 1.15, clampf((k - 0.4) / 0.6, 0.0, 1.0)), rot, a2)

	func _draw_tex(tex: Texture2D, at: Vector2, size: float, rot: float, alpha: float) -> void:
		if alpha <= 0.01:
			return
		var ts := tex.get_size()
		var sc := size / maxf(ts.x, ts.y)
		draw_set_transform(at, rot, Vector2(sc, sc))
		draw_texture(tex, -ts * 0.5, Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
