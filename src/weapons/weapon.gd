class_name Weapon
extends Node2D
## 掛在玩家身上的主武器，依照 WeaponData 與目前火力等級自動攻擊。
## BULLET 發射子彈（可穿透）；LASER 畫出多條細光束（火力越高越多條）；ARC 放出連鎖閃電。

const LASER_MUZZLE := Vector2(0, -40)

## 連鎖閃電額外多放的閃電數
const EXTRA_ARCS := 3

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
			_beam_lens.clear()
			_arc_fade = 0.0
			queue_redraw()
var _cooldown := 0.0
var _flash_col := Color(0.6, 0.9, 1.0)
# SMCPKG_SUPPORT>>>CursorM9Shot
## 射擊音效最短間隔。一輪多發只發一次訊號，連射再由 AudioManager 節流。
var _shot_sfx_wait := 0.0
# SMCPKG_SUPPORT<<<CursorM9ShotEnd

# 雷射狀態（每條光束各自的長度與是否命中）
var _beam_lens := PackedFloat32Array()
var _beam_hits: Array[bool] = []
var _laser_tick := 0.0
var _t := 0.0

# 連鎖閃電狀態：每段閃電是一串世界座標折線，_arc_fade 從 1 淡到 0
var _arcs: Array[PackedVector2Array] = []
var _arc_fade := 0.0
var _arc_cd := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	# SMCPKG_SUPPORT>>>CursorM9ShotTick
	_shot_sfx_wait = maxf(_shot_sfx_wait - delta, 0.0)
	# SMCPKG_SUPPORT<<<CursorM9ShotTickEnd
	if data == null or not firing:
		return
	if data.kind == WeaponData.Kind.LASER:
		_process_laser(delta)
		return
	if data.kind == WeaponData.Kind.ARC:
		_process_arc(delta)
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
	# SMCPKG_SUPPORT>>>CursorM9ShotVolley
	_emit_shot_sfx()
	# SMCPKG_SUPPORT<<<CursorM9ShotVolleyEnd


func _shoot(offset: Vector2, deg: float, dmg: int) -> void:
	var dir := Vector2.UP.rotated(deg_to_rad(deg))
	if NeonFx.instance:
		NeonFx.instance.muzzle(global_position + offset, _flash_col)
	var b := BulletPool.instance.spawn(global_position + offset, dir * data.bullet_speed,
			data.bullet_texture, data.bullet_radius, dmg, true)
	b.pierce = data.pierce
	b.homing = data.homing
	b.splash_radius = data.splash_radius
	b.splash_damage = data.splash_damage


# SMCPKG_SUPPORT>>>CursorM9ShotEmit
func _emit_shot_sfx() -> void:
	if data == null or _shot_sfx_wait > 0.0:
		return
	_shot_sfx_wait = 0.08
	var kind_name := &"bullet"
	if data.kind == WeaponData.Kind.LASER:
		kind_name = &"laser"
	elif data.kind == WeaponData.Kind.ARC:
		kind_name = &"arc"
	Events.weapon_fired.emit(data.id, kind_name)
# SMCPKG_SUPPORT<<<CursorM9ShotEmitEnd


# ---------- 雷射：細光束，火力越高條數越多 ----------

func _beam_x(i: int, n: int) -> float:
	var x := (i - (n - 1) / 2.0) * data.laser_spacing
	if data.laser_sweep > 0.0:
		x += sin(_t * 3.2 + i * 0.7) * data.laser_sweep * (1.0 if i % 2 == 0 else -1.0)
	return x


func _process_laser(delta: float) -> void:
	var n := data.laser_beams(level)
	var half := data.laser_width(level) / 2.0
	_beam_lens.resize(n)
	_beam_hits.resize(n)
	_laser_tick -= delta
	var tick := _laser_tick <= 0.0
	if tick:
		_laser_tick = data.laser_tick
		# SMCPKG_SUPPORT>>>CursorM9LaserSfx
		_emit_shot_sfx()
		# SMCPKG_SUPPORT<<<CursorM9LaserSfxEnd
	var dmg := data.laser_hit_damage(level)
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	for b in n:
		var origin := global_position + LASER_MUZZLE + Vector2(_beam_x(b, n), 0)
		var target: Enemy = null
		var best_y := -INF
		var best_p := Vector2.ZERO
		for node in enemies:
			var e := node as Enemy
			if e == null or e.health.dead or not e.is_on_screen():
				continue
			# 多弱點的敵人：找這條光束對得到的那一個弱點
			for p: Vector2 in e.aim_points():
				if p.y >= origin.y:
					continue
				if absf(p.x - origin.x) <= half + e.aim_radius() * 0.8 and p.y > best_y:
					best_y = p.y
					best_p = p
					target = e
		if target:
			_beam_lens[b] = maxf(origin.y - (best_p.y + target.aim_radius() * 0.5), 0.0)
			_beam_hits[b] = true
			if tick:
				target.take_damage(dmg)
		else:
			_beam_lens[b] = origin.y + 40.0
			_beam_hits[b] = false
	queue_redraw()


# ---------- 連鎖閃電 ----------

