class_name ScrollBackground
extends Node2D
## 程式繪製的捲軸背景：漸層天空 + 三層視差星星 + 雲塊。之後可以換成 TileMap 或圖片。

const LAYERS := [
	{ "count": 60, "speed": 0.35, "size": 1.5, "alpha": 0.45 },
	{ "count": 35, "speed": 0.7, "size": 2.5, "alpha": 0.7 },
	{ "count": 14, "speed": 1.2, "size": 3.5, "alpha": 1.0 },
]

var scroll_speed := 160.0
var top_color := Color(0.04, 0.06, 0.16)
var bottom_color := Color(0.10, 0.14, 0.30)
var _stars: Array = []
var _clouds: Array = []


func setup(stage: StageData) -> void:
	scroll_speed = stage.scroll_speed
	top_color = stage.bg_top_color
	bottom_color = stage.bg_bottom_color


func _ready() -> void:
	var size := get_viewport_rect().size
	for layer in LAYERS:
		var pts := []
		for i in layer.count:
			pts.append(Vector2(randf() * size.x, randf() * size.y))
		_stars.append(pts)
	for i in 6:
		_clouds.append(Rect2(randf() * size.x - 100.0, randf() * size.y, randf_range(120, 260), randf_range(40, 90)))


func _process(delta: float) -> void:
	var size := get_viewport_rect().size
	for li in LAYERS.size():
		var pts: Array = _stars[li]
		var v: float = scroll_speed * LAYERS[li].speed * delta
		for i in pts.size():
			var p: Vector2 = pts[i]
			p.y += v
			if p.y > size.y:
				p = Vector2(randf() * size.x, p.y - size.y)
			pts[i] = p
	for i in _clouds.size():
		var r: Rect2 = _clouds[i]
		r.position.y += scroll_speed * 1.6 * delta
		if r.position.y > size.y:
			r = Rect2(randf() * size.x - 100.0, -r.size.y - randf() * 200.0, r.size.x, r.size.y)
		_clouds[i] = r
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	for r in _clouds:
		draw_rect(r, Color(1, 1, 1, 0.05))
	for li in LAYERS.size():
		var c := Color(0.8, 0.9, 1.0, LAYERS[li].alpha)
		for p in _stars[li]:
			draw_circle(p, LAYERS[li].size, c)
