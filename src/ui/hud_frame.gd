class_name HudFrame
extends Control
## 科幻 HUD 外框（程式繪製）：四邊框線、左上系統資訊、右上 PILOT、左右小儀表、下方雷達與狀態列。
## 鋪滿整個螢幕；左右元件貼齊螢幕邊緣，上下位置對齊設計畫布（720x1280），
## 這樣在長螢幕上不會被裁掉。

const DESIGN := Vector2(720, 1280)
const CYAN := Color(0.4, 0.82, 1.0)
const DIM := Color(0.4, 0.82, 1.0, 0.45)
const TEXT := Color(0.8, 0.9, 1.0, 0.9)

## 對齊用的設計畫布
var canvas: Control
var subtitle := "AF//SHIP SELECT V2.3"
var pilot := "ACE-07"
var ship_class := "A"
var sector := "ORBITAL SECTOR  ·  7"
## 右上角 X 按下時
signal close_pressed

var _t := 0.0
var _close: Button
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	_close = Button.new()
	_close.flat = true
	_close.focus_mode = Control.FOCUS_NONE
	_close.draw.connect(_draw_close)
	# SMCPKG_SUPPORT>>>CursorM9UiClose
	# _close.pressed.connect(func(): close_pressed.emit())
	_close.pressed.connect(func() -> void:
		Events.ui_pressed.emit()
		close_pressed.emit()
	)
	# SMCPKG_SUPPORT<<<CursorM9UiCloseEnd
	add_child(_close)


func _process(delta: float) -> void:
	_t += delta
	var s := _s()
	_close.size = Vector2(52, 52) * s
	_close.position = _R(694, 30) - _close.size / 2.0
	_close.queue_redraw()
	queue_redraw()


# ---- 座標換算：x 貼齊螢幕左右邊，y 跟著設計畫布

func _s() -> float:
	return canvas.scale.x if canvas else size.x / DESIGN.x


func _y(y: float) -> float:
	return (canvas.position.y if canvas else 0.0) + y * _s()


func _L(x: float, y: float) -> Vector2:
	return Vector2(x * _s(), _y(y))


func _R(x: float, y: float) -> Vector2:
	return Vector2(size.x - (DESIGN.x - x) * _s(), _y(y))


