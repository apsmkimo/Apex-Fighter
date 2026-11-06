class_name HudStatusPanel
extends Control
## 左下角狀態面板：發光分段 HP 條＋圖示與數字（殘機、炸彈、火力、武器、導彈、護盾）。
## 一個 Control 一次 _draw 畫完；只有數值改變或需要閃爍動畫時才重畫。

const W := 340.0
const H := 176.0

var hp := 6
var max_hp := 6
var lives := 3
var bombs := 3
var power := 0
var weapon_name := ""
var weapon_color := NeonDraw.CYAN
var missile := 0
var shield := 0.0

var _t := 0.0
## 扣血時的閃白殘影（0~1）
var _hp_flash := 0.0
var _lost_from := 0


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hp(v: int, m: int) -> void:
	if v < hp:
		_hp_flash = 1.0
		_lost_from = hp
	hp = v
	max_hp = maxi(m, 1)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var animating := _hp_flash > 0.0 or hp * 3 <= max_hp
	if _hp_flash > 0.0:
		_hp_flash = maxf(_hp_flash - delta * 2.5, 0.0)
	if animating:
		queue_redraw()


func _draw() -> void:
	NeonDraw.panel(self, Rect2(0, 0, W, H), NeonDraw.CYAN)
	_draw_hp(Vector2(16, 18))
	# 第二列：殘機／炸彈／火力
	var y := 76.0
	NeonDraw.icon_ship(self, Vector2(30, y), 12, NeonDraw.CYAN)
	NeonDraw.text(self, Vector2(48, y + 10), "x%d" % maxi(lives, 0), 28, Color.WHITE)
	NeonDraw.icon_bomb(self, Vector2(132, y), 12, NeonDraw.GREEN)
	NeonDraw.text(self, Vector2(150, y + 10), "x%d" % bombs, 28, Color.WHITE)
	NeonDraw.icon_bolt(self, Vector2(234, y), 13, NeonDraw.AMBER)
	NeonDraw.text(self, Vector2(250, y + 10), "LV%d" % (power + 1), 28, NeonDraw.AMBER)
	# 分隔線
	draw_line(Vector2(16, 100), Vector2(W - 16, 100), Color(0.3, 0.9, 1.0, 0.25), 1.0)
	# 第三列：主武器名稱
	y = 125.0
	NeonDraw.icon_weapon(self, Vector2(30, y), 13, weapon_color)
	NeonDraw.text(self, Vector2(50, y + 9), weapon_name, 24, weapon_color.lightened(0.3))
	# 第四列：導彈／護盾（沒有就不顯示）
	y = 156.0
	var x := 22.0
	if missile > 0:
		NeonDraw.icon_missile(self, Vector2(x + 8, y), 11, Color(0.75, 0.5, 1.0))
		NeonDraw.text(self, Vector2(x + 26, y + 8), "x%d" % missile, 22, Color(0.85, 0.7, 1.0))
		x += 110.0
	if shield > 0.0:
		var sc := Color(0.35, 0.85, 1.0)
		NeonDraw.icon_shield(self, Vector2(x + 8, y), 11, sc)
		NeonDraw.text(self, Vector2(x + 26, y + 8), "x%d" % int(shield), 22, sc)


## 分段 HP 條：每格一點血，斜切平行四邊形，依剩餘比例變色，低血量閃爍
func _draw_hp(o: Vector2) -> void:
	var ratio := float(hp) / max_hp
	var col := NeonDraw.CYAN if ratio > 0.67 else (NeonDraw.AMBER if ratio > 0.34 else NeonDraw.RED)
	if hp * 3 <= max_hp:
		col.a = 0.55 + 0.45 * absf(sin(_t * 6.0))
	NeonDraw.icon_hp(self, o + Vector2(12, 16), 11, col)
	NeonDraw.text(self, o + Vector2(28, 26), "HP", 22, col)
	var bar_x := o.x + 70.0
	var bar_w := W - bar_x - 18.0
	var gap := 5.0
	var seg_w := (bar_w - gap * (max_hp - 1)) / max_hp
	var hgt := 24.0
	var skew := 7.0
	for i in max_hp:
		var x := bar_x + i * (seg_w + gap)
		var pts := PackedVector2Array([Vector2(x + skew, o.y + 4), Vector2(x + seg_w + skew, o.y + 4),
				Vector2(x + seg_w, o.y + 4 + hgt), Vector2(x, o.y + 4 + hgt)])
		if i < hp:
			# 外發光＋實心＋上緣高光
			var loop := pts.duplicate()
			loop.append(pts[0])
			draw_polyline(loop, Color(col.r, col.g, col.b, 0.35 * col.a), 6.0, true)
			draw_colored_polygon(pts, col)
			draw_line(pts[0] + Vector2(2, 3), pts[1] + Vector2(-2, 3), Color(1, 1, 1, 0.55 * col.a), 2.0)
		elif i < _lost_from and _hp_flash > 0.0:
			# 剛被扣掉的格子：白色殘影漸漸消失
			draw_colored_polygon(pts, Color(1, 1, 1, _hp_flash * 0.85))
		else:
			var loop := pts.duplicate()
			loop.append(pts[0])
			draw_colored_polygon(pts, Color(0.05, 0.08, 0.18, 0.8))
			draw_polyline(loop, Color(col.r, col.g, col.b, 0.35), 1.5, true)
