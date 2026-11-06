class_name NeonDraw
extends RefCounted
## HUD 共用的霓虹繪圖工具：發光文字、圖示、切角面板。
## 全部用 CanvasItem 的 draw_* 指令畫，不需要任何圖檔，換風格只要改這裡。

const CYAN := Color(0.3, 0.9, 1.0)
const BLUE := Color(0.35, 0.55, 1.0)
const MAGENTA := Color(1.0, 0.3, 0.85)
const AMBER := Color(1.0, 0.75, 0.3)
const GREEN := Color(0.4, 1.0, 0.6)
const RED := Color(1.0, 0.3, 0.35)
const PANEL_BG := Color(0.02, 0.04, 0.12, 0.62)
const OUTLINE := Color(0.01, 0.01, 0.05, 0.95)


static func font() -> Font:
	return ThemeDB.fallback_font


## 有描邊和外發光的文字。align_w > 0 時在這個寬度內依 align 對齊。
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, align_w := -1.0, glow := true) -> void:
	var f := font()
	if glow:
		ci.draw_string_outline(f, pos, s, align, align_w, size, 12, Color(col.r, col.g, col.b, 0.22))
	ci.draw_string_outline(f, pos, s, align, align_w, size, 6, OUTLINE)
	ci.draw_string(f, pos, s, align, align_w, size, col)


## 右上與左下切角的科技面板
static func panel(ci: CanvasItem, r: Rect2, border: Color, cut := 14.0) -> void:
	var pts := PackedVector2Array([
		r.position, Vector2(r.end.x - cut, r.position.y), Vector2(r.end.x, r.position.y + cut),
		r.end, Vector2(r.position.x + cut, r.end.y), Vector2(r.position.x, r.end.y - cut)])
	ci.draw_colored_polygon(pts, PANEL_BG)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, Color(border.r, border.g, border.b, 0.18), 6.0, true)
	ci.draw_polyline(loop, Color(border.r, border.g, border.b, 0.75), 1.5, true)
	# 角落亮條
	ci.draw_line(r.position, r.position + Vector2(36, 0), border, 3.0)
	ci.draw_line(r.end, r.end - Vector2(36, 0), border, 3.0)


static func _glow_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, Color(col.r, col.g, col.b, 0.3), 5.0, true)
	ci.draw_colored_polygon(pts, col)


# ---------- 圖示（中心點 c、大小 s） ----------

## 戰機（殘機）
static func icon_ship(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	_glow_poly(ci, PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, s * 0.7),
			c + Vector2(0, s * 0.35), c + Vector2(-s * 0.8, s * 0.7)]), col)


## 炸彈
static func icon_bomb(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(0, s * 0.15), s * 0.95, Color(col.r, col.g, col.b, 0.25))
	ci.draw_circle(c + Vector2(0, s * 0.15), s * 0.72, col)
	ci.draw_circle(c + Vector2(-s * 0.25, -s * 0.1), s * 0.18, Color(1, 1, 1, 0.8))
	ci.draw_line(c + Vector2(s * 0.35, -s * 0.45), c + Vector2(s * 0.65, -s * 0.85), col, 3.0)
	ci.draw_circle(c + Vector2(s * 0.7, -s * 0.92), s * 0.18, AMBER)


## 閃電（火力）
static func icon_bolt(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	_glow_poly(ci, PackedVector2Array([c + Vector2(s * 0.2, -s), c + Vector2(-s * 0.55, s * 0.12),
			c + Vector2(-s * 0.02, s * 0.12), c + Vector2(-s * 0.25, s), c + Vector2(s * 0.55, -s * 0.15),
			c + Vector2(s * 0.02, -s * 0.15)]), col)


## 主武器（菱形能量彈）
static func icon_weapon(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	_glow_poly(ci, PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.5, 0),
			c + Vector2(0, s), c + Vector2(-s * 0.5, 0)]), col)
	ci.draw_line(c + Vector2(0, -s * 0.6), c + Vector2(0, s * 0.6), Color(1, 1, 1, 0.8), 2.0)


## 導彈
static func icon_missile(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	_glow_poly(ci, PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.28, -s * 0.5),
			c + Vector2(s * 0.28, s * 0.5), c + Vector2(s * 0.6, s), c + Vector2(-s * 0.6, s),
			c + Vector2(-s * 0.28, s * 0.5), c + Vector2(-s * 0.28, -s * 0.5)]), col)


## 護盾光點：中心一顆亮點＋外圈環
static func icon_shield(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_arc(c, s * 0.85, 0, TAU, 24, Color(col, col.a * 0.6), 2.0, true)
	ci.draw_circle(c, s * 0.5, Color(col, col.a * 0.5))
	ci.draw_circle(c, s * 0.3, Color(0.85, 1.0, 1.0, col.a))


## 愛心（HP）
static func icon_hp(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-s * 0.36, -s * 0.2), s * 0.42, col)
	ci.draw_circle(c + Vector2(s * 0.36, -s * 0.2), s * 0.42, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.78, -s * 0.05),
			c + Vector2(s * 0.78, -s * 0.05), c + Vector2(0, s * 0.85)]), col)
