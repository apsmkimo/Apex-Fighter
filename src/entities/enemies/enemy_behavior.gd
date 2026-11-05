class_name EnemyBehavior
extends Node2D
## 敵機特殊行為（EnemyData.behavior），掛在 Enemy 底下。
## 發光的部分畫在這個節點（加亮混合）；需要時可以接管 Enemy 的移動。

var enemy: Enemy
var data: EnemyData
var _t := 0.0
var _cd := 0.0
var _step := 0          # 各行為自己的階段
var _step_t := 0.0
var _vel := Vector2.ZERO
var _takeover := false
var _hit_done := false
var _cycle := 0
var _ghost_cd := 0.0
# 加特林
var _last_player := Vector2.ZERO
var _player_vel := Vector2.ZERO
# 聚焦雷射
var _laser_from := 0.0
var _laser_to := 0.0
var _scorch_cd := 0.0
# 繞場衛星
var _orbit_center := Vector2.ZERO
var _orbit_ang := 0.0

const SWORD_CHARGE := 0.7
const SWORD_DASH := 0.95
const GAT_RATE := 0.15
const GAT_RAPID_RATE := 0.06
const GAT_BURST := 1.4
const GAT_SWELL := 0.5
const GAT_RAPID := 1.6
const LASER_CHARGE := 1.0
const LASER_FIRE := 2.0
const LASER_WIDTH := 26.0
const STEAM_TIME := 0.9


func _ready() -> void:
	data = enemy.data
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 1
	_cd = data.first_fire_delay
	if data.behavior == &"orbit":
		_takeover = true
		_orbit_ang = randf() * TAU


func overrides_movement() -> bool:
	return _takeover


func _physics_process(delta: float) -> void:
	if enemy == null or enemy.health.dead:
		return
	_t += delta
	var pl := Player.instance
	if pl and pl.alive:
		_player_vel = _player_vel.lerp((pl.global_position - _last_player) / maxf(delta, 0.001), minf(1.0, 6.0 * delta))
		_last_player = pl.global_position
	match data.behavior:
		&"kamikaze":
			_kamikaze(delta)
		&"sword":
			_sword(delta)
		&"artillery":
			_artillery(delta)
		&"gatling":
			_gatling(delta)
		&"focus_laser":
			_focus_laser(delta)
		&"vlauncher":
			_vlauncher(delta)
		&"orbit":
			_orbit(delta)
	queue_redraw()


func _ready_to_act() -> bool:
	return enemy.is_on_screen() and enemy.global_position.y < get_viewport_rect().size.y * 0.75


func _player_pos() -> Vector2:
	var pl := Player.instance
	if pl and pl.alive:
		return pl.global_position
	return get_viewport_rect().size * Vector2(0.5, 0.8)


func _muzzle(i: int) -> Vector2:
	var p := data.behavior_points[i % data.behavior_points.size()] if not data.behavior_points.is_empty() else Vector2(0, 30)
	return enemy.global_position + p.rotated(enemy.sprite.rotation)


func _shoot(from: Vector2, vel: Vector2, tex: Texture2D, radius: float) -> void:
	if BulletPool.instance:
		BulletPool.instance.spawn(from, vel, tex, radius, data.bullet_damage, false)


# ---------- kamikaze：低血自爆衝鋒 ----------

func _kamikaze(delta: float) -> void:
	if not _takeover:
		if enemy.health.ratio() <= data.kamikaze_ratio and enemy.is_on_screen():
			_takeover = true
			_vel = (_player_pos() - enemy.global_position).normalized() * data.kamikaze_speed * 0.4
			if NeonFx.instance:
				NeonFx.instance.ring(enemy.global_position, 10.0, 70.0, 0.3, data.behavior_color, 4.0)
		return
	var want := (_player_pos() - enemy.global_position).normalized() * data.kamikaze_speed
	_vel = _vel.move_toward(want, data.kamikaze_speed * 2.2 * delta)
	enemy.position += _vel * delta
	enemy.sprite.rotation = _vel.angle() - PI / 2.0
	if NeonFx.instance and Engine.get_physics_frames() % 2 == 0:
		NeonFx.instance.emit(enemy.global_position - _vel.normalized() * 30.0, -_vel * 0.2, 0.3, 9.0, data.behavior_color)
	var pl := Player.instance
	if pl and pl.alive and pl.global_position.distance_to(enemy.global_position) < data.hit_radius + pl.ship.hitbox_radius + 6.0:
		pl.take_hit(data.contact_damage)
		if NeonFx.instance:
			NeonFx.instance.explode(enemy.global_position, data.explosion_scale * 1.3)
		Events.screen_shake.emit(6.0, 0.2)
		enemy.queue_free()
	elif not get_viewport_rect().grow(120.0).has_point(enemy.global_position):
		enemy.queue_free()


