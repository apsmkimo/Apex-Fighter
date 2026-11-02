extends Control
## 星圖選關畫面（STAR MAP）
## 由下往上的航線：每一關是一個「星區節點」，旁邊用全息框顯示該關的最終 Boss。
## 已解鎖的航段有流動的能量脈衝；未解鎖的節點是暗色加鎖。上下拖曳捲動，點節點出擊。
## 全部用程式繪製（霓虹科技風），沒有用到任何外部圖。

const MAP_H := 2450.0
const SLOT_COUNT := 6
const NODE_R := 46.0
const STEP_Y := 340.0
const BOTTOM_PAD := 470.0
const TAP_SLOP := 18.0

const SECTOR_NAMES := ["NEBULA GATE", "CRIMSON RIFT", "VOID ABYSS", "SOLAR FORGE", "IRON HALO", "OMEGA CORE"]
const SECTOR_COLORS := [
	Color(0.3, 0.9, 1.0), Color(1.0, 0.3, 0.35), Color(0.7, 0.35, 1.0),
	Color(1.0, 0.7, 0.25), Color(0.5, 1.0, 0.6), Color(1.0, 0.35, 0.85)]

var _scroll := 0.0
var _t := 0.0
var _drag_from := Vector2.ZERO
var _drag_scroll := 0.0
var _dragging := false
var _moved := false
var _stars: Array = []       # [Vector2 map 座標, 大小, 閃爍相位]
var _nodes: Array[Vector2] = []
var _path: PackedVector2Array = PackedVector2Array()
var _path_seg_start: PackedInt32Array = PackedInt32Array()   # 每個節點在 _path 裡的起點索引
var _back: Button


func _ready() -> void:
	Events.music_requested.emit(&"ship_select")
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 2077
	for i in 260:
		_stars.append([Vector2(rng.randf() * 720.0, rng.randf() * MAP_H), rng.randf_range(0.6, 2.2), rng.randf() * TAU])
	_build_layout()
	_back = UiKit.button("BACK", 30, Vector2(200, 76))
	_back.pressed.connect(GameManager.goto_ship_select)
	add_child(_back)
	resized.connect(_place_ui)
	_place_ui()
	# 一進來就把「下一關」捲到畫面中下方
	_scroll = clampf(_node_map(_current_index()).y - size.y * 0.62, 0.0, maxf(MAP_H - size.y, 0.0))


func _place_ui() -> void:
	_back.position = Vector2(24, size.y - 100)


func _build_layout() -> void:
	_nodes.clear()
	for i in SLOT_COUNT:
		# 左右交錯，再加一點固定的錯位，讓航線不像棋盤
		var x := 230.0 if i % 2 == 0 else 490.0
		x += [0.0, 20.0, -30.0, 10.0, -15.0, 25.0][i]
		_nodes.append(Vector2(x, MAP_H - BOTTOM_PAD - i * STEP_Y))
	# 用 Catmull-Rom 把節點串成平滑航線
	_path = PackedVector2Array()
	_path_seg_start = PackedInt32Array()
	var pts: Array[Vector2] = [_nodes[0] + Vector2(0, 260)]
	pts.append_array(_nodes)
	pts.append(_nodes[-1] + Vector2(0, -260))
	for i in range(1, pts.size() - 2):
		_path_seg_start.append(_path.size())
		for s in 24:
			var k := s / 24.0
			_path.append(_catmull(pts[i - 1], pts[i], pts[i + 1], pts[i + 2], k))
	_path.append(pts[-2])


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _stage_count() -> int:
	return mini(Database.stages.size(), SLOT_COUNT)


## 可以出擊的最高關（已過關數，最多到最後一關）
func _current_index() -> int:
	return clampi(GameManager.cleared_stages, 0, maxi(_stage_count() - 1, 0))


func _is_unlocked(i: int) -> bool:
	return i < _stage_count() and i <= GameManager.cleared_stages


func _node_map(i: int) -> Vector2:
	return _nodes[clampi(i, 0, _nodes.size() - 1)]


func _to_screen(p: Vector2) -> Vector2:
	return Vector2(p.x * size.x / 720.0, p.y - _scroll)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# ---------------------------------------------------------------- 輸入

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_dragging = true
			_moved = false
			_drag_from = mb.position
			_drag_scroll = _scroll
		else:
			_dragging = false
			if not _moved:
				_tap(mb.position)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var dy := mm.position.y - _drag_from.y
		if absf(dy) > TAP_SLOP:
			_moved = true
		if _moved:
			_scroll = clampf(_drag_scroll - dy, 0.0, maxf(MAP_H - size.y, 0.0))


