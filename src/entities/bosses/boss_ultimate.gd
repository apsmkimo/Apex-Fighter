class_name BossUltimate
extends Node2D
## Boss 大絕招：儲備能量（能量粒子聚集＋地面警示區）→ 往下發射大範圍雷射。
## 玩家被打到扣 BossData.ult_damage（滿血只擋得住一次），護盾可以抵銷。

enum State { IDLE, CHARGE, FIRE }

var boss: Boss
var bd: BossData
var state := State.IDLE
var _timer := 0.0
var _t := 0.0
var _hit_done := false
var _particles: Array = []   # [角度, 距離, 速度]


func setup(b: Boss) -> void:
	boss = b
	bd = b.boss_data()
	_timer = bd.entry_time + bd.ult_first_delay


func _ready() -> void:
	z_index = 5
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func busy() -> bool:
	return state != State.IDLE


func cancel() -> void:
	state = State.IDLE
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
			_check_hit()
			Events.screen_shake.emit(5.0, 0.1)
			if _timer <= 0.0:
				state = State.IDLE
				_timer = bd.ult_interval
				Events.boss_ultimate.emit("end")
	queue_redraw()


func _start_charge() -> void:
	state = State.CHARGE
	_timer = bd.ult_charge_time
	_particles.clear()
	Events.boss_ultimate.emit("charge")


func _start_fire() -> void:
	state = State.FIRE
	_timer = bd.ult_fire_time
	_hit_done = false
	Events.boss_ultimate.emit("fire")
	Events.screen_shake.emit(14.0, 0.4)


## 0 → 1：儲能進度
func _charge_ratio() -> float:
	return clampf(1.0 - _timer / bd.ult_charge_time, 0.0, 1.0)


## 0 → 1 → 0：雷射寬度（開頭快速展開，結尾收細）
func _beam_ratio() -> float:
	var elapsed := bd.ult_fire_time - _timer
	return clampf(minf(elapsed / 0.12, _timer / 0.25), 0.0, 1.0)


func _update_particles(delta: float) -> void:
	# 粒子從四周被吸進砲口
	var spawn := 2 + int(_charge_ratio() * 4.0)
	for i in spawn:
		_particles.append([randf() * TAU, randf_range(110.0, 220.0), randf_range(260.0, 480.0)])
	for p in _particles:
		p[1] -= p[2] * delta
	_particles = _particles.filter(func(p: Array) -> bool: return p[1] > 8.0)


func _check_hit() -> void:
	var pl := Player.instance
	if _hit_done or pl == null or not pl.alive or _beam_ratio() < 0.5:
		return
	var origin := global_position + bd.ult_origin
	var half := bd.ult_width * 0.5 * _beam_ratio() * 0.85
	if pl.global_position.y > origin.y and absf(pl.global_position.x - origin.x) < half + pl.ship.hitbox_radius:
		_hit_done = true   # 一次發射只扣一次血
		pl.take_hit(bd.ult_damage)


func _draw() -> void:
	var o := bd.ult_origin if bd else Vector2.ZERO
	var c := bd.ult_color if bd else Color.MAGENTA
	var screen_h := get_viewport_rect().size.y + 200.0
	match state:
		State.CHARGE:
			var k := _charge_ratio()
			# 警示區：雷射會打到的範圍，邊線閃爍
			var blink := 0.5 + 0.5 * sin(_t * (10.0 + k * 20.0))
			var half := bd.ult_width * 0.5
			draw_rect(Rect2(o.x - half, o.y, half * 2.0, screen_h), Color(c.r, c.g, c.b, 0.05 + 0.08 * k * blink))
			for sx: float in [-half, half]:
				var y := o.y
				while y < screen_h:   # 虛線邊界
					draw_line(Vector2(o.x + sx, y), Vector2(o.x + sx, y + 22.0), Color(c.r, c.g, c.b, 0.35 + 0.5 * blink), 3.0)
					y += 40.0
			# 細預瞄線
			draw_line(o, o + Vector2(0, screen_h), Color(1, 0.6, 0.9, 0.25 + 0.4 * k * blink), 2.0)
			# 被吸進來的能量粒子
			for p in _particles:
				var ang: float = p[0]
				var dist: float = p[1]
				var pos := o + Vector2(cos(ang), sin(ang)) * dist
				var tail := o + Vector2(cos(ang), sin(ang)) * (dist + 18.0)
				draw_line(pos, tail, Color(c.r, c.g, c.b, 0.8), 3.0)
			# 能量球越來越大
			var r := 10.0 + 34.0 * k + 3.0 * sin(_t * 30.0)
			draw_circle(o, r * 1.8, Color(c.r, c.g, c.b, 0.18))
			draw_circle(o, r, Color(c.r, c.g, c.b, 0.6))
			draw_circle(o, r * 0.55, Color(1, 0.9, 1, 0.95))
			for i in 4:   # 旋轉能量環
				draw_arc(o, r * 1.4 + i * 6.0, _t * (3.0 + i) , _t * (3.0 + i) + PI * 0.8, 16, Color(c.r, c.g, c.b, 0.5), 2.0)
		State.FIRE:
			var w := bd.ult_width * _beam_ratio()
			var flick := 0.9 + 0.1 * sin(_t * 70.0)
			var end := o + Vector2(0, screen_h)
			draw_line(o, end, Color(c.r, c.g, c.b, 0.25), w * 1.5 * flick)
			draw_line(o, end, Color(c.r, c.g, c.b, 0.7), w * flick)
			draw_line(o, end, Color(1, 0.85, 1, 0.95), w * 0.4)
			draw_circle(o, w * 0.6, Color(c.r, c.g, c.b, 0.6))
			draw_circle(o, w * 0.35, Color(1, 0.95, 1, 1))
			# 光束上的能量波紋
			for i in 10:
				var y := fmod(_t * 900.0 + i * 140.0, screen_h)
				draw_line(o + Vector2(-w * 0.5, y), o + Vector2(w * 0.5, y), Color(1, 0.8, 1, 0.25), 6.0)
