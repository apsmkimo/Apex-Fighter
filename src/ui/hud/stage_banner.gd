class_name StageBanner
extends Control
## 畫面中央的動畫提示（STAGE 標題、WARNING、STAGE CLEAR、GAME OVER）。
## 動畫：上下光條從中間展開 → 文字逐字出現並發光 → 收合淡出。
## warning = true 時加上捲動的警示斜紋並閃爍。

var _title := ""
var _sub := ""
var _col := NeonDraw.CYAN
var _dur := 0.0
var _t := -1.0
var _warning := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(title: String, subtitle: String, col: Color, duration := 2.6, warning := false) -> void:
	_title = title
	_sub = subtitle
	_col = col
	_dur = duration
	_warning = warning
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t > _dur:
		_t = -1.0
	queue_redraw()


func _draw() -> void:
	if _t < 0.0:
		return
	var w := size.x
	var cy := size.y * 0.42
	var open := clampf(_t / 0.35, 0.0, 1.0)            # 展開
	var close := clampf((_dur - _t) / 0.4, 0.0, 1.0)    # 收合
	var k := ease(open, -2.0) * close
	var half_h := 62.0 * k
	var col := _col
	if _warning:
		col.a = 0.55 + 0.45 * absf(sin(_t * 7.0))
	# 帶狀底色＋掃描線
	draw_rect(Rect2(0, cy - half_h, w, half_h * 2.0), Color(0.02, 0.03, 0.1, 0.6 * k))
	var y := cy - half_h
	while y < cy + half_h:
		draw_line(Vector2(0, y), Vector2(w, y), Color(col.r, col.g, col.b, 0.05 * k), 1.0)
		y += 6.0
	# 上下光條（從中間往兩側展開）
	var lw := w * ease(open, -2.0) * 0.5
	for sy: float in [-half_h, half_h]:
		var ly := cy + sy
		draw_line(Vector2(w / 2.0 - lw, ly), Vector2(w / 2.0 + lw, ly), Color(col.r, col.g, col.b, 0.3 * close), 8.0)
		draw_line(Vector2(w / 2.0 - lw, ly), Vector2(w / 2.0 + lw, ly), Color(col.r, col.g, col.b, close), 2.0)
		if _warning:
			# 警示斜紋：沿光條捲動
			var off := fmod(_t * 120.0, 40.0)
			var x := -40.0 + off
			var dir := -1.0 if sy < 0.0 else 1.0
			while x < w:
				draw_colored_polygon(PackedVector2Array([Vector2(x, ly), Vector2(x + 16, ly), Vector2(x + 30, ly + 14 * dir), Vector2(x + 14, ly + 14 * dir)]),
						Color(col.r, col.g, col.b, 0.5 * close))
				x += 40.0
	# 文字逐字出現
	var reveal := clampf((_t - 0.2) / 0.45, 0.0, 1.0)
	var shown := _title.substr(0, int(ceil(_title.length() * reveal)))
	if shown != "":
		var f := NeonDraw.font()
		var tc := Color(col.lightened(0.45).r, col.lightened(0.45).g, col.lightened(0.45).b, close * col.a)
		var pos := Vector2(0, cy + 22)
		draw_string_outline(f, pos, shown, HORIZONTAL_ALIGNMENT_CENTER, w, 64, 26, Color(col.r, col.g, col.b, 0.18 * close))
		draw_string_outline(f, pos, shown, HORIZONTAL_ALIGNMENT_CENTER, w, 64, 12, Color(col.r, col.g, col.b, 0.45 * close))
		draw_string_outline(f, pos, shown, HORIZONTAL_ALIGNMENT_CENTER, w, 64, 5, Color(0.01, 0.01, 0.05, close))
		draw_string(f, pos, shown, HORIZONTAL_ALIGNMENT_CENTER, w, 64, tc)
	if _sub != "" and reveal >= 1.0:
		var sa := clampf((_t - 0.65) / 0.3, 0.0, 1.0) * close
		NeonDraw.text(self, Vector2(0, cy - half_h - 14), _sub, 22, Color(col.r, col.g, col.b, sa), HORIZONTAL_ALIGNMENT_CENTER, w)