func _tap(pos: Vector2) -> void:
	for i in _stage_count():
		var c := _to_screen(_node_map(i))
		if pos.distance_to(c) < NODE_R + 30.0 or _boss_rect(i).has_point(pos):
			if _is_unlocked(i):
				_launch(i)
			else:
				if NeonFx.instance:
					NeonFx.instance.float_text(c, "LOCKED", NeonDraw.RED)
			return


func _launch(i: int) -> void:
	var ship := GameManager.selected_ship
	if ship == null and not Database.ships.is_empty():
		ship = Database.ships[0]
	GameManager.start_run(ship, Database.stages[i])
	GameManager.goto_stage()


func _boss_rect(i: int) -> Rect2:
	var c := _to_screen(_node_map(i))
	var side := 1.0 if c.x < size.x * 0.5 else -1.0
	var center := c + Vector2(side * 200.0 * size.x / 720.0, -30.0)
	return Rect2(center - Vector2(95, 80), Vector2(190, 160))


# ---------------------------------------------------------------- 繪製

func _draw() -> void:
	_draw_space()
	_draw_home_planet()
	_draw_path()
	for i in SLOT_COUNT:
		_draw_boss_card(i)
	for i in SLOT_COUNT:
		_draw_node(i)
	_draw_top_bar()


func _draw_space() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.02, 0.06))
	# 每個星區一團星雲，顏色跟關卡主題一致
	for i in SLOT_COUNT:
		var c := _to_screen(_node_map(i) + Vector2(i % 2 * -120.0 + 60.0, -60))
		if c.y < -500 or c.y > size.y + 500:
			continue
		var col: Color = SECTOR_COLORS[i]
		for k in 6:
			var r := 380.0 - k * 55.0
			draw_circle(c + Vector2(sin(k * 1.7) * 40.0, cos(k * 2.3) * 30.0), r, Color(col.r * 0.6, col.g * 0.4, col.b * 0.8, 0.025))
	# 星星
	for s in _stars:
		var p := _to_screen(s[0] as Vector2)
		if p.y < -4 or p.y > size.y + 4:
			continue
		var tw := 0.55 + 0.45 * sin(_t * 2.0 + (s[2] as float))
		draw_circle(p, s[1] as float, Color(0.8, 0.9, 1.0, 0.35 + 0.5 * tw))
	# 淡淡的經緯網格，增加「導航圖」的感覺
	var grid := Color(0.3, 0.6, 1.0, 0.05)
	var off := fmod(_scroll, 80.0)
	for y in range(0, int(size.y) + 80, 80):
		draw_line(Vector2(0, y - off), Vector2(size.x, y - off), grid, 1.0)
	for x in range(0, int(size.x) + 80, 80):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid, 1.0)


## 起點的母星：線框行星（經緯線）＋外環
func _draw_home_planet() -> void:
	var c := _to_screen(Vector2(360, MAP_H + 120))
	if c.y - 420 > size.y:
		return
	var r := 420.0
	draw_circle(c, r + 30.0, Color(0.2, 0.6, 1.0, 0.06))
	draw_circle(c, r, Color(0.03, 0.08, 0.18, 1.0))
	var col := Color(0.3, 0.85, 1.0, 0.35)
	for k in range(1, 7):
		var ry := r * k / 7.0
		draw_arc(c, ry, PI, TAU, 64, Color(col.r, col.g, col.b, 0.12), 1.5)
	for k in range(-4, 5):
		var w := r * cos(k * 0.3)
		var y := c.y - r * sin(absf(k) * 0.3 + 0.15)
		draw_line(Vector2(c.x - w, y), Vector2(c.x + w, y), Color(col.r, col.g, col.b, 0.15), 1.5)
	draw_arc(c, r, PI, TAU, 96, Color(0.4, 0.9, 1.0, 0.9), 3.0)
	draw_arc(c, r + 10.0, PI * 1.05, PI * 1.95, 96, Color(0.4, 0.9, 1.0, 0.25), 8.0)
	NeonDraw.text(self, c + Vector2(-r, -r + 120), "HOME BASE", 22, NeonDraw.CYAN, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)


