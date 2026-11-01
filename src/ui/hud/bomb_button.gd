class_name BombButton
extends Control
## 右下角炸彈按鈕：大圓形霓虹按鈕＋炸彈圖示＋剩餘數量徽章。
## 按下時縮小回彈並放出光環；沒有炸彈時變暗。

signal pressed

const SIZE := 200.0

var count := 3:
	set(v):
		count = v
		queue_redraw()
var _t := 0.0
var _press := 0.0     # 按下回饋（1 → 0）
var _ring := 0.0      # 擴散光環（0 → 1）


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	# Android 預設會把觸控轉成滑鼠事件，所以只聽滑鼠，避免同一下觸發兩次
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_press = 1.0
		_ring = 0.0001 if count > 0 else 0.0
		pressed.emit()


func _process(delta: float) -> void:
	_t += delta
	_press = maxf(_press - delta * 5.0, 0.0)
	if _ring > 0.0:
		_ring += delta * 2.5
		if _ring >= 1.0:
			_ring = 0.0
	scale = Vector2.ONE * (1.0 - 0.12 * _press)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := SIZE * 0.4
	var ready := count > 0
	var col := NeonDraw.GREEN if ready else Color(0.4, 0.45, 0.55)
	var pulse := 0.5 + 0.5 * sin(_t * 3.0) if ready else 0.0
	# 底盤
	draw_circle(c, r + 14.0, Color(col.r, col.g, col.b, 0.08 + 0.06 * pulse))
	draw_circle(c, r, Color(0.02, 0.05, 0.12, 0.7))
	# 外圈：發光環＋旋轉刻度
	draw_arc(c, r, 0, TAU, 48, Color(col.r, col.g, col.b, 0.3), 8.0)
	draw_arc(c, r, 0, TAU, 48, col, 2.5)
	for i in 3:
		var a := _t * 1.2 + TAU * i / 3.0
		draw_arc(c, r + 9.0, a, a + 0.7, 10, Color(col.r, col.g, col.b, 0.7), 3.0)
	# 按下時的白色閃光
	if _press > 0.0:
		draw_circle(c, r, Color(1, 1, 1, 0.25 * _press))
	# 擴散光環
	if _ring > 0.0:
		draw_arc(c, r + 50.0 * _ring, 0, TAU, 40, Color(col.r, col.g, col.b, 1.0 - _ring), 4.0)
	# 圖示與文字
	NeonDraw.icon_bomb(self, c + Vector2(0, -14), 30, col)
	NeonDraw.text(self, c + Vector2(-r, r * 0.72), "BOMB", 24, col.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
	# 數量徽章（右上）
	var b := c + Vector2(r * 0.72, -r * 0.72)
	draw_circle(b, 24.0, Color(0.02, 0.04, 0.1, 0.95))
	draw_arc(b, 24.0, 0, TAU, 24, col, 2.5)
	NeonDraw.text(self, b + Vector2(-24, 10), str(count), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 48, false)
