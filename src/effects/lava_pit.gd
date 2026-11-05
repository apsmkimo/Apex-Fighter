class_name LavaPit
extends Node2D
## 紅光岩漿坑（場景傷害貼花）：跟著地表捲動，岩漿會跳動發光。
## 戰機在坑裡每 TICK 秒受到 damage 點灼燒傷害，life 秒後淡出消失。
## scorch = true 時是雷射燒痕：只有發光的焦痕，不傷人。

const TICK := 1.0
const FADE_IN := 0.18
const FADE_OUT := 0.7

var texture: Texture2D
var size := 160.0
var life := 4.0
var damage := 1
var scorch := false
var _age := 0.0
var _tick := 0.3
var _rot := 0.0
var _seed := 0.0


## 在 parent 底下產生一個岩漿坑（pos 為世界座標）
static func spawn(parent: Node, pos: Vector2, tex: Texture2D, pit_size: float, pit_life := 4.0, dmg := 1) -> LavaPit:
	if parent == null or not is_instance_valid(parent):
		return null
	var p := LavaPit.new()
	p.texture = tex
	p.size = pit_size
	p.life = pit_life
	p.damage = dmg
	p.position = pos
	parent.add_child.call_deferred(p)
	return p


## 雷射燒痕（不傷人，短暫發光）
static func spawn_scorch(parent: Node, pos: Vector2, scorch_size: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var p := LavaPit.new()
	p.scorch = true
	p.size = scorch_size
	p.life = 2.2
	p.damage = 0
	p.position = pos
	parent.add_child.call_deferred(p)


func _ready() -> void:
	z_index = -6
	_rot = randf() * TAU
	_seed = randf() * 10.0
	add_to_group(&"lava_pits")


func _physics_process(delta: float) -> void:
	_age += delta
	position.y += ScrollBackground.ground_speed * delta
	if _age >= life or position.y > get_viewport_rect().size.y + size:
		queue_free()
		return
	if not scorch and damage > 0 and _age > FADE_IN and _age < life - FADE_OUT * 0.5:
		_tick -= delta
		var pl := Player.instance
		if _tick <= 0.0 and pl and pl.alive and pl.global_position.distance_to(global_position) < size * 0.38 + pl.ship.hitbox_radius:
			_tick = TICK
			pl.take_hit(damage)
			if NeonFx.instance:
				NeonFx.instance.ring(global_position, size * 0.2, size * 0.5, 0.3, Color(1.0, 0.25, 0.15), 4.0)
	# 岩漿冒泡的火星
	if not scorch and NeonFx.instance and Engine.get_physics_frames() % 5 == 0:
		var d := Vector2.RIGHT.rotated(randf() * TAU) * randf() * size * 0.3
		NeonFx.instance.emit(global_position + d, Vector2(randf_range(-20, 20), randf_range(-70, -30)), 0.6, randf_range(4.0, 8.0), Color(1.0, 0.35, 0.15, 0.8))
	queue_redraw()


func _alpha() -> float:
	return clampf(_age / FADE_IN, 0.0, 1.0) * clampf((life - _age) / FADE_OUT, 0.0, 1.0)


func _draw() -> void:
	var a := _alpha()
	if scorch:
		# 燒痕：暗紅焦黑底＋漸暗的紅光
		var k := _age / life
		draw_circle(Vector2.ZERO, size * 0.5, Color(0.08, 0.0, 0.0, 0.55 * a))
		draw_circle(Vector2.ZERO, size * 0.32, Color(1.0, 0.2, 0.1, 0.5 * a * (1.0 - k)))
		draw_circle(Vector2.ZERO, size * 0.14, Color(1.0, 0.75, 0.4, 0.6 * a * (1.0 - k)))
		return
	# 岩漿跳動：大小與亮度用兩個不同頻率的波疊起來
	var pulse := 0.5 + 0.25 * sin(_age * 7.0 + _seed) + 0.25 * sin(_age * 11.3 + _seed * 2.0)
	if texture:
		var ts := texture.get_size()
		var sc := size * (0.96 + 0.06 * pulse) * (0.7 + 0.3 * clampf(_age / FADE_IN, 0.0, 1.0)) / maxf(ts.x, ts.y)
		draw_set_transform(Vector2.ZERO, _rot, Vector2(sc, sc))
		var bright := 0.85 + 0.35 * pulse
		draw_texture(texture, -ts * 0.5, Color(bright, bright * 0.92, bright * 0.9, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(Vector2.ZERO, size * 0.45, Color(0.6, 0.05, 0.0, a))
	# 加亮光暈（另一個 CanvasItem 太貴，這裡用多層半透明圓）
	var g := NeonFx.get_glow_tex()
	var r := size * (0.42 + 0.06 * pulse)
	draw_texture_rect(g, Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(1.0, 0.25, 0.1, 0.35 * a * (0.6 + 0.4 * pulse)))