# ---------- sword：劍氣＋重劍突刺 ----------

func _sword(delta: float) -> void:
	match _step:
		0:
			if _ready_to_act():
				_cd -= delta
				if _cd <= 0.0:
					_step = 1
					_step_t = 0.0
		1:
			# 機首蓄力
			_step_t += delta
			if _step_t >= SWORD_CHARGE:
				var from := _muzzle(0)
				var dir := (_player_pos() - from).normalized()
				var tex := data.behavior_texture
				for i in 3:   # 三段排成一條細長的劍氣
					_shoot(from + dir * i * 26.0, dir * 760.0, tex, 7.0)
				Events.screen_shake.emit(3.0, 0.1)
				_step = 2
				_step_t = 0.0
		2:
			_step_t += delta
			if _step_t >= 0.45:
				_takeover = true
				_vel = (_player_pos() - enemy.global_position).normalized() * 720.0
				_step = 3
				_step_t = 0.0
		3:
			# 突刺：沿直線衝過去，留下紅光殘影
			_step_t += delta
			enemy.position += _vel * delta
			enemy.sprite.rotation = lerp_angle(enemy.sprite.rotation, _vel.angle() - PI / 2.0, minf(1.0, 10.0 * delta))
			_ghost_cd -= delta
			if _ghost_cd <= 0.0:
				_ghost_cd = 0.035
				Afterimage.spawn(enemy.get_parent(), enemy.sprite, enemy.global_position, data.behavior_color)
			if _step_t > SWORD_DASH:
				_vel = _vel.move_toward(Vector2(0, 300), 900.0 * delta)
			if not get_viewport_rect().grow(140.0).has_point(enemy.global_position):
				enemy.queue_free()


# ---------- artillery：重砲轟炸 ----------

func _artillery(delta: float) -> void:
	if not _ready_to_act():
		return
	_cd -= delta
	if _step > 0:
		_step_t -= delta
		if _step_t <= 0.0:
			# 四門砲輪流開火
			var i := data.behavior_count - _step
			var target := _player_pos() + Vector2(randf_range(-80, 80), randf_range(-60, 60))
			ArtilleryShell.spawn(enemy.get_parent(), _muzzle(i), target, data)
			if NeonFx.instance:
				NeonFx.instance.muzzle(_muzzle(i), data.behavior_color)
				NeonFx.instance.emit(_muzzle(i), Vector2(0, -80), 0.25, 26.0, data.behavior_color)
			Events.screen_shake.emit(2.5, 0.1)
			_step -= 1
			_step_t = 0.24
		return
	if _cd <= 0.0:
		_cd = data.behavior_interval
		_step = maxi(data.behavior_count, 1)
		_step_t = 0.0


# ---------- gatling：預判速射＋過熱連射 ----------

func _lead_target(from: Vector2, speed: float) -> Vector2:
	var p := _player_pos()
	var tt := from.distance_to(p) / speed
	return p + _player_vel.limit_length(400.0) * tt


func _gatling(delta: float) -> void:
	var from := _muzzle(0)
	var aim := _lead_target(from, 560.0)
	var want := (aim - enemy.global_position).angle() + PI / 2.0
	enemy.sprite.rotation = lerp_angle(enemy.sprite.rotation, want, minf(1.0, 6.0 * delta))
	if not _ready_to_act():
		enemy.sprite.scale = Vector2.ONE
		return
	_step_t += delta
	var swell := 0.0
	match _step:
		0:   # 等待
			if _step_t >= _cd:
				_step = 1 if (_cycle % 3) != 2 else 2
				_step_t = 0.0
				_cycle += 1
		1:   # 一般掃射
			_fire_gat(delta, GAT_RATE, 0.04)
			if _step_t >= GAT_BURST:
				_step = 0
				_step_t = 0.0
				_cd = 1.0
		2:   # 過熱：紅光膨脹
			swell = clampf(_step_t / GAT_SWELL, 0.0, 1.0)
			if _step_t >= GAT_SWELL:
				_step = 3
				_step_t = 0.0
				if NeonFx.instance:
					NeonFx.instance.ring(enemy.global_position, 20.0, 90.0, 0.3, data.behavior_color, 4.0)
		3:   # 連射模式
			swell = 1.0
			_fire_gat(delta, GAT_RAPID_RATE, 0.12)
			if _step_t >= GAT_RAPID:
				_step = 0
				_step_t = 0.0
				_cd = 1.6
	enemy.sprite.scale = Vector2.ONE * (1.0 + 0.1 * swell)
	if swell > 0.0:
		enemy.sprite.modulate = Color(1.0 + 0.8 * swell, 1.0 - 0.3 * swell, 1.0 - 0.3 * swell)


