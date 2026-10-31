class_name Player
extends Area2D
## 玩家戰機。外觀、速度、判定、武器都來自 ShipData，所以換機體不用改這支程式。
## 操作：手指在畫面任意位置拖曳＝相對移動；自動連射；炸彈按鈕或 X 鍵。

static var instance: Player

const INVINCIBLE_TIME := 2.5
const EDGE := Vector2(24, 40)

var ship: ShipData
var alive := false
var invincible := 0.0
var _entering := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt_shape: CollisionShape2D = $CollisionShape2D
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var weapon: Weapon = $Weapon


## 在 add_child 之前呼叫。
func setup(ship_data: ShipData) -> void:
	ship = ship_data


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	sprite.texture = ship.texture
	var hurt := CircleShape2D.new()
	hurt.radius = ship.hitbox_radius
	hurt_shape.shape = hurt
	var pick := CircleShape2D.new()
	pick.radius = ship.pickup_radius
	pickup_shape.shape = pick
	weapon.data = ship.weapon
	weapon.level = GameManager.power_level
	area_entered.connect(_on_hurt)
	pickup_area.area_entered.connect(_on_pickup)
	Events.power_changed.connect(_on_power_changed)
	_spawn_in()


func _unhandled_input(event: InputEvent) -> void:
	if not alive or _entering:
		return
	if event is InputEventScreenDrag:
		position += (event as InputEventScreenDrag).relative * ship.touch_sensitivity
		_clamp()
	elif event.is_action_pressed(&"bomb"):
		use_bomb()


func _physics_process(delta: float) -> void:
	if alive and not _entering:
		var dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if dir != Vector2.ZERO:
			position += dir * ship.speed * delta
			_clamp()
	if invincible > 0.0:
		invincible -= delta
		sprite.visible = int(invincible * 20.0) % 2 == 0
	elif alive:
		sprite.visible = true


func use_bomb() -> void:
	if not alive or _entering or not GameManager.use_bomb():
		return
	invincible = maxf(invincible, 1.5)
	if BulletPool.instance:
		BulletPool.instance.clear_enemy_bullets()
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var e := node as Enemy
		if e and e.is_on_screen():
			e.take_damage(ship.bomb_damage)
	Events.bomb_used.emit(global_position)
	Events.screen_shake.emit(16.0, 0.5)


func _clamp() -> void:
	var size := get_viewport_rect().size
	position = position.clamp(EDGE, size - EDGE)


func _on_power_changed(level: int, _max_level: int) -> void:
	weapon.level = level


func _on_hurt(area: Area2D) -> void:
	if not alive or invincible > 0.0:
		return
	if area is Bullet and not (area as Bullet).is_player_bullet:
		(area as Bullet).release()
		_die()
	elif area is Enemy:
		_die()


func _on_pickup(area: Area2D) -> void:
	if alive and area is Item:
		(area as Item).collect()


func _die() -> void:
	alive = false
	weapon.firing = false
	sprite.visible = false
	Events.player_hit.emit()
	Events.screen_shake.emit(14.0, 0.5)
	if BulletPool.instance:
		BulletPool.instance.clear_enemy_bullets()
	if GameManager.lose_life():
		await get_tree().create_timer(1.2).timeout
		_spawn_in()
	else:
		Events.game_over.emit()


## 從畫面下方飛進來，期間無敵。
func _spawn_in() -> void:
	var size := get_viewport_rect().size
	position = Vector2(size.x / 2.0, size.y + 80.0)
	alive = true
	_entering = true
	invincible = INVINCIBLE_TIME
	weapon.firing = false
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2(size.x / 2.0, size.y - 220.0), 0.7) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	_entering = false
	weapon.firing = true
	Events.player_respawned.emit()
