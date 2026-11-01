class_name Weapon
extends Node2D
## 掛在玩家身上的主武器，依照 WeaponData 與目前火力等級自動攻擊。
## 一般武器發射子彈；LASER 武器畫出一道連續光束，打到正前方最近的敵人。

const LASER_MUZZLE := Vector2(0, -40)

var data: WeaponData:
	set(v):
		data = v
		_cooldown = 0.0
		queue_redraw()
var level := 0
var firing := false:
	set(v):
		firing = v
		if not v:
			_beam_len = 0.0
			queue_redraw()
var _cooldown := 0.0
var _flash_col := Color(0.6, 0.9, 1.0)

# 雷射狀態
var _beam_len := 0.0
var _beam_hit := false
var _laser_tick := 0.0
var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	if data == null or not firing:
		return
	if data.kind == WeaponData.Kind.LASER:
		_process_laser(delta)
		return
	if data.levels.is_empty() or BulletPool.instance == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var lv := data.get_level(level)
	_cooldown = lv.fire_interval
	var dmg := data.bullet_damage(level)
	_flash_col = NeonFx.tex_color(data.bullet_texture)
	var max_angle := 0.0
	var max_off := 0.0
	for i in lv.offsets.size():
		var deg := lv.angles_deg[i] if i < lv.angles_deg.size() else 0.0
		max_angle = maxf(max_angle, absf(deg))
		max_off = maxf(max_off, absf(lv.offsets[i].x))
		_shoot(lv.offsets[i], deg, dmg)
	# 超過設計等級：外側一對一對加上去
	var step := 6.0 if max_angle > 4.0 else 3.0
	for k in data.extra_pairs(level):
		var deg := max_angle + step * (k + 1)
		var ox := max_off + 10.0 * (k + 1)
		_shoot(Vector2(-ox, -10.0 + 4.0 * k), -deg, dmg)
		_shoot(Vector2(ox, -10.0 + 4.0 * k), deg, dmg)


func _shoot(offset: Vector2, deg: float, dmg: int) -> void:
	var dir := Vector2.UP.rotated(deg_to_rad(deg))
	if NeonFx.instance:
		NeonFx.instance.muzzle(global_position + offset, _flash_col)
	BulletPool.instance.spawn(global_position + offset, dir * data.bullet_speed,
			data.bullet_texture, data.bullet_radius, dmg, true)


# ---------- 雷射 ----------

func _process_laser(delta: float) -> void:
	var origin := global_position + LASER_MUZZLE
	var half := data.laser_width(level) / 2.0
	var target: Enemy = null
	var best_y := -INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var e := node as Enemy
		if e == null or e.health.dead or not e.is_on_screen():
			continue
		var p := e.global_position
		if p.y >= origin.y:
			continue
		if absf(p.x - origin.x) <= half + e.data.hit_radius * 0.8 and p.y > best_y:
			best_y = p.y
			target = e
	if target:
		_beam_len = origin.y - (target.global_position.y + target.data.hit_radius * 0.5)
		_beam_hit = true
		_laser_tick -= delta
		if _laser_tick <= 0.0:
			_laser_tick = data.laser_tick
			target.take_damage(data.laser_hit_damage(level))
	else:
		_beam_len = origin.y + 40.0
		_beam_hit = false
	_beam_len = maxf(_beam_len, 0.0)
	queue_redraw()


func _draw() -> void:
	if data == null or data.kind != WeaponData.Kind.LASER or _beam_len <= 0.0:
		return
	var w := data.laser_width(level)
	var c := data.laser_color
	var flick := 0.85 + 0.15 * sin(_t * 60.0)
	var top := LASER_MUZZLE + Vector2(0, -_beam_len)
	# 外層光暈 → 主光束 → 白色核心
	draw_line(LASER_MUZZLE, top, Color(c.r, c.g, c.b, 0.22), w * 2.2 * flick)
	draw_line(LASER_MUZZLE, top, Color(c.r, c.g, c.b, 0.65), w * flick)
	draw_line(LASER_MUZZLE, top, Color(0.85, 0.95, 1.0, 0.95), w * 0.35)
	# 砲口光球
	draw_circle(LASER_MUZZLE, w * 0.9, Color(c.r, c.g, c.b, 0.5))
	draw_circle(LASER_MUZZLE, w * 0.45, Color(0.9, 0.97, 1.0, 0.95))
	# 命中火花
	if _beam_hit:
		var r := w * (0.9 + 0.3 * sin(_t * 45.0))
		draw_circle(top, r, Color(c.r, c.g, c.b, 0.55))
		draw_circle(top, r * 0.5, Color(1, 1, 1, 0.9))
		for i in 6:
			var a := _t * 9.0 + TAU * i / 6.0
			draw_line(top, top + Vector2.RIGHT.rotated(a) * r * 1.8, Color(0.7, 0.9, 1.0, 0.8), 2.0)
