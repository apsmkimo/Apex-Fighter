class_name ScrollBackground
extends Node2D
## 霓虹科技感太空背景（全部程式繪製，沒有靜態圖片）。
##
## 由後往前的圖層：
## 1. 深空藍紫漸層＋緩慢移動的掃描光帶
## 2. 星雲（大片柔光，加亮混合，視差最慢）
## 3. 四層視差星星：遠景小點 → 中景 → 近景發光星 → 超近景十字星芒（會閃爍）
## 4. 高速光塵（拉長的線，帶出速度感）
## 5. 偶爾出現的流星／光條
##
## 效能：星星總數約 180 顆，全部在兩個 CanvasItem 的 _draw 裡畫完，
## 光點共用 NeonFx 的同一張貼圖，Draw Call 很少。

## 星星圖層設定：count 數量、speed 相對捲動速度、size 大小、alpha 亮度、glow 是否用光點貼圖
const STAR_LAYERS := [
	{ "count": 90, "speed": 0.12, "size": 1.0, "alpha": 0.35, "glow": false },
	{ "count": 55, "speed": 0.3, "size": 1.8, "alpha": 0.6, "glow": false },
	{ "count": 26, "speed": 0.7, "size": 7.0, "alpha": 0.75, "glow": true },
	{ "count": 7, "speed": 1.3, "size": 16.0, "alpha": 0.9, "glow": true },
]
const DUST_COUNT := 22
const NEBULA_COUNT := 5

## 配色：深空藍紫＋青、電光藍、洋紅、琥珀點綴
const COL_TOP := Color(0.035, 0.02, 0.11)
const COL_BOTTOM := Color(0.02, 0.05, 0.15)
const STAR_TINTS := [Color(0.75, 0.9, 1.0), Color(0.3, 0.9, 1.0), Color(1.0, 0.35, 0.85), Color(1.0, 0.75, 0.3), Color(0.55, 0.6, 1.0)]

var scroll_speed := 160.0
## 目前地表捲動速度（地面砲台跟著它移動；砲台封鎖時降到 0）
static var ground_speed := 160.0
var halted := false
var _speed_k := 1.0
var _terrain: Texture2D
var _terrain_tint := Color.WHITE
var _terrain_y := 0.0
var _far: Texture2D
var _far_tint := Color.WHITE
var _far_speed := 0.4
var _decor_tex: Array[Texture2D] = []
var _decor: Array = []   # [貼圖, 位置, 角度, 自轉, 大小, 速度倍率]
var top_color := COL_TOP
var bottom_color := COL_BOTTOM

var _t := 0.0
var _size := Vector2(720, 1280)
var _stars: Array[PackedVector2Array] = []
var _phase: Array[PackedFloat32Array] = []
var _tint: Array[PackedInt32Array] = []
var _dust := PackedVector2Array()
var _nebulae: Array = []      # [位置, 半徑, 顏色, 速度倍率]
var _meteors: Array = []      # [位置, 速度, 剩餘時間, 總時間, 顏色]
var _meteor_timer := 2.5
var _glow_layer: GlowLayer


func setup(stage: StageData) -> void:
	scroll_speed = stage.scroll_speed
	_terrain = stage.terrain
	_terrain_tint = stage.terrain_tint
	_far = stage.terrain_far
	_far_tint = stage.terrain_far_tint
	_far_speed = stage.terrain_far_speed
	_decor_tex = stage.float_decor
	ground_speed = scroll_speed
	# 關卡顏色只當成色調，和霓虹配色混合，保留每關的個性
	top_color = COL_TOP.lerp(stage.bg_top_color, 0.25)
	bottom_color = COL_BOTTOM.lerp(stage.bg_bottom_color, 0.25)


func _ready() -> void:
	z_index = -50
	_size = get_viewport_rect().size
	for layer in STAR_LAYERS:
		var pts := PackedVector2Array()
		var ph := PackedFloat32Array()
		var tn := PackedInt32Array()
		for i in layer.count:
			pts.append(Vector2(randf() * _size.x, randf() * _size.y))
			ph.append(randf() * TAU)
			# 大部分是冷白色，少數帶霓虹色
			tn.append(0 if randf() < 0.6 else randi_range(1, STAR_TINTS.size() - 1))
		_stars.append(pts)
		_phase.append(ph)
		_tint.append(tn)
	for i in DUST_COUNT:
		_dust.append(Vector2(randf() * _size.x, randf() * _size.y))
	var neb_cols := [Color(1.0, 0.2, 0.8, 0.16), Color(0.2, 0.6, 1.0, 0.14), Color(0.5, 0.25, 1.0, 0.16), Color(0.1, 0.9, 1.0, 0.09), Color(1.0, 0.6, 0.2, 0.06)]
	for i in NEBULA_COUNT:
		_nebulae.append([Vector2(randf() * _size.x, randf() * _size.y * 1.4 - _size.y * 0.2),
				randf_range(260.0, 520.0), neb_cols[i % neb_cols.size()], randf_range(0.04, 0.09)])
	# 會發光的部分放到加亮混合的子節點
	_glow_layer = GlowLayer.new()
	_glow_layer.bg = self
	add_child(_glow_layer)