func _fire_gat(delta: float, rate: float, jitter: float) -> void:
	_ghost_cd -= delta
	if _ghost_cd > 0.0:
		return
	_ghost_cd = rate
	var from := _muzzle(0)
	var dir := (_lead_target(from, 560.0) - from).normalized().rotated(randf_range(-jitter, jitter))
	_shoot(from, dir * 560.0, data.behavior_texture, 5.0)
	if NeonFx.instance:
		NeonFx.instance.muzzle(from, data.behavior_color)
	Events.enemy_fired.emit(0)


# ---------- focus_laser：聚焦雷射旋轉掃場 ----------

func _laser_angle() -> float:
	return lerp_angle(_laser_from, _laser_to, ease(clampf(_step_t / LASER_FIRE, 0.0, 1.0), -1.4))


func _focus_laser(delta: float) -> void:
	match _step:
		0:
			if _ready_to_act():
				_cd -= delta
				if _cd <= 0.0:
					_step = 1
					_step_t = 0.0
		1:
			_step_t += delta
			if _step_t >= LASER_CHARGE:
				var center := (_player_pos() - enemy.global_position).angle()
				var dir := 1.0 if randf() < 0.5 else -1.0
				_laser_from = center - 0.5 * dir
				_laser_to = center + 1.25 * dir
				_step = 2
				_step_t = 0.0
				_hit_done = false
				Events.screen_shake.emit(5.0, 0.2)
		2:
			_step_t += delta
			var o := enemy.global_position
			var dir := Vector2.RIGHT.rotated(_laser_angle())
			var pl := Player.instance
			if not _hit_done and pl and pl.alive:
				var rel := pl.global_position - o
				if rel.dot(dir) > 0.0 and absf(rel.cross(dir)) < LASER_WIDTH * 0.4 + pl.ship.hitbox_radius:
					_hit_done = true
					pl.take_hit(data.behavior_damage)
			# 地板燒痕
			_scorch_cd -= delta
			if _scorch_cd <= 0.0:
				_scorch_cd = 0.07
				var far := _beam_length(o, dir)
				LavaPit.spawn_scorch(enemy.get_parent(), o + dir * randf_range(60.0, far), randf_range(26.0, 40.0))
			if _step_t >= LASER_FIRE:
				_step = 0
				_cd = data.behavior_interval


func _beam_length(o: Vector2, dir: Vector2) -> float:
	# 雷射射到畫面邊緣為止
	var r := get_viewport_rect()
	var best := 1800.0
	if dir.x > 0.001:
		best = minf(best, (r.size.x - o.x) / dir.x)
	elif dir.x < -0.001:
		best = minf(best, -o.x / dir.x)
	if dir.y > 0.001:
		best = minf(best, (r.size.y - o.y) / dir.y)
	elif dir.y < -0.001:
		best = minf(best, -o.y / dir.y)
	return maxf(best, 80.0)


# ---------- vlauncher：垂直飛彈巢 ----------

func _vlauncher(delta: float) -> void:
	match _step:
		0:
			if _ready_to_act():
				_cd -= delta
				if _cd <= 0.0:
					_step = 1
					_step_t = 0.0
		1:
			# 巢口冒紅光蒸氣
			_step_t += delta
			if NeonFx.instance and Engine.get_physics_frames() % 2 == 0:
				var p := _muzzle(randi())
				NeonFx.instance.emit(p, Vector2(randf_range(-25, 25), randf_range(-90, -40)), 0.7, randf_range(10.0, 18.0), Color(1.0, 0.3, 0.25, 0.55))
			if _step_t >= STEAM_TIME:
				_launch()
				_step = 0
				_cd = data.behavior_interval


