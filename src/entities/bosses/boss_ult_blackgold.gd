class_name BlackGoldUlt
extends Node
## 第六關黑金機甲的三種絕招（由 BossUltimate 呼叫）：
##   x_strike   全砲口聚能 → 十道紅光砲在地面交織成巨大 X（黑金裂紋＋岩漿）
##              X 留在地上：踩到每 0.2 秒扣血；出現 2 秒後引爆，之後淡出（共 3 秒）
##   focus_ring 浮游砲飛到空中圍成圓 → 六道雷射聚焦，紅光球膨脹 2 秒 → 炸開全場衝擊波＋多個岩漿坑
##              聚焦時打掉浮游砲：每少一座，衝擊波傷害減 1/6；全部打掉則紅光球潰散
##   annihilate 核心打開露出紅光黑洞（飄進三顆隕石）→ 超寬湮滅光柱緩慢橫掃全場，地板染紅
##              被掃到受到大傷害；躲在隕石後面（光柱的陰影裡）或用護盾才安全
## 圖層：floor（地板，一般混合 z -4）、beam（光柱，加亮 z 1）、cover（隕石與陰影，一般 z 2）、
##       hole（黑洞，一般 z 4）、hi（聚能、雷射、紅光球、衝擊波，加亮 z 5）

const KINDS := [&"x_strike", &"focus_ring", &"annihilate"]
const X_CHARGE := 1.6
const X_CONVERGE := 0.35
const X_BURN := 2.0
const X_FADE := 1.0
const X_TICK := 0.2
const FOCUS_CHARGE := 1.3
const FOCUS_GROW := 2.0
const SHOCK_SPEED := 1100.0
const ANNI_CHARGE := 2.6
const ANNI_AFTER := 1.1
const COVER_R := 58.0

var ult: BossUltimate
var boss: Boss
var bd: BossData
var kind: StringName = &""
var charging := false
var _t := 0.0          # 這次絕招的經過時間（蓄力與發射各自從 0 算）
var _gt := 0.0         # 全域時間（動畫用）
var _done := true
var _hit_done := false
var _tick := 0.0
# x_strike
var _xc := Vector2.ZERO
var _x_boomed := false
# focus_ring
var _fc := Vector2.ZERO
var _f_alive := 0
var _shock_r := -1.0
var _shock_dmg := 0
var _shock_hit := false
var _fizzled := false
# annihilate
var _a_from := 0.0
var _a_to := 0.0
var _covers: Array = []      # [貼圖, 目前位置, 目標位置, 自轉]
var _tint := 0.0
var _hole := 0.0

var _floor: Layer
var _beam: Layer
var _cover: Layer
var _holel: Layer
var _hi: Layer


static func handles(k: StringName) -> bool:
	return k in KINDS


func setup(u: BossUltimate) -> void:
	ult = u
	boss = u.boss
	bd = u.bd


func _ready() -> void:
	_floor = _make_layer(-4, false)
	_beam = _make_layer(1, true)
	_beam.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_cover = _make_layer(2, false)
	_holel = _make_layer(4, false)
	_hi = _make_layer(5, true)


func _make_layer(z: int, additive: bool) -> Layer:
	var l := Layer.new()
	l.u = self
	l.z_index = z
	l.z_as_relative = false
	l.top_level = true
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		l.material = mat
	add_child(l)
	return l


func can_use(k: StringName) -> bool:
	if k == &"focus_ring":
		return boss.float_rig != null and boss.float_rig.alive_count() > 0
	return true


func _vp() -> Vector2:
	return boss.get_viewport_rect().size


func _player_pos() -> Vector2:
	var pl := Player.instance
	if pl and pl.alive:
		return pl.global_position
	return _vp() * Vector2(0.5, 0.75)


func core_pos() -> Vector2:
	return boss.global_position + bd.weak_offset


# ======================================================================
# 流程
# ======================================================================