func _process(delta: float) -> void:
	_t += delta
	_size = get_viewport_rect().size
	var h := _size.y
	# 封鎖時平滑停下，解除後再加速
	_speed_k = move_toward(_speed_k, 0.0 if halted else 1.0, delta * 1.2)
	ground_speed = scroll_speed * _speed_k
	_terrain_y += ground_speed * delta
	if not _decor_tex.is_empty():
		_update_decor(delta)
	var scroll_speed := self.scroll_speed * maxf(_speed_k, 0.15)
	# 星星
	for li in STAR_LAYERS.size():
		var pts := _stars[li]
		var v: float = scroll_speed * STAR_LAYERS[li].speed * delta
		for i in pts.size():
			var p := pts[i]
			p.y += v
			if p.y > h + 20.0:
				p = Vector2(randf() * _size.x, p.y - h - 40.0)
			pts[i] = p
		_stars[li] = pts
	# 光塵
	var dv := scroll_speed * 2.6 * delta
	for i in _dust.size():
		var p := _dust[i]
		p.y += dv
		if p.y > h + 40.0:
			p = Vector2(randf() * _size.x, -40.0 - randf() * 200.0)
		_dust[i] = p
	# 星雲
	for n in _nebulae:
		var pos: Vector2 = n[0]
		pos.y += scroll_speed * n[3] * delta
		var r: float = n[1]
		if pos.y - r > h:
			pos = Vector2(randf() * _size.x, -r - randf() * 300.0)
		n[0] = pos
	# 流星／光條
	_meteor_timer -= delta
	if _meteor_timer <= 0.0:
		_meteor_timer = randf_range(3.0, 7.0)
		_spawn_meteor()
	for i in range(_meteors.size() - 1, -1, -1):
		var m: Array = _meteors[i]
		m[0] += (m[1] as Vector2) * delta
		m[2] -= delta
		if m[2] <= 0.0:
			_meteors.remove_at(i)
	queue_redraw()
	_glow_layer.queue_redraw()


func _spawn_meteor() -> void:
	var from_left := randf() < 0.5
	var start := Vector2(-40.0 if from_left else _size.x + 40.0, randf_range(0.0, _size.y * 0.5))
	var dir := Vector2(1.0 if from_left else -1.0, randf_range(0.35, 0.8)).normalized()
	var col: Color = [Color(0.4, 0.95, 1.0), Color(1.0, 0.4, 0.9), Color(1.0, 0.8, 0.4)][randi() % 3]
	var life := randf_range(0.7, 1.1)
	_meteors.append([start, dir * randf_range(900.0, 1300.0), life, life, col])