func _draw_path() -> void:
	var scaled := PackedVector2Array()
	for p in _path:
		scaled.append(_to_screen(p))
	# 已解鎖航段的終點索引
	var lit_end := _path_seg_start[mini(_current_index(), _path_seg_start.size() - 1)] if _current_index() > 0 else 0
	lit_end = mini(lit_end, scaled.size() - 1)
	# 先畫整條暗色虛線
	for i in range(0, scaled.size() - 1, 2):
		draw_line(scaled[i], scaled[i + 1], Color(0.5, 0.55, 0.7, 0.28), 3.0)
	# 已解鎖的部分：亮青色＋流動的光點
	if lit_end > 0:
		var lit := scaled.slice(0, lit_end + 1)
		draw_polyline(lit, Color(0.3, 0.9, 1.0, 0.18), 12.0, true)
		draw_polyline(lit, Color(0.4, 0.95, 1.0, 0.8), 3.0, true)
		var n := lit.size()
		for k in 6:
			var f := fmod(_t * 0.25 + k / 6.0, 1.0)
			var p := lit[int(f * (n - 1))]
			draw_circle(p, 7.0, Color(0.5, 1.0, 1.0, 0.35))
			draw_circle(p, 3.5, Color(1, 1, 1, 0.95))
	# 從起點母星拉到第一關的那段
	var first := _to_screen(_node_map(0))
	var base := _to_screen(Vector2(_node_map(0).x, MAP_H - 120))
	draw_line(base, first, Color(0.4, 0.95, 1.0, 0.6), 3.0)