func start_charge(k: StringName) -> float:
	kind = k
	charging = true
	_done = false
	_t = 0.0
	match k:
		&"x_strike":
			var s := _vp()
			var p := _player_pos()
			_xc = Vector2(clampf(p.x, s.x * 0.36, s.x * 0.64), clampf(p.y, s.y * 0.5, s.y * 0.76))
			return X_CHARGE
		&"focus_ring":
			var s := _vp()
			_fc = Vector2(clampf(_player_pos().x, 240.0, s.x - 240.0), s.y * 0.6)
			_set_ring_targets(0.0)
			boss.float_rig.face_point = _fc
			return FOCUS_CHARGE
		&"annihilate":
			_spawn_covers()
			return ANNI_CHARGE
	return 1.0


func update_charge(delta: float) -> void:
	_t += delta
	_gt += delta
	match kind:
		&"focus_ring":
			_set_ring_targets(_t * 0.4)
		&"annihilate":
			_hole = clampf(_t / ANNI_CHARGE, 0.0, 1.0)
			_tint = move_toward(_tint, 1.0, delta / ANNI_CHARGE)
			_update_covers(delta, true)
	_redraw()


func start_fire() -> float:
	charging = false
	_t = 0.0
	_hit_done = false
	_tick = 0.0
	match kind:
		&"x_strike":
			_x_boomed = false
			Events.screen_shake.emit(10.0, 0.3)
		&"focus_ring":
			_f_alive = boss.float_rig.alive_count()
			_shock_r = -1.0
			_shock_hit = false
			_fizzled = false
		&"annihilate":
			var dir := 1.0 if randf() < 0.5 else -1.0
			var half := deg_to_rad(bd.ult_annihilate_sweep_deg) * 0.5
			_a_from = PI / 2.0 - half * dir
			_a_to = PI / 2.0 + half * dir
			Events.screen_shake.emit(16.0, 0.6)
	return 60.0   # 由 is_done() 決定何時結束


func update_fire(delta: float) -> void:
	_t += delta
	_gt += delta
	match kind:
		&"x_strike":
			_update_x(delta)
		&"focus_ring":
			_update_focus(delta)
		&"annihilate":
			_update_annihilate(delta)
	_redraw()


func is_done() -> bool:
	return _done


func cancel() -> void:
	_done = true
	charging = false
	kind = &""
	_covers.clear()
	_tint = 0.0
	_hole = 0.0
	_shock_r = -1.0
	if boss and boss.float_rig:
		boss.float_rig.override_targets.clear()
		boss.float_rig.face_point = Vector2.INF
	_redraw()


## 絕招結束後的餘韻（地板紅色、隕石離場）在閒置時繼續
func idle_update(delta: float) -> void:
	_gt += delta
	var dirty := false
	if _tint > 0.0 and kind != &"annihilate":
		_tint = move_toward(_tint, 0.0, delta * 1.2)
		dirty = true
	if _hole > 0.0 and kind != &"annihilate":
		_hole = move_toward(_hole, 0.0, delta * 2.0)
		dirty = true
	if not _covers.is_empty() and kind != &"annihilate":
		_update_covers(delta, false)
		dirty = true
	if dirty:
		_redraw()


func _redraw() -> void:
	_floor.queue_redraw()
	_beam.queue_redraw()
	_cover.queue_redraw()
	_holel.queue_redraw()
	_hi.queue_redraw()


# ======================================================================
# x_strike
# ======================================================================

func _on_x(p: Vector2, extra: float) -> bool:
	var rel := p - _xc
	if rel.length() > bd.ult_x_size * 0.47:
		return false
	var hw := bd.ult_x_size * 0.075 + extra
	var d1 := Vector2(1, 1).normalized()
	var d2 := Vector2(1, -1).normalized()
	return absf(rel.cross(d1)) < hw or absf(rel.cross(d2)) < hw


func _update_x(delta: float) -> void:
	var pl := Player.instance
	var on_floor := _t >= X_CONVERGE and _t < X_CONVERGE + X_BURN + X_FADE * 0.5
	if on_floor and pl and pl.alive:
		_tick -= delta
		if _tick <= 0.0 and _on_x(pl.global_position, pl.ship.hitbox_radius):
			_tick = X_TICK
			pl.take_hit(1)
	if not _x_boomed and _t >= X_CONVERGE + X_BURN:
		_x_boomed = true
		_x_detonate()
	if _t >= X_CONVERGE + X_BURN + X_FADE:
		_done = true