## 底層：漸層、掃描光帶、遠景星點（一般混合）
func _draw() -> void:
	var s := _size
	if _terrain and _terrain_tint.a >= 0.99:
		_draw_terrain()
		return
	draw_polygon(
		PackedVector2Array([Vector2(-20, -20), Vector2(s.x + 20, -20), s + Vector2(20, 20), Vector2(-20, s.y + 20)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	# 遠景視差層（第 6 關）：先畫遠景，再疊半透明的主背景
	if _far:
		_draw_loop(_far, _terrain_y * _far_speed, _far_tint)
	# 半透明地表（第 5 關 50%）：漸層上面疊地表
	if _terrain:
		_draw_terrain()
		return
	# 緩慢往下移動的科技掃描光帶
	var band_y := fmod(_t * 40.0, s.y + 400.0) - 200.0
	draw_rect(Rect2(-20, band_y, s.x + 40, 140), Color(0.3, 0.5, 1.0, 0.025))
	draw_rect(Rect2(-20, band_y + 60, s.x + 40, 2), Color(0.4, 0.9, 1.0, 0.06))
	# 遠景兩層：小方點就夠了，最省效能
	for li in 2:
		var base_a: float = STAR_LAYERS[li].alpha
		var sz: float = STAR_LAYERS[li].size
		var pts := _stars[li]
		var ph := _phase[li]
		var tn := _tint[li]
		for i in pts.size():
			var c: Color = STAR_TINTS[tn[i]]
			c.a = base_a * (0.65 + 0.35 * sin(_t * 2.0 + ph[i]))
			draw_rect(Rect2(pts[i].x, pts[i].y, sz, sz), c)


## 星球地表：寬度貼齊畫面，往下循環捲動
func _draw_terrain() -> void:
	# 地表圖本身已經上下鏡像接好（無縫循環）
	_draw_loop(_terrain, _terrain_y, _terrain_tint)
	# 上下暗角，讓子彈與敵機更清楚
	draw_rect(Rect2(Vector2.ZERO, _size), Color(0.0, 0.02, 0.05, 0.28))
	for d in _decor:
		var tex: Texture2D = d[0]
		var sz: Vector2 = tex.get_size() * float(d[4])
		draw_set_transform(d[1], d[2], Vector2.ONE)
		draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, Color(0.55, 0.55, 0.6, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_loop(tex: Texture2D, offset: float, tint: Color) -> void:
	var ts := tex.get_size()
	var w := _size.x
	var th := ts.y * (w / ts.x)
	var y := fmod(offset, th) - th
	while y < _size.y:
		draw_texture_rect(tex, Rect2(0, y, w, th), false, tint)
		y += th


## 飄浮隕石：最多 7 顆，從上方進來、往下飄、邊轉邊走
func _update_decor(delta: float) -> void:
	for i in range(_decor.size() - 1, -1, -1):
		var d: Array = _decor[i]
		d[1] += Vector2(0, scroll_speed * float(d[5]) * maxf(_speed_k, 0.25) * delta)
		d[2] += float(d[3]) * delta
		if (d[1] as Vector2).y > _size.y + 120.0:
			_decor.remove_at(i)
	if _decor.size() < 7 and randf() < delta * 1.2:
		var k := randf_range(0.35, 0.9)
		_decor.append([_decor_tex.pick_random(), Vector2(randf() * _size.x, -100.0), randf() * TAU,
				randf_range(-0.6, 0.6), k, 1.3 + k])


## 發光層（加亮混合）：星雲、近景星、光塵、流星
class GlowLayer extends Node2D:
	var bg: ScrollBackground

	func _ready() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _draw() -> void:
		if bg == null:
			return
		var tex := NeonFx.get_glow_tex()
		var t := bg._t
		if bg._terrain:
			# 地表關卡：只留高速光塵
			for p in bg._dust:
				draw_line(p, p - Vector2(0, 26), Color(0.7, 0.9, 1.0, 0.12), 1.5)
			return
		# 星雲：同一張光點貼圖放大，疊兩次做出不規則形狀
		for n in bg._nebulae:
			var p: Vector2 = n[0]
			var r: float = n[1]
			var c: Color = n[2]
			draw_texture_rect(tex, Rect2(p.x - r, p.y - r * 0.7, r * 2.0, r * 1.4), false, c)
			var c2 := c
			c2.a *= 0.7
			draw_texture_rect(tex, Rect2(p.x - r * 0.3, p.y - r * 0.6, r * 1.3, r * 1.0), false, c2)
		# 近景兩層：發光星，最前面那層加十字星芒
		for li in range(2, ScrollBackground.STAR_LAYERS.size()):
			var layer: Dictionary = ScrollBackground.STAR_LAYERS[li]
			var pts := bg._stars[li]
			var ph := bg._phase[li]
			var tn := bg._tint[li]
			var sz: float = layer.size
			for i in pts.size():
				var c: Color = ScrollBackground.STAR_TINTS[tn[i]]
				var tw := 0.6 + 0.4 * sin(t * 3.0 + ph[i])
				c.a = layer.alpha * tw
				var s := sz * (0.8 + 0.2 * tw)
				var p := pts[i]
				draw_texture_rect(tex, Rect2(p.x - s, p.y - s, s * 2.0, s * 2.0), false, c)
				if li == ScrollBackground.STAR_LAYERS.size() - 1:
					var f := Color(c.r, c.g, c.b, c.a * 0.6)
					draw_line(p - Vector2(s * 1.6, 0), p + Vector2(s * 1.6, 0), f, 1.5)
					draw_line(p - Vector2(0, s * 1.6), p + Vector2(0, s * 1.6), f, 1.5)
		# 光塵：往下拉長的細線
		for p in bg._dust:
			draw_line(p, p - Vector2(0, 26), Color(0.4, 0.8, 1.0, 0.18), 1.5)
		# 流星：亮頭＋漸淡長尾
		for m in bg._meteors:
			var pos: Vector2 = m[0]
			var vel: Vector2 = m[1]
			var k: float = m[2] / m[3]
			var col: Color = m[4]
			var tail := vel.normalized() * 220.0
			for seg in 6:
				var a := float(seg) / 6.0
				var b := float(seg + 1) / 6.0
				draw_line(pos - tail * a, pos - tail * b, Color(col.r, col.g, col.b, 0.7 * k * (1.0 - a)), 3.0 * (1.0 - a) + 0.5)
			draw_texture_rect(tex, Rect2(pos - Vector2(14, 14), Vector2(28, 28)), false, Color(col.r, col.g, col.b, k))
