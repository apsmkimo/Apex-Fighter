class_name BossUltimate
extends Node2D
## Boss 大絕招。BossData.ult_kinds 依序輪流：
##   beam      儲能（粒子聚集＋警示區）→ 往下發射大範圍雷射
##   eye_laser 眼睛充能、紅色瞄準扇形 → 紅眼雷射從一側掃到另一側
##   web       口部蓄力 → 吐出數團絲網，碰到玩家會黏住無法移動（護盾可擋）
##   pincer    左右鉗子充能 → 兩道雷射由內往外張開（中間與兩側留有安全區）
##   nova      核心充能 → 數圈擴散衝擊波，每圈有缺口可以鑽過
##   feather   雙翼砲台發光 → 大量子彈齊射（一般子彈傷害）
## 雷射類打到玩家扣 BossData.ult_damage（滿血只擋得住一次），一次發射只扣一次。

enum State { IDLE, CHARGE, FIRE }

const WEB_RADIUS := 26.0
const WEB_MAX_TIME := 5.0

var boss: Boss
var bd: BossData
var state := State.IDLE
var kind: StringName = &"beam"
var _kind_index := 0
var _timer := 0.0
var _t := 0.0
var _hit_done := false
var _particles: Array = []   # [角度, 距離, 速度]
# 紅眼雷射
var _eye_from := 0.0
var _eye_to := 0.0
# 絲網：每團 [世界座標, 速度, 旋轉角]
var _webs: Array = []
# 衝擊波：每圈 [半徑, 缺口中心角, 已命中]
var _rings: Array = []
var _rings_left := 0
var _ring_cd := 0.0
var _feather_cd := 0.0


func setup(b: Boss) -> void:
	boss = b
	bd = b.boss_data()
	_timer = bd.entry_time + bd.ult_first_delay


func _ready() -> void:
	z_index = 5
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


## 儲能與雷射發射期間 Boss 暫停一般彈幕；吐絲時彈幕照常（被黏住才危險）
func busy() -> bool:
	return state == State.CHARGE or (state == State.FIRE and kind != &"web")


## 吐絲與衝擊波要等飛出畫面才結束
func _waits_for_projectiles() -> bool:
	return kind == &"web" or kind == &"nova"


func cancel() -> void:
	state = State.IDLE
	_webs.clear()
	_rings.clear()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	if boss == null or boss.health.dead:
		return
	_timer -= delta
	match state:
		State.IDLE:
			if _timer <= 0.0:
				_start_charge()
		State.CHARGE:
			_update_particles(delta)
			if _timer <= 0.0:
				_start_fire()
		State.FIRE:
			match kind:
				&"beam":
					_check_beam_hit()
					Events.screen_shake.emit(5.0, 0.1)
				&"eye_laser":
					_check_eye_hit()
					Events.screen_shake.emit(4.0, 0.1)
				&"web":
					_update_webs(delta)
				&"pincer":
					_check_pincer_hit()
					Events.screen_shake.emit(4.0, 0.1)
				&"nova":
					_update_nova(delta)
				&"feather":
					_update_feather(delta)
			var finished := _timer <= 0.0
			if kind == &"web":
				finished = _webs.is_empty() or _timer <= 0.0
			elif kind == &"nova":
				finished = (_rings.is_empty() and _rings_left <= 0) or _timer <= 0.0
			if finished:
				_webs.clear()
				_rings.clear()
				state = State.IDLE
				_timer = bd.ult_interval
				Events.boss_ultimate.emit("end")
	queue_redraw()


# ---------- 狀態切換 ----------

func _start_charge() -> void:
	kind = bd.ult_kinds[_kind_index % bd.ult_kinds.size()] if not bd.ult_kinds.is_empty() else &"beam"
	_kind_index += 1
	state = State.CHARGE
	match kind:
		&"eye_laser":
			_timer = bd.ult_eye_charge
		&"web":
			_timer = bd.ult_web_charge
		&"pincer":
			_timer = bd.ult_pincer_charge
		&"nova":
			_timer = bd.ult_nova_charge
		&"feather":
			_timer = bd.ult_feather_charge
		_:
			_timer = bd.ult_charge_time
	_charge_total = _timer
	_particles.clear()
	Events.boss_ultimate.emit("charge")


var _charge_total := 1.0


