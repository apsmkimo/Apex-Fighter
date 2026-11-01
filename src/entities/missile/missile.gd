class_name Missile
extends Area2D
## 自動追蹤導彈：發射後先往外側飛，再轉向最近的敵人。程式繪製，不需要貼圖。

const SPEED := 760.0
const TURN_RATE := 7.0
const LIFETIME := 3.0
const TRAIL_LEN := 8

var velocity := Vector2.UP * 300.0
var damage := 3
var _age := 0.0
var _target: Enemy
var _trail: Array[Vector2] = []
var _done := false


static func launch(parent: Node, pos: Vector2, side: float, dmg: int) -> void:
	var m := Missile.new()
	m.position = pos
	m.velocity = Vector2(side * 420.0, -260.0)
	m.damage = dmg
	parent.add_child(m)


func _ready() -> void:
	collision_layer = 1 << 1   # player_bullet
	collision_mask = 1 << 2    # enemy
	monitorable = false
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 9.0
	shape.shape = c
	add_child(shape)
	area_entered.connect(_on_area_entered)
	z_index = 1


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME or not get_viewport_rect().grow(80).has_point(global_position):
		queue_free()
		return
	if _target == null or not is_instance_valid(_target) or _target.health.dead or not _target.is_on_screen():
		_target = _find_target()
	var desired := Vector2.UP * SPEED
	if _target:
		desired = (_target.global_position - global_position).normalized() * SPEED
	if _age > 0.12:
		var ang := velocity.angle()
		var want := desired.angle()
		ang = rotate_toward(ang, want, TURN_RATE * delta)
		var spd := minf(velocity.length() + 1800.0 * delta, SPEED)
		velocity = Vector2.RIGHT.rotated(ang) * spd
	_trail.push_front(global_position)
	if _trail.size() > TRAIL_LEN:
		_trail.pop_back()
	position += velocity * delta
	rotation = velocity.angle() + PI / 2.0
	queue_redraw()


func _find_target() -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var e := node as Enemy
		if e == null or e.health.dead or not e.is_on_screen():
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _on_area_entered(area: Area2D) -> void:
	if _done or not area is Enemy:
		return
	_done = true
	(area as Enemy).take_damage(damage)
	queue_free()


func _draw() -> void:
	# 尾焰（用世界座標轉回本地）
	for i in _trail.size():
		var k := 1.0 - float(i) / TRAIL_LEN
		var p := to_local(_trail[i])
		draw_circle(p, 5.0 * k + 1.0, Color(0.3, 1.0, 0.6, 0.45 * k))
	# 彈體：白色機身＋綠色霓虹彈頭
	draw_rect(Rect2(-3, -8, 6, 16), Color(0.9, 0.95, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -8), Vector2(3, -8), Vector2(0, -14)]), Color(0.3, 1.0, 0.6))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, 6), Vector2(-7, 10), Vector2(-3, 2)]), Color(0.6, 0.65, 0.75))
	draw_colored_polygon(PackedVector2Array([Vector2(3, 6), Vector2(7, 10), Vector2(3, 2)]), Color(0.6, 0.65, 0.75))
	draw_circle(Vector2(0, 10), 3.5, Color(1.0, 0.9, 0.5, 0.9))