func _process_arc(delta: float) -> void:
	_arc_fade = maxf(_arc_fade - delta * 9.0, 0.0)
	_arc_cd -= delta
	queue_redraw()
	if _arc_cd > 0.0:
		return
	_arc_cd = data.arc_interval
	# SMCPKG_SUPPORT>>>CursorM9ArcSfx
	_emit_shot_sfx()
	# SMCPKG_SUPPORT<<<CursorM9ArcSfxEnd
	var origin := global_position + LASER_MUZZLE
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	var hit: Array[Enemy] = []
	var from := origin
	var dmg := data.arc_hit_damage(level)
	var chains := data.arc_chains(level)
	_arcs.clear()
	for c in chains:
		var limit := data.arc_range if c == 0 else data.arc_jump
		var best: Enemy = null
		var best_d := limit
		for node in enemies:
			var e := node as Enemy
			if e == null or e.health.dead or not e.is_on_screen() or e in hit:
				continue
			# 第一下只打前方的敵人
			if c == 0 and e.aim_point().y > origin.y + 20.0:
				continue
			var d := from.distance_to(e.aim_point())
			# Boss 體型大且停在畫面上方：第一下多給 420 的射程，避免連鎖閃電打不到 Boss
			if c == 0 and e is Boss:
				d -= 420.0
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		hit.append(best)
		_arcs.append(_bolt(from, best.aim_point()))
		from = best.aim_point()
	# 額外 3 道閃電（使用者 2026-11-03 要求）：優先打還沒被電到的敵人；
	# 沒有其他目標時打在主目標上，傷害減半
	var extra_hits: Array[Enemy] = []
	for k in EXTRA_ARCS:
		var best: Enemy = null
		var best_d := data.arc_range
		for node in enemies:
			var e := node as Enemy
			if e == null or e.health.dead or not e.is_on_screen() or e in hit or e in extra_hits:
				continue
			if e.aim_point().y > origin.y + 20.0:
				continue
			var d := origin.distance_to(e.aim_point()) - (420.0 if e is Boss else 0.0)
			if d < best_d:
				best_d = d
				best = e
		if best:
			extra_hits.append(best)
			_arcs.append(_bolt(origin, best.aim_point()))
		elif not hit.is_empty():
			_arcs.append(_bolt(origin, hit[0].aim_point()))
			hit[0].take_damage(maxi(dmg / 2, 1))
	if hit.is_empty() and extra_hits.is_empty():
		# 沒有目標：往前放出幾段電弧
		for k in EXTRA_ARCS + 1:
			_arcs.append(_bolt(origin, origin + Vector2(randf_range(-90, 90), -120)))
	else:
		for e in hit + extra_hits:
			e.take_damage(dmg)
			if NeonFx.instance:
				NeonFx.instance.impact(e.aim_point(), data.laser_color)
	_arc_fade = 1.0


## 產生鋸齒狀閃電折線（世界座標）
func _bolt(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var segs := maxi(4, int(a.distance_to(b) / 28.0))
	var normal := (b - a).normalized().orthogonal()
	for i in range(1, segs):
		var k := float(i) / segs
		pts.append(a.lerp(b, k) + normal * randf_range(-14.0, 14.0))
	pts.append(b)
	return pts


func _draw() -> void:
	if data == null:
		return
	if data.kind == WeaponData.Kind.ARC:
		_draw_arcs()
	elif data.kind == WeaponData.Kind.LASER:
		_draw_lasers()


func _draw_arcs() -> void:
	if _arc_fade <= 0.0:
		return
	var c := data.laser_color
	for arc in _arcs:
		var local := PackedVector2Array()
		for p in arc:
			local.append(to_local(p))
		# 閃電線條加粗 3 倍
		draw_polyline(local, Color(c.r, c.g, c.b, 0.3 * _arc_fade), 27.0)
		draw_polyline(local, Color(c.r, c.g, c.b, 0.85 * _arc_fade), 10.5)
		draw_polyline(local, Color(1, 1, 1, _arc_fade), 4.5)
		draw_circle(local[local.size() - 1], 18.0, Color(c.r, c.g, c.b, 0.6 * _arc_fade))
	draw_circle(LASER_MUZZLE, 16.0, Color(c.r, c.g, c.b, 0.7 * _arc_fade))


func _draw_lasers() -> void:
	if not firing or _beam_lens.is_empty():
		return
	var w := data.laser_width(level)
	var c := data.laser_color
	var flick := 0.85 + 0.15 * sin(_t * 60.0)
	var n := _beam_lens.size()
	for b in n:
		var muzzle := LASER_MUZZLE + Vector2(_beam_x(b, n), 0)
		var top := muzzle + Vector2(0, -_beam_lens[b])
		draw_line(muzzle, top, Color(c.r, c.g, c.b, 0.22), w * 2.4 * flick)
		draw_line(muzzle, top, Color(c.r, c.g, c.b, 0.7), w * flick)
		draw_line(muzzle, top, Color(0.85, 0.95, 1.0, 0.95), w * 0.35)
		draw_circle(muzzle, w * 0.9, Color(c.r, c.g, c.b, 0.55))
		if _beam_hits[b]:
			var r := w * (1.0 + 0.3 * sin(_t * 45.0 + b))
			draw_circle(top, r, Color(c.r, c.g, c.b, 0.55))
			draw_circle(top, r * 0.5, Color(1, 1, 1, 0.9))
