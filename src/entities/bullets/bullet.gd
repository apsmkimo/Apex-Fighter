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

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
var _circle := CircleShape2D.new()


func _ready() -> void:
	shape.shape = _circle
	area_entered.connect(_on_area_entered)
	_set_active(false)


func activate(pos: Vector2, vel: Vector2, tex: Texture2D, radius: float, dmg: int, player_owned: bool) -> void:
	global_position = pos
	velocity = vel
	damage = dmg
	is_player_bullet = player_owned
	sprite.texture = tex
	sprite.rotation = vel.angle() + PI / 2.0  # 圖片朝上
	_circle.radius = radius
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
	position += velocity * delta
	if not get_viewport_rect().grow(SCREEN_MARGIN).has_point(global_position):
		release()


func _on_area_entered(area: Area2D) -> void:
	if active and is_player_bullet and area is Enemy:
		(area as Enemy).take_damage(damage)
		release()