func _x_detonate() -> void:
	var L := bd.ult_x_size * 0.42
	var parent := boss.get_parent()
	if NeonFx.instance:
		for d: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			for k: float in [0.3, 0.65, 1.0]:
				NeonFx.instance.explode(_xc + d.normalized() * L * k, 1.6)
		NeonFx.instance.explode(_xc, 2.6)
		NeonFx.instance.ring(_xc, 30.0, bd.ult_x_size * 0.6, 0.5, bd.ult_color, 8.0)
	Events.screen_shake.emit(18.0, 0.6)
	var pl := Player.instance
	if pl and pl.alive and _on_x(pl.global_position, pl.ship.hitbox_radius + 10.0):
		pl.take_hit(bd.ult_damage)
	# 岩漿蔓延：四個端點＋中心留下岩漿坑
	if bd.ult_pit_texture:
		LavaPit.spawn(parent, _xc, bd.ult_pit_texture, 170.0)
		for d: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			LavaPit.spawn(parent, _xc + d.normalized() * L * 0.9, bd.ult_pit_texture, 120.0)


## 十個砲口各自對準 X 上的一個點
func _x_target(i: int) -> Vector2:
	var L := bd.ult_x_size * 0.42
	var dirs := [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]
	var fr := [1.0, 0.55, 0.2]
	var n := maxi(bd.ult_feather_points.size(), 1)
	var p := bd.ult_feather_points[i] if i < bd.ult_feather_points.size() else Vector2.ZERO
	# 左邊砲口打 X 左半邊、右邊砲口打右半邊
	var side := 0 if p.x < 0.0 else 2
	var d: Vector2 = dirs[side + (i % 2)]
	return _xc + d.normalized() * L * float(fr[(i >> 1) % 3]) * (0.9 + 0.1 * float(i) / n)


# ======================================================================
# focus_ring
# ======================================================================

func _set_ring_targets(spin: float) -> void:
	var rig := boss.float_rig
	if rig == null:
		return
	var t: Array[Vector2] = []
	var n := rig.drones.size()
	for i in n:
		t.append(_fc + Vector2.RIGHT.rotated(TAU * i / maxf(n, 1.0) - PI / 2.0 + spin) * bd.ult_focus_radius)
	rig.override_targets = t
	rig.face_point = _fc


func _orb_size() -> float:
	if _fizzled:
		return 0.0
	var k := clampf(_t / FOCUS_GROW, 0.0, 1.0)
	return lerpf(40.0, 300.0, ease(k, 0.6)) * (0.4 + 0.6 * float(_f_alive) / 6.0)


func _update_focus(delta: float) -> void:
	var rig := boss.float_rig
	if _shock_r < 0.0:
		_set_ring_targets(0.52 + _t * 0.25)
		_f_alive = rig.alive_count() if rig else 0
		if _f_alive == 0 and not _fizzled:
			# 浮游砲全滅：紅光球潰散
			_fizzled = true
			if NeonFx.instance:
				NeonFx.instance.ring(_fc, 20.0, 160.0, 0.4, bd.ult_color, 4.0)
				NeonFx.instance.float_text(_fc + Vector2(0, -60), "FOCUS BROKEN!", Color(1.0, 0.85, 0.5))
			_end_focus()
			_done = true
			return
		if fmod(_gt, 0.25) < delta:
			Events.screen_shake.emit(2.0 + 4.0 * _t / FOCUS_GROW, 0.15)
		if _t >= FOCUS_GROW:
			# 炸開：全場衝擊波，傷害依剩下的浮游砲數量
			_shock_r = 0.0
			_shock_dmg = maxi(1, int(ceil(bd.ult_damage * _f_alive / 6.0)))
			_end_focus()
			Events.screen_shake.emit(22.0, 0.7)
			if NeonFx.instance:
				if bd.ult_orb_texture:
					NeonFx.instance.burst(_fc, bd.ult_orb_texture, 520.0, 0.6)
				NeonFx.instance.explode(_fc, 4.0)
			if bd.ult_pit_texture:
				var s := _vp()
				LavaPit.spawn(boss.get_parent(), _fc, bd.ult_pit_texture, 190.0)
				for i in 5:
					var p := Vector2(randf_range(70.0, s.x - 70.0), randf_range(s.y * 0.4, s.y * 0.9))
					LavaPit.spawn(boss.get_parent(), p, bd.ult_pit_texture, randf_range(110.0, 150.0))
		return
	# 衝擊波往外擴散
	_shock_r += SHOCK_SPEED * delta
	var pl := Player.instance
	if not _shock_hit and pl and pl.alive and _shock_r >= pl.global_position.distance_to(_fc):
		_shock_hit = true
		pl.take_hit(_shock_dmg)
	if _shock_r > 1700.0:
		_shock_r = -1.0
		_done = true