func _start_fire() -> void:
	state = State.FIRE
	_hit_done = false
	match kind:
		&"eye_laser":
			_timer = bd.ult_eye_fire
			# 以玩家目前方向為中心，從一側掃到另一側（方向隨機）
			var center := _aim_angle(bd.ult_eye_offset)
			var half := deg_to_rad(bd.ult_eye_sweep_deg) * 0.5
			var dir := 1.0 if randf() < 0.5 else -1.0
			_eye_from = center - half * dir
			_eye_to = center + half * dir
			Events.screen_shake.emit(12.0, 0.3)
		&"web":
			_timer = WEB_MAX_TIME
			_spawn_webs()
		&"pincer":
			_timer = bd.ult_pincer_fire
			Events.screen_shake.emit(10.0, 0.3)
		&"nova":
			_timer = 8.0
			_rings.clear()
			_rings_left = bd.ult_nova_rings
			_ring_cd = 0.0
		&"feather":
			_timer = bd.ult_feather_time
			_feather_cd = 0.0
		_:
			_timer = bd.ult_fire_time
			Events.screen_shake.emit(14.0, 0.4)
	Events.boss_ultimate.emit("fire")


## 從 Boss 身上某點指向玩家的角度（沒有玩家就朝下）
func _aim_angle(local_from: Vector2) -> float:
	var from := global_position + local_from
	if Player.instance and Player.instance.alive:
		return (Player.instance.global_position - from).angle()
	return PI / 2.0


# ---------- 共用 ----------

func _charge_ratio() -> float:
	return clampf(1.0 - _timer / maxf(_charge_total, 0.01), 0.0, 1.0)


## 0 → 1 → 0：雷射寬度（開頭快速展開，結尾收細）
func _beam_ratio(total: float) -> float:
	var elapsed := total - _timer
	return clampf(minf(elapsed / 0.12, _timer / 0.25), 0.0, 1.0)


func _update_particles(delta: float) -> void:
	var spawn := 2 + int(_charge_ratio() * 4.0)
	for i in spawn:
		_particles.append([randf() * TAU, randf_range(110.0, 220.0), randf_range(260.0, 480.0)])
	for p in _particles:
		p[1] -= p[2] * delta
	_particles = _particles.filter(func(p: Array) -> bool: return p[1] > 8.0)


func _charge_origin() -> Vector2:
	match kind:
		&"eye_laser":
			return bd.ult_eye_offset
		&"web":
			return bd.ult_web_origin
		&"pincer":
			return bd.ult_pincer_offset
	return bd.ult_origin


# ---------- beam ----------

func _check_beam_hit() -> void:
	var pl := Player.instance
	if _hit_done or pl == null or not pl.alive or _beam_ratio(bd.ult_fire_time) < 0.5:
		return
	var origin := global_position + bd.ult_origin
	var half := bd.ult_width * 0.5 * _beam_ratio(bd.ult_fire_time) * 0.85
	if pl.global_position.y > origin.y and absf(pl.global_position.x - origin.x) < half + pl.ship.hitbox_radius:
		_hit_done = true
		pl.take_hit(bd.ult_damage)


# ---------- eye_laser ----------

func _eye_angle() -> float:
	var k := clampf(1.0 - _timer / bd.ult_eye_fire, 0.0, 1.0)
	return lerp_angle(_eye_from, _eye_to, ease(k, -1.6))


func _check_eye_hit() -> void:
	var pl := Player.instance
	if _hit_done or pl == null or not pl.alive or _beam_ratio(bd.ult_eye_fire) < 0.5:
		return
	var origin := global_position + bd.ult_eye_offset
	var dir := Vector2.RIGHT.rotated(_eye_angle())
	var rel := pl.global_position - origin
	var along := rel.dot(dir)
	if along <= 0.0:
		return
	var dist := absf(rel.cross(dir))
	if dist < bd.ult_eye_width * 0.5 * 0.8 + pl.ship.hitbox_radius:
		_hit_done = true
		pl.take_hit(bd.ult_damage)


# ---------- web ----------

func _spawn_webs() -> void:
	var center := _aim_angle(bd.ult_web_origin)
	var n := maxi(bd.ult_web_count, 1)
	var spread := deg_to_rad(bd.ult_web_spread_deg)
	for i in n:
		var a := center if n == 1 else center - spread * 0.5 + spread * i / (n - 1)
		_webs.append([global_position + bd.ult_web_origin, Vector2.RIGHT.rotated(a) * bd.ult_web_speed, randf() * TAU])


func _update_webs(delta: float) -> void:
	var rect := get_viewport_rect().grow(80.0)
	var pl := Player.instance
	for i in range(_webs.size() - 1, -1, -1):
		var w: Array = _webs[i]
		w[0] += (w[1] as Vector2) * delta
		w[2] += delta * 3.0
		var pos: Vector2 = w[0]
		if pl and pl.alive and pos.distance_to(pl.global_position) < WEB_RADIUS + pl.ship.hitbox_radius + 6.0:
			pl.apply_web(bd.ult_web_stun)
			_webs.remove_at(i)
			continue
		if not rect.has_point(pos):
			_webs.remove_at(i)


