class_name TimeBomb
extends Node2D
## 計時炸彈（大 Boss 武器）：被丟出後減速停在太空中，螢幕倒數，時間到範圍爆炸。
## 打不壞，只能躲。爆炸範圍會在最後 1.5 秒閃紅提示。

const TEX := preload("res://assets/sprites/hazards/time_bomb.png")

var velocity := Vector2.ZERO
var fuse := 4.0
var radius := 150.0
var damage := 3
var _t := 0.0
var _total := 4.0


static func spawn(parent: Node, from: Vector2, to: Vector2, fuse_time: float, blast_r: float, dmg: int) -> TimeBomb:
	var b := TimeBomb.new()
	b.position = from
	# 用減速運動在約 0.8 秒內滑到目標點
	b.velocity = (to - from) / 0.8 * 2.0
	b.fuse = fuse_time
	b._total = fuse_time
	b.radius = blast_r
	b.damage = dmg
	parent.add_child(b)
	return b


func _ready() -> void:
	z_index = 2
	add_to_group(&"time_bombs")


func _physics_process(delta: float) -> void:
	_t += delta
	position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, velocity.length() * 2.5 * delta + 20.0 * delta)
	fuse -= delta
	if fuse <= 0.0:
		_explode()
		return
	queue_redraw()


func _explode() -> void:
	if NeonFx.instance:
		NeonFx.instance.explode(global_position, 2.6)
		NeonFx.instance.ring(global_position, 20.0, radius, 0.4, Color(0.4, 0.7, 1.0), 8.0)
		NeonFx.instance.ring(global_position, 10.0, radius * 0.7, 0.3, Color(1.0, 0.85, 0.3), 5.0)
	Events.screen_shake.emit(12.0, 0.35)
	var p := Player.instance
	if p and p.alive and global_position.distance_to(p.global_position) < radius:
		p.take_hit(damage)
	queue_free()


func _draw() -> void:
	var warn := fuse < 1.5
	var blink := 0.5 + 0.5 * sin(_t * (8.0 if not warn else 22.0))
	# 爆炸範圍
	var col := Color(1.0, 0.25, 0.3) if warn else Color(0.35, 0.65, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, 0.05 + (0.08 * blink if warn else 0.0)))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(col.r, col.g, col.b, 0.35 + 0.35 * blink), 2.5)
	# 剩餘時間的弧
	var k := clampf(fuse / _total, 0.0, 1.0)
	draw_arc(Vector2.ZERO, 60.0, -PI / 2, -PI / 2 + TAU * k, 48, Color(col.r, col.g, col.b, 0.9), 4.0)
	var s := 1.0 + (0.08 * blink if warn else 0.0)
	var sz := TEX.get_size() * s
	draw_texture_rect(TEX, Rect2(-sz * 0.5, sz), false)
	# 機身螢幕上的倒數（蓋在原圖的顯示器位置）
	var txt := "%02d:%02d" % [int(fuse), int(fmod(fuse, 1.0) * 100.0)]
	draw_rect(Rect2(Vector2(-25, -9) * s, Vector2(50, 18) * s), Color(0.01, 0.04, 0.1, 0.95))
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(-25, 6) * s, txt, HORIZONTAL_ALIGNMENT_CENTER, 50.0 * s, int(14 * s), Color(1.0, 0.35, 0.35) if warn else Color(0.45, 0.85, 1.0))
