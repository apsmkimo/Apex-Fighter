class_name Bullet
extends Area2D
## 子彈（玩家與敵人共用），由 BulletPool 重複使用，不會一直 new / free。

const LAYER_PLAYER_BULLET := 1 << 1
const LAYER_ENEMY_BULLET := 1 << 3
const MASK_ENEMY := 1 << 2
const SCREEN_MARGIN := 64.0

var velocity := Vector2.ZERO
var damage := 1
var is_player_bullet := false
var active := false
## 穿透彈：打中不消失，對同一隻敵機只打一次
var pierce := false
var _hit_ids: Array[int] = []
## 追蹤彈轉向速度（弧度/秒）
var homing := 0.0
var _target: Enemy
var _retarget := 0.0
## 爆裂彈
var splash_radius := 0.0
var splash_damage := 0
## 敵方分裂彈：飛行 split_time 秒後裂成 split_count 顆扇形小彈
var split_time := 0.0
var split_count := 0
var split_spread := 70.0
var split_tex: Texture2D
var _age := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
var _circle := CircleShape2D.new()
## 子彈光暈（玩家：往後拉長的拖尾；敵人：圓形光暈），共用貼圖與材質，可合批繪製
var _glow: Sprite2D
var _col := Color.WHITE
static var _add_mat: CanvasItemMaterial


func _ready() -> void:
	shape.shape = _circle
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = Sprite2D.new()
	_glow.texture = NeonFx.get_glow_tex()
	_glow.material = _add_mat
	_glow.show_behind_parent = true
	sprite.add_child(_glow)
	area_entered.connect(_on_area_entered)
	_set_active(false)


func activate(pos: Vector2, vel: Vector2, tex: Texture2D, radius: float, dmg: int, player_owned: bool) -> void:
	global_position = pos
	velocity = vel
	damage = dmg
	is_player_bullet = player_owned
	# 圖層：玩家子彈在 Boss 上面；敵彈在 Boss 下面（看起來從 Boss 底下射出）
	z_index = 4 if player_owned else 0
	pierce = false
	homing = 0.0
	_target = null
	_retarget = 0.0
	splash_radius = 0.0
	splash_damage = 0
	split_time = 0.0
	split_count = 0
	_age = 0.0
	_hit_ids.clear()
	sprite.texture = tex
	sprite.rotation = vel.angle() + PI / 2.0  # 圖片朝上
	_circle.radius = radius
	_col = NeonFx.tex_color(tex)
	if player_owned:
		# 拖尾：沿飛行方向往後拉長（貼圖朝上，所以往 +y 延伸）
		var h: float = tex.get_height() if tex else 30.0
		_glow.scale = Vector2(maxf(radius, 5.0) * 2.4 / 64.0, h * 2.6 / 64.0)
		_glow.position = Vector2(0, h * 0.75)
		_glow.modulate = Color(_col.r, _col.g, _col.b, 0.55)
	else:
		_glow.scale = Vector2.ONE * radius * 4.2 / 64.0
		_glow.position = Vector2.ZERO
		_glow.modulate = Color(1.0, 0.3, 0.8, 0.55)
	collision_layer = LAYER_PLAYER_BULLET if player_owned else LAYER_ENEMY_BULLET
	collision_mask = MASK_ENEMY if player_owned else 0
	_set_active(true)


func release() -> void:
	if not active:
		return
	_set_active(false)
	if BulletPool.instance:
		BulletPool.instance.recycle(self)


func _set_active(value: bool) -> void:
	active = value
	visible = value
	set_physics_process(value)
	shape.set_deferred("disabled", not value)
	set_deferred("monitoring", value and is_player_bullet)


func _physics_process(delta: float) -> void:
	if homing > 0.0:
		_steer(delta)
	position += velocity * delta
	if split_count > 0:
		_age += delta
		if _age >= split_time:
			_split()
			return
	if not get_viewport_rect().grow(SCREEN_MARGIN).has_point(global_position):
		release()


func _on_area_entered(area: Area2D) -> void:
	if active and is_player_bullet and area is Enemy:
		if pierce:
			var id := area.get_instance_id()
			if id in _hit_ids:
				return
			_hit_ids.append(id)
			(area as Enemy).take_damage(damage)
			if NeonFx.instance:
				NeonFx.instance.impact(global_position, _col)
			return
		(area as Enemy).take_damage(damage)
		if splash_radius > 0.0:
			_splash(area as Enemy)
		elif NeonFx.instance and randf() < 0.6:
			NeonFx.instance.impact(global_position, _col)
		release()


## 追蹤：轉向最近的畫面內敵人
func _steer(delta: float) -> void:
	_retarget -= delta
	if _target == null or not is_instance_valid(_target) or _target.health.dead or _retarget <= 0.0:
		_retarget = 0.25
		_target = null
		var best := 900.0
		for node in get_tree().get_nodes_in_group(&"enemies"):
			var e := node as Enemy
			if e == null or e.health.dead or not e.is_on_screen() or e.is_hazard():
				continue
			var d := global_position.distance_to(e.aim_point())
			if d < best:
				best = d
				_target = e
	if _target:
		var want := (_target.aim_point() - global_position).angle()
		var cur := velocity.angle()
		var ang := cur + clampf(wrapf(want - cur, -PI, PI), -homing * delta, homing * delta)
		velocity = Vector2.RIGHT.rotated(ang) * velocity.length()
		sprite.rotation = ang + PI / 2.0


## 爆裂：傷害周圍的敵人
func _splash(hit: Enemy) -> void:
	if NeonFx.instance:
		NeonFx.instance.explode(global_position, splash_radius / 90.0)
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var e := node as Enemy
		if e == null or e == hit or e.health.dead:
			continue
		if e.global_position.distance_to(global_position) <= splash_radius + e.aim_radius():
			e.take_damage(splash_damage)


func _split() -> void:
	var n := split_count
	var tex := split_tex
	var spd := velocity.length() * 1.1
	var dir := velocity.normalized()
	var at := global_position
	var dmg := damage
	split_count = 0
	release()
	if NeonFx.instance:
		NeonFx.instance.impact(at, Color(0.5, 1.0, 0.4))
	for d in BulletPattern.fan(dir, n, split_spread):
		BulletPool.instance.spawn(at, d * spd, tex, 6.0, dmg, false)