# ---------- pincer ----------

## 鉗子雷射角度：side = 1 右鉗、-1 左鉗。從偏內側（96°）張開到偏外側（78°）
func _pincer_angle(side: float) -> float:
	var k := clampf(1.0 - _timer / bd.ult_pincer_fire, 0.0, 1.0) if state == State.FIRE else 0.0
	var deg := lerpf(96.0, 78.0, ease(k, -1.5))
	return deg_to_rad(90.0 + (deg - 90.0) * side)


func _pincer_origin(side: float) -> Vector2:
	return Vector2(bd.ult_pincer_offset.x * side, bd.ult_pincer_offset.y)


func _check_pincer_hit() -> void:
	var pl := Player.instance
	if _hit_done or pl == null or not pl.alive or _beam_ratio(bd.ult_pincer_fire) < 0.5:
		return
	for side: float in [-1.0, 1.0]:
		var origin := global_position + _pincer_origin(side)
		var dir := Vector2.RIGHT.rotated(_pincer_angle(side))
		var rel := pl.global_position - origin
		if rel.dot(dir) > 0.0 and absf(rel.cross(dir)) < bd.ult_pincer_width * 0.4 + pl.ship.hitbox_radius:
			_hit_done = true
			pl.take_hit(bd.ult_damage)
			return


# ---------- nova ----------

func _update_nova(delta: float) -> void:
	_ring_cd -= delta
	if _rings_left > 0 and _ring_cd <= 0.0:
		_rings_left -= 1
		_ring_cd = 0.75
		# 缺口大致朝玩家，但每圈偏一點，逼玩家移動
		var gap := _aim_angle(bd.ult_origin) + randf_range(-0.7, 0.7)
		_rings.append([30.0, gap, false])
		Events.screen_shake.emit(8.0, 0.2)
	var pl := Player.instance
	var origin := global_position + bd.ult_origin
	var half_gap := deg_to_rad(bd.ult_nova_gap_deg) * 0.5
	for i in range(_rings.size() - 1, -1, -1):
		var r: Array = _rings[i]
		r[0] += bd.ult_nova_speed * delta
		if r[0] > 1600.0:
			_rings.remove_at(i)
			continue
		if r[2] or pl == null or not pl.alive:
			continue
		var rel := pl.global_position - origin
		if absf(rel.length() - (r[0] as float)) < bd.ult_nova_width * 0.5 + pl.ship.hitbox_radius:
			if absf(angle_difference(rel.angle(), r[1] as float)) > half_gap:
				r[2] = true
				pl.take_hit(bd.ult_damage)


# ---------- feather ----------

func _update_feather(delta: float) -> void:
	_feather_cd -= delta
	if _feather_cd > 0.0 or BulletPool.instance == null or bd.ult_feather_points.is_empty():
		return
	_feather_cd = bd.ult_feather_rate
	var p := bd.ult_feather_points[randi() % bd.ult_feather_points.size()]
	var from := global_position + p
	var ang := _aim_angle(p) + randf_range(-0.45, 0.45)
	BulletPool.instance.spawn(from, Vector2.RIGHT.rotated(ang) * bd.ult_feather_speed,
			bd.ult_feather_texture, 8.0, bd.bullet_damage, false)
	if NeonFx.instance:
		NeonFx.instance.muzzle(from, bd.ult_color)


# ---------- 繪製 ----------

func _draw() -> void:
	if bd == null:
		return
	var c := bd.ult_color
	match state:
		State.CHARGE:
			_draw_charge(c)
		State.FIRE:
			match kind:
				&"beam":
					_draw_beam(c)
				&"eye_laser":
					_draw_eye_laser(c)
				&"web":
					_draw_webs()
				&"pincer":
					_draw_pincer(c)
				&"nova":
					_draw_nova(c)


