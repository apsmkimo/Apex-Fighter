class_name Enemy
extends Area2D
## 通用敵機：外觀、血量、移動、攻擊全部由 EnemyData 決定。
## 有特殊行為的敵機可以繼承這個類別（Boss 就是這樣做的）。

const SCREEN_MARGIN := 140.0
const MAX_LIFETIME := 40.0

var data: EnemyData
var movement: MovePattern
var spawn_pos := Vector2.ZERO
var flip_x := false
var age := 0.0

var _was_on_screen := false
var _flash := 0.0
var _shake_cd := 0.0
## 血量達到這個值以上的敵機，被打中時畫面會輕微震動
const BIG_ENEMY_HP := 30

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var health: HealthComponent = $HealthComponent
@onready var emitter: BulletEmitter = $BulletEmitter


## 在 add_child 之前呼叫。
func setup(enemy_data: EnemyData, pos: Vector2, move_override: MovePattern = null, mirrored := false) -> void:
	data = enemy_data
	spawn_pos = pos
	movement = move_override if move_override else enemy_data.movement
	flip_x = mirrored
	position = pos


func _ready() -> void:
	add_to_group(&"enemies")
	sprite.texture = data.texture
	var circle := CircleShape2D.new()
	circle.radius = data.hit_radius
	# 有弱點的敵人：碰撞範圍只剩發光核心，子彈會穿過裝甲、只有打中核心才算
	if data.weak_radius > 0.0:
		circle.radius = data.weak_radius
		shape.position = data.weak_offset
	shape.shape = circle
	var diff := GameManager.difficulty
	var base_hp := diff.scale_hp(data.max_hp) if diff else data.max_hp
	health.setup(int(round(base_hp * GameManager.enemy_hp_mult)))
	health.died.connect(_on_died)
	emitter.configure(data.bullet_pattern, diff.scale_interval(data.fire_interval) if diff else data.fire_interval, data.first_fire_delay)
	emitter.enabled = false
	emitter.bullet_damage = data.bullet_damage
	if data.bank_amount > 0.0 or not data.thruster_offsets.is_empty():
		# 敵機機頭朝下
		FlightVisual.attach(self, sprite, Vector2.DOWN, data.bank_amount, data.flight_ref_speed,
				data.thruster_offsets, data.thruster_color, data.thruster_width, data.thruster_length)


func _physics_process(delta: float) -> void:
	age += delta
	if movement:
		var off := movement.offset_at(age)
		if flip_x:
			off.x = -off.x
		position = spawn_pos + off
	var on := is_on_screen()
	if on:
		_was_on_screen = true
	emitter.enabled = _can_fire()
	_shake_cd -= delta
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(2.5, 2.5, 2.5) if _flash > 0.0 else Color.WHITE
	if _can_despawn() and ((_was_on_screen and not get_viewport_rect().grow(SCREEN_MARGIN).has_point(global_position)) or age > MAX_LIFETIME):
		queue_free()


func is_on_screen() -> bool:
	return get_viewport_rect().has_point(global_position)


## 武器瞄準的位置：有弱點就是弱點
func aim_point() -> Vector2:
	return global_position + data.weak_offset if data.weak_radius > 0.0 else global_position


func aim_radius() -> float:
	return data.weak_radius if data.weak_radius > 0.0 else data.hit_radius


func has_weak_point() -> bool:
	return data.weak_radius > 0.0


func take_damage(amount: int) -> void:
	if health.dead:
		return
	# SMCPKG_SUPPORT>>>CursorM9Hit
	Events.enemy_damaged.emit(global_position)
	# SMCPKG_SUPPORT<<<CursorM9HitEnd
	_flash = 0.05
	if data.max_hp >= BIG_ENEMY_HP and _shake_cd <= 0.0:
		_shake_cd = 0.18
		Events.screen_shake.emit(2.5, 0.08)
	health.take_damage(amount)


## 只有在畫面內、而且離玩家不會太近時才開火（避免貼臉彈）。
func _can_fire() -> bool:
	return is_on_screen() and global_position.y < get_viewport_rect().size.y * 0.75


func _can_despawn() -> bool:
	return true


func _on_died() -> void:
	GameManager.add_score(data.score)
	Events.enemy_killed.emit(data, global_position)
	_try_drop()
	if data.death_spawn:
		_spawn_on_death.call_deferred(data.death_spawn, global_position, get_parent())
	queue_free()


static func _spawn_on_death(d: EnemyData, pos: Vector2, parent: Node) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var e := (load("res://src/entities/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	e.setup(d, pos)
	parent.add_child(e)
	if NeonFx.instance:
		NeonFx.instance.float_text(pos + Vector2(0, -40), "EJECT!", Color(1.0, 0.35, 0.3))


func _try_drop() -> void:
	if data.drop_item and randf() < data.drop_chance:
		Item.spawn(data.drop_item, global_position, get_parent())
	if not data.bonus_pool.is_empty() and randf() < data.bonus_chance:
		var bonus := GameManager.next_drop(data.id, data.bonus_pool) as ItemData
		if bonus:
			Item.spawn(bonus, global_position + Vector2(randf_range(-30, 30), -20), get_parent())