func _end_focus() -> void:
	if boss.float_rig:
		boss.float_rig.override_targets.clear()
		boss.float_rig.face_point = Vector2.INF


# ======================================================================
# annihilate
# ======================================================================

func _spawn_covers() -> void:
	_covers.clear()
	if bd.ult_cover_textures.is_empty():
		return
	var s := _vp()
	var xs := [0.2, 0.5, 0.8]
	xs.shuffle()
	for i in 3:
		var to := Vector2(s.x * float(xs[i]) + randf_range(-30.0, 30.0), s.y * randf_range(0.6, 0.7))
		var from := Vector2(to.x + randf_range(-60.0, 60.0), -100.0 - i * 60.0)
		_covers.append([bd.ult_cover_textures[i % bd.ult_cover_textures.size()], from, to, randf() * TAU])


func _update_covers(delta: float, arriving: bool) -> void:
	for c in _covers:
		var pos: Vector2 = c[1]
		if arriving:
			pos = pos.lerp(c[2] as Vector2, minf(1.0, 2.2 * delta))
		else:
			pos += Vector2(0, 260.0 * delta)
		c[1] = pos
		c[3] = float(c[3]) + delta * 0.4
	if not arriving:
		var h := _vp().y
		_covers = _covers.filter(func(c: Array) -> bool: return (c[1] as Vector2).y < h + 140.0)


func _anni_angle() -> float:
	var k := clampf(_t / bd.ult_annihilate_time, 0.0, 1.0)
	return lerp_angle(_a_from, _a_to, ease(k, -1.3))


func _anni_width() -> float:
	return bd.ult_annihilate_width * clampf(minf(_t / 0.25, (bd.ult_annihilate_time - _t) / 0.35), 0.0, 1.0)


## 玩家是否躲在某顆隕石後面（從核心看過去被隕石擋住）
func shadowed(p: Vector2) -> bool:
	var o := core_pos()
	for c in _covers:
		var cp: Vector2 = c[1]
		var to_c := cp - o
		var to_p := p - o
		if to_p.length() <= to_c.length():
			continue
		var half := asin(clampf(COVER_R / maxf(to_c.length(), COVER_R + 1.0), 0.0, 1.0))
		if absf(angle_difference(to_p.angle(), to_c.angle())) < half:
			return true
	return false


func _update_annihilate(delta: float) -> void:
	_hole = 1.0
	_tint = 1.0
	_update_covers(delta, true)
	if _t < bd.ult_annihilate_time:
		Events.screen_shake.emit(4.0, 0.1)
		var pl := Player.instance
		if not _hit_done and pl and pl.alive and _anni_width() > bd.ult_annihilate_width * 0.5:
			var o := core_pos()
			var dir := Vector2.RIGHT.rotated(_anni_angle())
			var rel := pl.global_position - o
			if rel.dot(dir) > 0.0 and absf(rel.cross(dir)) < _anni_width() * 0.42 + pl.ship.hitbox_radius and not shadowed(pl.global_position):
				_hit_done = true
				pl.take_hit(bd.ult_damage)
		return
	if _t >= bd.ult_annihilate_time + ANNI_AFTER:
		kind = &""    # 讓餘韻在閒置時淡出
		_done = true