func _draw_charge(c: Color) -> void:
	var o := _charge_origin()
	var k := _charge_ratio()
	var blink := 0.5 + 0.5 * sin(_t * (10.0 + k * 20.0))
	var screen_h := get_viewport_rect().size.y + 200.0
	match kind:
		&"beam":
			# 警示區：雷射會打到的範圍，邊線閃爍
			var half := bd.ult_width * 0.5
			draw_rect(Rect2(o.x - half, o.y, half * 2.0, screen_h), Color(c.r, c.g, c.b, 0.05 + 0.08 * k * blink))
			for sx: float in [-half, half]:
				var y := o.y
				while y < screen_h:
					draw_line(Vector2(o.x + sx, y), Vector2(o.x + sx, y + 22.0), Color(c.r, c.g, c.b, 0.35 + 0.5 * blink), 3.0)
					y += 40.0
			draw_line(o, o + Vector2(0, screen_h), Color(1, 0.6, 0.9, 0.25 + 0.4 * k * blink), 2.0)
		&"eye_laser":
			# 紅色瞄準扇形：顯示等一下會掃過的範圍
			var center := _aim_angle(bd.ult_eye_offset)
			var half := deg_to_rad(bd.ult_eye_sweep_deg) * 0.5
			var far := 1800.0
			var pts := PackedVector2Array([o, o + Vector2.RIGHT.rotated(center - half) * far, o + Vector2.RIGHT.rotated(center + half) * far])
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.04 + 0.07 * k * blink))
			for a: float in [center - half, center + half]:
				draw_line(o, o + Vector2.RIGHT.rotated(a) * far, Color(c.r, c.g, c.b, 0.3 + 0.5 * blink), 2.0)
			draw_line(o, o + Vector2.RIGHT.rotated(center) * far, Color(1, 0.5, 0.5, 0.2 + 0.4 * k), 1.5)
		&"pincer":
			# 兩道鉗子雷射會掃過的扇形
			for side: float in [-1.0, 1.0]:
				var po := _pincer_origin(side)
				var a0 := deg_to_rad(90.0 + 6.0 * side)
				var a1 := deg_to_rad(90.0 - 12.0 * side)
				var far := 1800.0
				draw_colored_polygon(PackedVector2Array([po, po + Vector2.RIGHT.rotated(a0) * far, po + Vector2.RIGHT.rotated(a1) * far]),
						Color(c.r, c.g, c.b, 0.05 + 0.08 * k * blink))
				for a: float in [a0, a1]:
					draw_line(po, po + Vector2.RIGHT.rotated(a) * far, Color(c.r, c.g, c.b, 0.3 + 0.5 * blink), 2.0)
				draw_circle(po, 8.0 + 18.0 * k, Color(c.r, c.g, c.b, 0.6))
		&"nova":
			# 核心外圍一圈圈往內收的預告環
			for i in 3:
				var rr := fmod(200.0 - _t * 220.0 + i * 70.0, 210.0) + 20.0
				draw_arc(o, rr, 0, TAU, 48, Color(c.r, c.g, c.b, 0.25 + 0.4 * k), 3.0)
		&"feather":
			# 每個翼砲台閃爍
			for p in bd.ult_feather_points:
				draw_circle(p, 5.0 + 6.0 * k * blink, Color(c.r, c.g, c.b, 0.5 + 0.4 * blink))
		&"web":
			# 口部的白色絲線蓄力
			for i in 6:
				var a := _t * 4.0 + TAU * i / 6.0
				draw_line(o, o + Vector2.RIGHT.rotated(a) * (20.0 + 20.0 * k), Color(0.9, 0.9, 1.0, 0.5 * k), 2.0)
	# 能量粒子被吸進來
	var pc := c if kind != &"web" else Color(0.85, 0.85, 1.0)
	for p in _particles:
		var ang: float = p[0]
		var dist: float = p[1]
		var pos := o + Vector2(cos(ang), sin(ang)) * dist
		var tail := o + Vector2(cos(ang), sin(ang)) * (dist + 18.0)
		draw_line(pos, tail, Color(pc.r, pc.g, pc.b, 0.8), 3.0)
	# 能量球越來越大
	var r := 10.0 + 34.0 * k + 3.0 * sin(_t * 30.0)
	if kind == &"eye_laser":
		r *= 1.3
	draw_circle(o, r * 1.8, Color(pc.r, pc.g, pc.b, 0.18))
	draw_circle(o, r, Color(pc.r, pc.g, pc.b, 0.6))
	draw_circle(o, r * 0.55, Color(1, 0.9, 0.9, 0.95))
	for i in 4:
		draw_arc(o, r * 1.4 + i * 6.0, _t * (3.0 + i), _t * (3.0 + i) + PI * 0.8, 16, Color(pc.r, pc.g, pc.b, 0.5), 2.0)