func _launch() -> void:
	if data.behavior_missile == null:
		return
	for i in data.behavior_count:
		var m := Enemy.spawn_enemy(data.behavior_missile, _muzzle(i), enemy.get_parent())
		if m:
			# 先垂直升空，之後由飛彈本身轉向追蹤
			m.velocity = Vector2(randf_range(-40, 40), -1.0).normalized() * data.behavior_missile.home_speed
			m.rotation = m.velocity.angle()
	Events.screen_shake.emit(4.0, 0.2)
	if NeonFx.instance:
		NeonFx.instance.ring(enemy.global_position, 20.0, 80.0, 0.3, data.behavior_color, 4.0)


# ---------- orbit：被支配的衛星繞場旋轉 ----------

func _orbit(delta: float) -> void:
	var size := get_viewport_rect().size
	var r := 120.0
	var spd := 1.15 * (-1.0 if enemy.flip_x else 1.0)
	if _t < 1.6:
		# 進場：降到繞行中心
		_orbit_center = Vector2(enemy.spawn_pos.x, lerpf(enemy.spawn_pos.y, size.y * 0.28, ease(_t / 1.6, 0.5)))
		r *= _t / 1.6
	else:
		_orbit_center.y += 24.0 * delta
		if _t > 15.0:
			_orbit_center.y += 80.0 * delta
	_orbit_ang += spd * delta
	enemy.position = _orbit_center + Vector2(cos(_orbit_ang), sin(_orbit_ang) * 0.75) * r


# ---------- 繪製（加亮） ----------

func _draw() -> void:
	var c := data.behavior_color
	match data.behavior:
		&"sword":
			if _step == 1:
				var k := _step_t / SWORD_CHARGE
				var o := to_local(_muzzle(0))
				draw_circle(o, 6.0 + 18.0 * k, Color(c.r, c.g, c.b, 0.6))
				draw_circle(o, 3.0 + 7.0 * k, Color(1, 0.85, 0.8, 0.9))
				var p := to_local(_player_pos())
				draw_line(o, o + (p - o).normalized() * 900.0, Color(c.r, c.g, c.b, 0.15 + 0.35 * k), 2.0)
		&"gatling":
			if _step == 2 or _step == 3:
				var k := 1.0 if _step == 3 else clampf(_step_t / GAT_SWELL, 0.0, 1.0)
				draw_circle(Vector2.ZERO, data.hit_radius * (0.9 + 0.3 * k), Color(c.r, c.g, c.b, 0.18 * k))
				draw_circle(to_local(_muzzle(0)), 8.0 + 8.0 * k, Color(c.r, c.g, c.b, 0.5 * k))
		&"focus_laser":
			_draw_focus(c)
		&"orbit":
			# 紅光脈衝環
			var ph := fmod(_t, 1.2) / 1.2
			draw_arc(Vector2.ZERO, 30.0 + 60.0 * ph, 0, TAU, 32, Color(c.r, c.g, c.b, 0.6 * (1.0 - ph)), 3.0)
			draw_arc(Vector2.ZERO, 44.0, _t * 2.0, _t * 2.0 + PI * 1.2, 24, Color(c.r, c.g, c.b, 0.35), 2.0)
			draw_circle(Vector2(0, -6), 8.0 + 2.0 * sin(_t * 8.0), Color(c.r, c.g, c.b, 0.45))


func _draw_focus(c: Color) -> void:
	var gold := Color(1.0, 0.82, 0.45)
	if _step == 1:
		# 香檳金聚焦環由外往內收
		var k := _step_t / LASER_CHARGE
		for i in 3:
			var rr := lerpf(70.0, 12.0, fmod(k + i / 3.0, 1.0))
			draw_arc(Vector2.ZERO, rr, 0, TAU, 32, Color(gold.r, gold.g, gold.b, 0.3 + 0.5 * k), 3.0)
		draw_circle(Vector2.ZERO, 8.0 + 14.0 * k, Color(c.r, c.g, c.b, 0.7))
		var p := to_local(_player_pos())
		draw_line(Vector2.ZERO, p.normalized() * 1600.0, Color(c.r, c.g, c.b, 0.12 + 0.3 * k), 2.0)
	elif _step == 2:
		var dir := Vector2.RIGHT.rotated(_laser_angle())
		var far := _beam_length(enemy.global_position, dir)
		var w := LASER_WIDTH * clampf(minf(_step_t / 0.1, (LASER_FIRE - _step_t) / 0.2), 0.0, 1.0)
		var flick := 0.88 + 0.12 * sin(_t * 80.0)
		var end := dir * far
		draw_line(Vector2.ZERO, end, Color(c.r, c.g, c.b, 0.25), w * 2.2 * flick)
		draw_line(Vector2.ZERO, end, Color(c.r, c.g, c.b, 0.8), w * flick)
		draw_line(Vector2.ZERO, end, Color(1, 0.8, 0.7, 0.95), w * 0.35)
		draw_circle(Vector2.ZERO, w * 1.2, Color(gold.r, gold.g, gold.b, 0.5))
		draw_circle(end, w * 1.4, Color(c.r, c.g, c.b, 0.5))