# ======================================================================
# 繪製
# ======================================================================

func draw_layer(l: Layer) -> void:
	if l == _floor:
		_draw_floor(l)
	elif l == _beam:
		_draw_beam(l)
	elif l == _cover:
		_draw_cover(l)
	elif l == _holel:
		_draw_hole(l)
	elif l == _hi:
		_draw_hi(l)


func _draw_floor(l: Layer) -> void:
	if _tint > 0.0:
		var s := _vp()
		l.draw_rect(Rect2(Vector2(-40, -40), s + Vector2(80, 80)), Color(0.55, 0.0, 0.02, 0.32 * _tint))
	if kind != &"x_strike" or charging or _done:
		return
	if _t < X_CONVERGE or bd.ult_x_texture == null:
		return
	var k := _t - X_CONVERGE
	var a := clampf(k / 0.15, 0.0, 1.0) * clampf((X_BURN + X_FADE - k) / X_FADE, 0.0, 1.0)
	var ts := bd.ult_x_texture.get_size()
	var grow := lerpf(0.75, 1.0, ease(clampf(k / 0.2, 0.0, 1.0), 0.4))
	var sc := bd.ult_x_size * grow / maxf(ts.x, ts.y)
	# 引爆前越來越亮、閃爍
	var warn := clampf(k / X_BURN, 0.0, 1.0)
	var flash := 1.0 + (0.5 * warn * (0.5 + 0.5 * sin(_gt * (10.0 + 24.0 * warn))) if k < X_BURN else 0.0)
	l.draw_set_transform(_xc, 0.0, Vector2(sc, sc))
	l.draw_texture(bd.ult_x_texture, -ts * 0.5, Color(flash, flash * 0.9, flash * 0.9, a))
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_beam(l: Layer) -> void:
	if kind != &"annihilate" or charging or _t >= bd.ult_annihilate_time:
		return
	var w := _anni_width()
	if w <= 1.0:
		return
	var o := core_pos()
	var c := bd.ult_color
	var flick := 0.92 + 0.08 * sin(_gt * 60.0)
	var blen := 2600.0
	l.draw_set_transform(o, _anni_angle() - PI / 2.0, Vector2.ONE)
	l.draw_rect(Rect2(-w * 0.75, 0, w * 1.5, blen), Color(c.r, c.g, c.b, 0.22 * flick))
	l.draw_rect(Rect2(-w * 0.5, 0, w, blen), Color(c.r, c.g * 0.6, c.b * 0.6, 0.55 * flick))
	if bd.ult_beam_texture:
		var tw := bd.ult_beam_texture.get_size()
		var sc := w / tw.x
		l.draw_set_transform(o, _anni_angle() - PI / 2.0, Vector2(sc, sc))
		var off := fmod(_gt * 1100.0 / sc, tw.y)
		l.draw_texture_rect(bd.ult_beam_texture, Rect2(-tw.x * 0.5, -off, tw.x, blen / sc + tw.y), true, Color(1, 1, 1, 0.95))
		l.draw_set_transform(o, _anni_angle() - PI / 2.0, Vector2.ONE)
	l.draw_rect(Rect2(-w * 0.12, 0, w * 0.24, blen), Color(1, 0.85, 0.8, 0.8))
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cover(l: Layer) -> void:
	if _covers.is_empty():
		return
	var o := core_pos()
	var beam_on := kind == &"annihilate"
	for c in _covers:
		var cp: Vector2 = c[1]
		if beam_on:
			# 隕石後面的陰影（安全區）
			var to_c := cp - o
			var dist := maxf(to_c.length(), COVER_R + 1.0)
			var half := asin(clampf(COVER_R / dist, 0.0, 1.0))
			var a := to_c.angle()
			var perp := to_c.normalized().orthogonal() * COVER_R
			var p1 := cp + perp
			var p2 := cp - perp
			# 兩個切點依角度排好，避免多邊形交叉
			if angle_difference(a, (p1 - o).angle()) < 0.0:
				var tmp := p1
				p1 = p2
				p2 = tmp
			var pts := PackedVector2Array([p1, o + Vector2.RIGHT.rotated(a + half) * 2600.0,
					o + Vector2.RIGHT.rotated(a - half) * 2600.0, p2])
			l.draw_colored_polygon(pts, Color(0.0, 0.0, 0.02, 0.55 * minf(_tint, 1.0)))
	for c in _covers:
		var tex: Texture2D = c[0]
		var ts := tex.get_size()
		var sc := COVER_R * 2.3 / maxf(ts.x, ts.y)
		l.draw_set_transform(c[1] as Vector2, float(c[3]), Vector2(sc, sc))
		l.draw_texture(tex, -ts * 0.5, Color(0.9, 0.8, 0.75))
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hole(l: Layer) -> void:
	if _hole <= 0.01 or bd.ult_hole_texture == null:
		return
	var ts := bd.ult_hole_texture.get_size()
	var size := 250.0 * ease(_hole, 0.5) * (1.0 + 0.05 * sin(_gt * 9.0))
	var sc := size / maxf(ts.x, ts.y)
	l.draw_set_transform(core_pos(), -_gt * 2.4, Vector2(sc, sc))
	l.draw_texture(bd.ult_hole_texture, -ts * 0.5, Color(1, 1, 1, clampf(_hole * 1.5, 0.0, 1.0)))
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hi(l: Layer) -> void:
	var c := bd.ult_color
	match kind:
		&"x_strike":
			if not charging and not _done and _t >= X_CONVERGE:
				# 地面 X 的紅光（加亮，脈動；引爆前越來越亮）
				var k := _t - X_CONVERGE
				var a := clampf(k / 0.15, 0.0, 1.0) * clampf((X_BURN + X_FADE - k) / X_FADE, 0.0, 1.0)
				var warn := clampf(k / X_BURN, 0.0, 1.0)
				var pulse := 0.5 + 0.5 * sin(_gt * (8.0 + 22.0 * warn))
				var L := bd.ult_x_size * 0.44
				var hw := bd.ult_x_size * 0.075
				for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
					var dn := d.normalized()
					l.draw_line(_xc - dn * L, _xc + dn * L, Color(c.r, c.g, c.b, (0.18 + 0.22 * pulse * warn) * a), hw * 2.6)
					l.draw_line(_xc - dn * L, _xc + dn * L, Color(1.0, 0.45, 0.3, (0.25 + 0.35 * pulse) * a), hw * 0.7)
			if charging:
				# 全砲口聚能發紅光＋地面 X 預警線
				var k := clampf(_t / X_CHARGE, 0.0, 1.0)
				var blink := 0.5 + 0.5 * sin(_gt * (10.0 + 20.0 * k))
				for p in bd.ult_feather_points:
					var at := boss.global_position + p
					l.draw_circle(at, 10.0 + 20.0 * k, Color(c.r, c.g, c.b, 0.35 + 0.3 * blink))
					l.draw_circle(at, 4.0 + 8.0 * k, Color(1, 0.85, 0.8, 0.9))
				var L := bd.ult_x_size * 0.45
				for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
					var dn := d.normalized()
					l.draw_line(_xc - dn * L, _xc + dn * L, Color(c.r, c.g, c.b, 0.2 + 0.5 * blink * k), 3.0 + 8.0 * k)
			elif not _done and _t < X_CONVERGE + 0.25:
				# 十道紅光砲射向地面交織成 X
				var k := clampf(_t / X_CONVERGE, 0.0, 1.0)
				var fade := clampf((X_CONVERGE + 0.25 - _t) / 0.25, 0.0, 1.0)
				for i in bd.ult_feather_points.size():
					var from := boss.global_position + bd.ult_feather_points[i]
					var to := from.lerp(_x_target(i), ease(k, 0.5))
					l.draw_line(from, to, Color(c.r, c.g, c.b, 0.35 * fade), 22.0)
					l.draw_line(from, to, Color(1, 0.7, 0.6, 0.9 * fade), 6.0)
					l.draw_circle(to, 16.0, Color(c.r, c.g, c.b, 0.6 * fade))
		&"focus_ring":
			_draw_focus(l, c)
		&"annihilate":
			if charging:
				# 能量被吸進黑洞
				var o := core_pos()
				var k := clampf(_t / ANNI_CHARGE, 0.0, 1.0)
				for i in 18:
					var a := TAU * i / 18.0 + _gt * 1.5
					var r := fmod(260.0 - _gt * 300.0 + i * 37.0, 260.0) + 40.0
					var p := o + Vector2.RIGHT.rotated(a) * r
					l.draw_line(p, p + (o - p).normalized() * 22.0, Color(c.r, c.g, c.b, 0.7 * k), 3.0)
				# 光柱會掃過的範圍
				var half := deg_to_rad(bd.ult_annihilate_sweep_deg) * 0.5 + 0.2
				var far := 2400.0
				l.draw_colored_polygon(PackedVector2Array([o, o + Vector2.RIGHT.rotated(PI / 2.0 - half) * far, o + Vector2.RIGHT.rotated(PI / 2.0 + half) * far]),
						Color(c.r, c.g, c.b, 0.03 + 0.05 * k))