func _draw_node(i: int) -> void:
	var c := _to_screen(_node_map(i))
	if c.y < -150 or c.y > size.y + 150:
		return
	var exists := i < _stage_count()
	var unlocked := _is_unlocked(i)
	var cleared := i < GameManager.cleared_stages
	var current := unlocked and i == _current_index() and not cleared
	var col: Color = SECTOR_COLORS[i] if unlocked else Color(0.45, 0.5, 0.6)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	# 外圈：兩段反向旋轉的弧
	var rr := NODE_R + 14.0
	for k in 3:
		var a := _t * (1.2 if unlocked else 0.3) + TAU * k / 3.0
		draw_arc(c, rr, a, a + 1.4, 16, Color(col.r, col.g, col.b, 0.75 if unlocked else 0.3), 3.0)
	for k in 4:
		var a := -_t * 0.7 + TAU * k / 4.0
		draw_arc(c, rr + 9.0, a, a + 0.5, 8, Color(col.r, col.g, col.b, 0.35 if unlocked else 0.15), 2.0)
	if current:
		draw_circle(c, NODE_R + 26.0 + pulse * 10.0, Color(col.r, col.g, col.b, 0.08 + 0.08 * pulse))
	# 本體：八角形（不用六角形），內部漸層
	var body := PackedVector2Array()
	for k in 8:
		body.append(c + Vector2.RIGHT.rotated(TAU * k / 8.0 + PI / 8.0) * NODE_R)
	draw_colored_polygon(body, Color(0.03, 0.05, 0.12, 0.95))
	var inner := PackedVector2Array()
	for k in 8:
		inner.append(c + Vector2.RIGHT.rotated(TAU * k / 8.0 + PI / 8.0) * (NODE_R - 8.0))
	draw_colored_polygon(inner, Color(col.r * 0.35, col.g * 0.35, col.b * 0.45, 0.9 if unlocked else 0.5))
	var loop := body.duplicate()
	loop.append(body[0])
	draw_polyline(loop, Color(col.r, col.g, col.b, 0.25), 8.0, true)
	draw_polyline(loop, col, 2.5, true)
	if unlocked:
		NeonDraw.text(self, c + Vector2(-60, 13), "%02d" % (i + 1), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	else:
		_draw_lock(c, col)
	# 名稱
	var name := "STAGE %d" % (i + 1)
	NeonDraw.text(self, c + Vector2(-110, NODE_R + 44), name, 22, col if unlocked else Color(0.6, 0.65, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 220.0)
	NeonDraw.text(self, c + Vector2(-110, NODE_R + 68), SECTOR_NAMES[i] if exists else "COMING SOON", 16,
			Color(0.75, 0.82, 0.95, 0.85 if unlocked else 0.5), HORIZONTAL_ALIGNMENT_CENTER, 220.0, false)
	if cleared:
		_draw_check(c + Vector2(NODE_R * 0.75, -NODE_R * 0.75))
	if current:
		# 上方上下跳動的雙箭頭＋ LAUNCH
		var bob := sin(_t * 5.0) * 6.0
		var top := c + Vector2(0, -NODE_R - 40 + bob)
		for k in 2:
			var y := top.y + k * 14.0
			draw_colored_polygon(PackedVector2Array([Vector2(top.x - 18, y - 10), Vector2(top.x + 18, y - 10), Vector2(top.x, y + 6)]),
					Color(NeonDraw.AMBER.r, NeonDraw.AMBER.g, NeonDraw.AMBER.b, 0.6 + 0.4 * pulse))
		NeonDraw.text(self, top + Vector2(-80, -22), "TAP TO LAUNCH", 16, NeonDraw.AMBER, HORIZONTAL_ALIGNMENT_CENTER, 160.0)


func _draw_lock(c: Vector2, col: Color) -> void:
	var lc := Color(col.r, col.g, col.b, 0.85)
	draw_arc(c + Vector2(0, -6), 11.0, PI, TAU, 16, lc, 4.0)
	draw_line(c + Vector2(-11, -6), c + Vector2(-11, 2), lc, 4.0)
	draw_line(c + Vector2(11, -6), c + Vector2(11, 2), lc, 4.0)
	draw_rect(Rect2(c + Vector2(-16, 0), Vector2(32, 22)), lc)
	draw_circle(c + Vector2(0, 10), 3.5, Color(0.03, 0.05, 0.12))


func _draw_check(c: Vector2) -> void:
	draw_circle(c, 15.0, Color(0.05, 0.25, 0.12, 0.95))
	draw_arc(c, 15.0, 0, TAU, 20, NeonDraw.GREEN, 2.0)
	draw_polyline(PackedVector2Array([c + Vector2(-7, 0), c + Vector2(-2, 6), c + Vector2(8, -6)]), NeonDraw.GREEN, 3.0)


## 節點旁邊的全息 Boss 卡：已解鎖顯示原色，未解鎖只剩掃描線的暗色剪影
func _draw_boss_card(i: int) -> void:
	if i >= _stage_count():
		return
	var st: StageData = Database.stages[i]
	if st.boss == null or st.boss.texture == null:
		return
	var r := _boss_rect(i)
	if r.position.y > size.y + 50 or r.end.y < -50:
		return
	var unlocked := _is_unlocked(i)
	var col: Color = SECTOR_COLORS[i] if unlocked else Color(0.45, 0.5, 0.6)
	NeonDraw.panel(self, r, col, 16.0)
	var tex := st.boss.texture
	var ts := tex.get_size()
	var s := minf((r.size.x - 20.0) / ts.x, (r.size.y - 44.0) / ts.y)
	var dst := Rect2(r.get_center() - ts * s * 0.5 + Vector2(0, -10), ts * s)
	var bob := sin(_t * 1.6 + i) * 3.0
	dst.position.y += bob
	if unlocked:
		draw_texture_rect(tex, dst, false)
	else:
		draw_texture_rect(tex, dst, false, Color(0.08, 0.1, 0.16, 0.95))
		draw_texture_rect(tex, dst.grow(2.0), false, Color(col.r, col.g, col.b, 0.12))
	# 全息掃描線
	var sy := r.position.y + fmod(_t * 60.0, r.size.y)
	draw_line(Vector2(r.position.x + 4, sy), Vector2(r.end.x - 4, sy), Color(col.r, col.g, col.b, 0.35), 2.0)
	var label := st.boss.boss_name if unlocked else "? ? ?"
	NeonDraw.text(self, Vector2(r.position.x, r.end.y - 10), label, 15, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, false)


func _draw_top_bar() -> void:
	var r := Rect2(Vector2(16, 16), Vector2(size.x - 32, 92))
	NeonDraw.panel(self, r, NeonDraw.CYAN)
	NeonDraw.text(self, r.position + Vector2(20, 44), "STAR MAP", 34, NeonDraw.CYAN)
	var ship_name := GameManager.selected_ship.display_name if GameManager.selected_ship else ""
	NeonDraw.text(self, r.position + Vector2(22, 76), ship_name, 18, Color(0.8, 0.9, 1.0), HORIZONTAL_ALIGNMENT_LEFT, -1.0, false)
	NeonDraw.text(self, r.position + Vector2(0, 42), "HI SCORE", 16, NeonDraw.AMBER, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20.0, false)
	NeonDraw.text(self, r.position + Vector2(0, 74), str(GameManager.hi_score), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20.0)
	var prog := "SECTORS %d / %d" % [mini(GameManager.cleared_stages, _stage_count()), _stage_count()]
	NeonDraw.text(self, r.position + Vector2(0, 76), prog, 16, NeonDraw.GREEN, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameManager.goto_ship_select()