func _draw_beam(c: Color) -> void:
	var o := bd.ult_origin
	var screen_h := get_viewport_rect().size.y + 200.0
	var w := bd.ult_width * _beam_ratio(bd.ult_fire_time)
	var flick := 0.9 + 0.1 * sin(_t * 70.0)
	var end := o + Vector2(0, screen_h)
	draw_line(o, end, Color(c.r, c.g, c.b, 0.25), w * 1.5 * flick)
	draw_line(o, end, Color(c.r, c.g, c.b, 0.7), w * flick)
	draw_line(o, end, Color(1, 0.85, 1, 0.95), w * 0.4)
	draw_circle(o, w * 0.6, Color(c.r, c.g, c.b, 0.6))
	draw_circle(o, w * 0.35, Color(1, 0.95, 1, 1))
	for i in 10:
		var y := fmod(_t * 900.0 + i * 140.0, screen_h)
		draw_line(o + Vector2(-w * 0.5, y), o + Vector2(w * 0.5, y), Color(1, 0.8, 1, 0.25), 6.0)


func _draw_eye_laser(c: Color) -> void:
	var o := bd.ult_eye_offset
	var w := bd.ult_eye_width * _beam_ratio(bd.ult_eye_fire)
	var dir := Vector2.RIGHT.rotated(_eye_angle())
	var end := o + dir * 1900.0
	var flick := 0.88 + 0.12 * sin(_t * 80.0)
	draw_line(o, end, Color(c.r, c.g, c.b, 0.22), w * 2.0 * flick)
	draw_line(o, end, Color(c.r, c.g, c.b, 0.75), w * flick)
	draw_line(o, end, Color(1, 0.75, 0.7, 0.95), w * 0.35)
	# 眼睛的強光
	draw_circle(o, w * 1.1, Color(c.r, c.g, c.b, 0.5))
	draw_circle(o, w * 0.55, Color(1, 0.9, 0.85, 1))
	# 光束上流動的能量點
	for i in 8:
		var d := fmod(_t * 1400.0 + i * 230.0, 1900.0)
		var p := o + dir * d
		draw_circle(p, w * 0.3, Color(1, 0.6, 0.5, 0.35))


func _draw_webs() -> void:
	for w in _webs:
		var p := to_local(w[0] as Vector2)
		var rot: float = w[2]
		var r := WEB_RADIUS
		var col := Color(0.88, 0.9, 1.0, 0.85)
		draw_circle(p, r * 1.3, Color(0.7, 0.75, 1.0, 0.12))
		for i in 8:   # 放射絲
			var a := rot + TAU * i / 8.0
			draw_line(p, p + Vector2.RIGHT.rotated(a) * r, col, 1.6)
		for ring in 3:   # 同心絲圈（八角形）
			var rr := r * (0.35 + 0.3 * ring)
			var pts := PackedVector2Array()
			for i in 9:
				pts.append(p + Vector2.RIGHT.rotated(rot + TAU * i / 8.0) * rr)
			draw_polyline(pts, Color(col.r, col.g, col.b, 0.7), 1.3)
		draw_circle(p, 4.0, Color(1, 0.3, 0.35, 0.9))


func _draw_pincer(c: Color) -> void:
	var w := bd.ult_pincer_width * _beam_ratio(bd.ult_pincer_fire)
	var flick := 0.88 + 0.12 * sin(_t * 75.0)
	for side: float in [-1.0, 1.0]:
		var o := _pincer_origin(side)
		var end := o + Vector2.RIGHT.rotated(_pincer_angle(side)) * 1900.0
		draw_line(o, end, Color(c.r, c.g, c.b, 0.22), w * 2.0 * flick)
		draw_line(o, end, Color(c.r, c.g, c.b, 0.75), w * flick)
		draw_line(o, end, Color(1, 0.85, 1, 0.95), w * 0.35)
		draw_circle(o, w * 0.9, Color(c.r, c.g, c.b, 0.6))
		draw_circle(o, w * 0.45, Color(1, 0.95, 1, 1))


func _draw_nova(c: Color) -> void:
	var o := bd.ult_origin
	var half_gap := deg_to_rad(bd.ult_nova_gap_deg) * 0.5
	for r in _rings:
		var rad: float = r[0]
		var gap: float = r[1]
		var a0 := gap + half_gap
		var a1 := gap - half_gap + TAU
		var segs := clampi(int(rad / 6.0), 24, 160)
		draw_arc(o, rad, a0, a1, segs, Color(c.r, c.g, c.b, 0.25), bd.ult_nova_width * 1.8)
		draw_arc(o, rad, a0, a1, segs, Color(c.r, c.g, c.b, 0.8), bd.ult_nova_width * 0.8)
		draw_arc(o, rad, a0, a1, segs, Color(1, 0.85, 0.8, 0.95), bd.ult_nova_width * 0.25)
	if _rings_left > 0:
		draw_circle(o, 30.0 + 6.0 * sin(_t * 30.0), Color(c.r, c.g, c.b, 0.7))