func _draw_focus(l: Layer, c: Color) -> void:
	var rig := boss.float_rig
	var gold := Color(1.0, 0.82, 0.45)
	if _shock_r >= 0.0:
		var a := clampf(1.0 - _shock_r / 1700.0, 0.0, 1.0)
		l.draw_arc(_fc, _shock_r, 0, TAU, 96, Color(c.r, c.g, c.b, 0.35 * a), 60.0)
		l.draw_arc(_fc, _shock_r, 0, TAU, 96, Color(1, 0.8, 0.7, 0.8 * a), 12.0)
		return
	if _done:
		return
	# 符文圓環
	var k := clampf(_t / FOCUS_CHARGE, 0.0, 1.0) if charging else 1.0
	var R := bd.ult_focus_radius
	l.draw_arc(_fc, R * 1.15, _gt * 0.3, _gt * 0.3 + TAU, 72, Color(gold.r, gold.g, gold.b, 0.35 * k), 2.5)
	l.draw_arc(_fc, R * 0.8, -_gt * 0.5, -_gt * 0.5 + TAU, 64, Color(gold.r, gold.g, gold.b, 0.25 * k), 2.0)
	for i in 12:
		var a := TAU * i / 12.0 + _gt * 0.3
		l.draw_line(_fc + Vector2.RIGHT.rotated(a) * R * 1.08, _fc + Vector2.RIGHT.rotated(a) * R * 1.22, Color(gold.r, gold.g, gold.b, 0.4 * k), 2.0)
	if charging or rig == null:
		return
	# 六道雷射聚焦到中間
	var flick := 0.85 + 0.15 * sin(_gt * 70.0)
	for i in rig.drones.size():
		var p := rig.drone_pos(i)
		if p == Vector2.INF:
			continue
		l.draw_line(p, _fc, Color(c.r, c.g, c.b, 0.3), 18.0 * flick)
		l.draw_line(p, _fc, Color(1, 0.75, 0.7, 0.9), 5.0)
	# 超巨型紅光球
	var sz := _orb_size()
	if bd.ult_orb_texture and sz > 1.0:
		var ts := bd.ult_orb_texture.get_size()
		var sc := sz * (1.0 + 0.04 * sin(_gt * 20.0)) / maxf(ts.x, ts.y)
		l.draw_set_transform(_fc, _gt * 1.5, Vector2(sc, sc))
		l.draw_texture(bd.ult_orb_texture, -ts * 0.5)
		l.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	l.draw_circle(_fc, sz * 0.12, Color(1, 0.9, 0.85, 0.9))


class Layer extends Node2D:
	var u: BlackGoldUlt

	func _draw() -> void:
		if u and u.bd:
			u.draw_layer(self)