func _text(p: Vector2, t: String, fs: float, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var px := int(fs * _s())
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := p.x
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w / 2.0
	draw_string(_font, Vector2(x, p.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, c)


func _line(pts: Array, c := DIM, w := 1.5) -> void:
	draw_polyline(PackedVector2Array(pts), c, w * _s(), true)


# ---- 繪製

func _draw() -> void:
	var s := _s()
	var top := _y(8)
	var bottom := _y(1272)
	var l := 8.0 * s
	var r := size.x - 8.0 * s

	# 左右邊框：直線＋中段的凸出缺口（箭頭旁）
	for side: int in [-1, 1]:
		var x := l if side < 0 else r
		var k := float(side)
		_line([Vector2(x, _y(60)), Vector2(x, _y(470)), Vector2(x - 6 * s * k, _y(490)), Vector2(x - 6 * s * k, _y(600)), Vector2(x, _y(620)), Vector2(x, _y(1180))])
		# 側邊細刻度
		for i in 8:
			var yy := _y(700 + i * 12)
			draw_line(Vector2(x, yy), Vector2(x - 6 * s * k, yy), DIM, 1.0 * s)
	# 四角
	var cl := 34.0 * s
	for c in [[Vector2(l, top), 1, 1], [Vector2(r, top), -1, 1], [Vector2(l, bottom), 1, -1], [Vector2(r, bottom), -1, -1]]:
		var p: Vector2 = c[0]
		_line([p + Vector2(0, cl * c[2]), p, p + Vector2(cl * c[1], 0)], CYAN, 2.0)
	# 上方細線（左上標題延伸）
	_line([_L(18, 40), _L(60, 40), _L(70, 30), _L(250, 30)])
	_line([_R(568, 108), _R(600, 108), _R(610, 98), _R(650, 98)])
	_line([_L(70, 108), _L(150, 108), _L(160, 98)])

	# 左上：Logo 徽章＋版本字＋SYS 小圖表
	var badge := _L(36, 30)
	var tri := PackedVector2Array([badge + Vector2(0, -14) * s, badge + Vector2(13, 9) * s, badge + Vector2(-13, 9) * s, badge + Vector2(0, -14) * s])
	draw_polyline(tri, CYAN, 1.5 * s, true)
	draw_circle(badge + Vector2(0, 2) * s, 4 * s, CYAN, false, 1.2 * s)
	_text(_L(70, 25), subtitle, 13, TEXT)
	_text(_L(18, 72), "SYS", 12, TEXT)
	for i in 6:
		var h := (8.0 + 14.0 * absf(sin(_t * 1.7 + i * 1.3))) * s
		var bx := _L(18 + i * 7, 128)
		draw_rect(Rect2(bx.x, bx.y - h, 4 * s, h), Color(CYAN, 0.75))
	_line([_L(16, 132), _L(66, 132)])

	# Logo 下方：連線狀態
	var blink := 0.45 + 0.55 * absf(sin(_t * 2.2))
	_text(Vector2(size.x / 2.0 - 14 * s, _y(146)), "CONNECTIVITY", 13, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_circle(Vector2(size.x / 2.0, _y(141)), 3.5 * s, Color(0.4, 1.0, 0.6, blink))
	_text(Vector2(size.x / 2.0 + 14 * s, _y(146)), "ONLINE", 13, Color(0.5, 1.0, 0.7, 0.95))

	# 右上：PILOT
	var hex_c := _R(530, 34)
	var hex := PackedVector2Array()
	for i in 7:
		var a := PI / 6.0 + i * TAU / 6.0
		hex.append(hex_c + Vector2(cos(a), sin(a)) * 22 * s)
	draw_polyline(hex, CYAN, 1.8 * s, true)
	draw_circle(hex_c + Vector2(0, -5) * s, 6 * s, Color(CYAN, 0.8))
	draw_arc(hex_c + Vector2(0, 13) * s, 12 * s, PI + 0.3, TAU - 0.3, 12, Color(CYAN, 0.8), 3 * s, true)
	_text(_R(560, 30), "PILOT", 13, TEXT)
	_text(_R(560, 50), pilot, 16, Color.WHITE)
	_line([_R(556, 58), _R(650, 58)])

	# 左側：CLASS / FRAME 小圖
	_text(_L(18, 648), "CLASS: %s" % ship_class, 13, TEXT)
	_text(_L(18, 668), "FRAME", 12, TEXT)
	var f0 := _L(20, 676)
	draw_rect(Rect2(f0, Vector2(70, 28) * s), DIM, false, 1.0 * s)
	_line([f0 + Vector2(10, 14) * s, f0 + Vector2(30, 14) * s, f0 + Vector2(36, 6) * s, f0 + Vector2(52, 6) * s, f0 + Vector2(60, 20) * s])

	# 右側：THRUST VECTOR 折線圖
	_text(_R(702, 648), "THRUST", 12, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(_R(702, 664), "VECTOR", 12, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	var g0 := _R(632, 674)
	draw_rect(Rect2(g0, Vector2(70, 30) * s), DIM, false, 1.0 * s)
	var gp := PackedVector2Array()
	for i in 12:
		var v := 0.5 + 0.35 * sin(_t * 2.0 + i * 0.7) * (i / 12.0) + i / 30.0
		gp.append(g0 + Vector2(4 + i * 5.6, 28 - clampf(v, 0.0, 1.0) * 24) * s)
	draw_polyline(gp, CYAN, 1.5 * s, true)

	# 下方左右：雷達
	for side: int in [-1, 1]:
		var rc := _L(70, 1196) if side < 0 else _R(650, 1196)
		for rr in [44.0, 30.0, 16.0]:
			draw_arc(rc, rr * s, 0, TAU, 40, Color(CYAN, 0.35), 1.2 * s, true)
		draw_line(rc - Vector2(46, 0) * s, rc + Vector2(46, 0) * s, Color(CYAN, 0.2), 1.0 * s)
		draw_line(rc - Vector2(0, 46) * s, rc + Vector2(0, 46) * s, Color(CYAN, 0.2), 1.0 * s)
		var a := _t * 2.0 * side
		for k in 8:   # 掃描殘影
			var aa := a - k * 0.08 * side
			draw_line(rc, rc + Vector2(cos(aa), sin(aa)) * 44 * s, Color(CYAN, 0.6 - k * 0.07), 2.0 * s, true)
		var blip := rc + Vector2(cos(1.3 * side), sin(-0.6)) * 26 * s
		draw_circle(blip, 2.5 * s, Color(1, 0.5, 0.4, 0.5 + 0.5 * absf(sin(_t * 3.0 + side))))

	# 最下方狀態列
	var by := _y(1262)
	_line([Vector2(l, by - 16 * s), _L(40, 1246), _L(250, 1246), _L(262, 1236), _L(290, 1236)])
	_line([Vector2(r, by - 16 * s), _R(680, 1246), _R(470, 1246), _R(458, 1236), _R(430, 1236)])
	var planet := _L(30, 1258)
	draw_circle(planet, 6 * s, Color(CYAN, 0.8), false, 1.5 * s)
	draw_arc(planet, 10 * s, -0.4, 0.4 + PI, 16, Color(CYAN, 0.6), 1.2 * s)
	_text(_L(46, 1264), sector, 15, TEXT)
	_text(_R(642, 1264), "FUEL 100%", 15, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	var bat := _R(650, 1252)
	draw_rect(Rect2(bat, Vector2(20, 11) * s), Color(TEXT, 0.9), false, 1.2 * s)
	draw_rect(Rect2(bat + Vector2(2, 2) * s, Vector2(16, 7) * s), Color(0.5, 1.0, 0.6, 0.9))
	for i in 4:
		var h := (4 + i * 3) * s
		var sx := _R(678 + i * 5, 1263)
		draw_rect(Rect2(sx.x, sx.y - h, 3 * s, h), TEXT)


func _draw_close() -> void:
	var s := _s()
	var c := _close.size / 2.0
	_close.draw_arc(c, 20 * s, 0, TAU, 32, CYAN, 1.8 * s, true)
	var d := 8 * s
	_close.draw_line(c + Vector2(-d, -d), c + Vector2(d, d), Color.WHITE, 2.2 * s, true)
	_close.draw_line(c + Vector2(d, -d), c + Vector2(-d, d), Color.WHITE, 2.2 * s, true)