## 突刺殘影：機身形狀的紅色殘影，迅速淡出
class Afterimage extends Sprite2D:
	var _life := 0.3
	var _max := 0.3
	static var _mat: CanvasItemMaterial

	static func spawn(parent: Node, src: Sprite2D, pos: Vector2, col: Color) -> void:
		if parent == null or not is_instance_valid(parent):
			return
		var g := Afterimage.new()
		g.texture = src.texture
		g.rotation = src.rotation
		g.scale = src.scale
		g.global_position = pos
		g.modulate = Color(col.r * 1.4, col.g * 0.6, col.b * 0.6, 0.6)
		if _mat == null:
			_mat = CanvasItemMaterial.new()
			_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = _mat
		g.z_index = -1
		parent.add_child(g)

	func _process(delta: float) -> void:
		_life -= delta
		modulate.a = 0.6 * maxf(_life / _max, 0.0)
		if _life <= 0.0:
			queue_free()


## 重砲彈：從砲口慢慢飛向落點（地面上的點，跟著地表捲動），落點有紅色預警圈；落地爆炸濺射並留下岩漿坑
class ArtilleryShell extends Node2D:
	const FLIGHT := 1.15
	var from := Vector2.ZERO
	var target := Vector2.ZERO
	var d: EnemyData
	var _age := 0.0
	static var _mat: CanvasItemMaterial

	static func spawn(parent: Node, at: Vector2, to: Vector2, ed: EnemyData) -> void:
		if parent == null or not is_instance_valid(parent):
			return
		var s := ArtilleryShell.new()
		s.from = at
		s.target = to
		s.d = ed
		if _mat == null:
			_mat = CanvasItemMaterial.new()
			_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = _mat
		s.z_index = 2
		s.top_level = true
		parent.add_child(s)

	func _physics_process(delta: float) -> void:
		_age += delta
		var g := ScrollBackground.ground_speed * delta
		target.y += g
		from.y += g
		if _age >= FLIGHT:
			_explode()
			return
		queue_redraw()

	func _pos() -> Vector2:
		var k := _age / FLIGHT
		# 拋物線：中段往上拱起
		return from.lerp(target, k) + Vector2(0, -160.0 * sin(k * PI))

	func _explode() -> void:
		var r := 78.0
		if NeonFx.instance:
			NeonFx.instance.explode(target, 1.4)
			NeonFx.instance.ring(target, 10.0, r * 1.2, 0.35, d.behavior_color, 5.0)
		Events.screen_shake.emit(5.0, 0.18)
		var pl := Player.instance
		if pl and pl.alive and pl.global_position.distance_to(target) < r + pl.ship.hitbox_radius:
			pl.take_hit(d.behavior_damage)
		if d.death_pit and d.behavior_pit_size > 0.0:
			LavaPit.spawn(get_parent(), target, d.death_pit, d.behavior_pit_size)
		queue_free()

	func _draw() -> void:
		var k := _age / FLIGHT
		var c := d.behavior_color
		# 落點預警圈（越接近落地越亮、越小）
		var blink := 0.5 + 0.5 * sin(_age * (12.0 + 20.0 * k))
		draw_arc(target, lerpf(90.0, 70.0, k), 0, TAU, 40, Color(c.r, c.g, c.b, 0.25 + 0.45 * blink * k), 3.0)
		draw_circle(target, 70.0 * k, Color(c.r, c.g, c.b, 0.08 + 0.1 * k))
		var p := _pos()
		var sz := 13.0 + 9.0 * sin(k * PI)
		if d.behavior_texture:
			var ts := d.behavior_texture.get_size()
			var sc := sz * 2.6 / maxf(ts.x, ts.y)
			draw_set_transform(p, _age * 6.0, Vector2(sc, sc))
			draw_texture(d.behavior_texture, -ts * 0.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(p, sz, Color(c.r, c.g, c.b, 0.8))
		draw_circle(p, sz * 0.45, Color(1, 0.85, 0.75, 0.9))
