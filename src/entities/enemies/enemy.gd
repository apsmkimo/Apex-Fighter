class_name Enemy
extends Area2D
## 通用敵機：外觀、血量、移動、攻擊全部由 EnemyData 決定。
## 有特殊行為的敵機可以繼承這個類別（Boss 就是這樣做的）。

const SCREEN_MARGIN := 140.0
const MAX_LIFETIME := 60.0

## 移動時間倍率（一般敵人較慢，停留更久；Boss = 1）
var move_time_scale := 1.0
var data: EnemyData
var movement: MovePattern
var spawn_pos := Vector2.ZERO
var flip_x := false
var age := 0.0

var _was_on_screen := false
var _flash := 0.0
var _shake_cd := 0.0
## 危險物（水雷、飛彈）用
var velocity := Vector2.ZERO
var _hazard_done := false
var _drop_cd := 0.0
## 地面砲台：停在這個高度（INF = 一路跟著地表捲走）
var ground_stop_y := INF
var ground_stopped := false
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
	# 多個發光弱點：每個弱點各一個碰撞圓
	if data.weak_radius > 0.0:
		for off in data.extra_weak_offsets:
			var cs := CollisionShape2D.new()
			var c2 := CircleShape2D.new()
			c2.radius = data.weak_radius
			cs.shape = c2
			cs.position = off
			add_child(cs)
	_drop_cd = data.drop_hazard_first
	var diff := GameManager.difficulty
	var base_hp := diff.scale_hp(data.max_hp) if diff else data.max_hp
	var defense := 1.0 if self is Boss else GameManager.ENEMY_DEFENSE_MULT
	health.setup(int(round(base_hp * GameManager.enemy_hp_mult * defense)))
	if data.ground:
		z_index = -5
	if not self is Boss:
		move_time_scale = GameManager.ENEMY_MOVE_TIME_SCALE
	health.died.connect(_on_died)
	var fire_iv := (diff.scale_interval(data.fire_interval) if diff else data.fire_interval) * GameManager.ENEMY_FIRE_INTERVAL_MULT
	emitter.configure(data.bullet_pattern, fire_iv, data.first_fire_delay)
	emitter.enabled = false
	emitter.bullet_damage = data.bullet_damage
	# 開火音效：依敵人大小分小兵／中兵／大兵（Boss 用中兵聲，避免太吵）
	if self is Boss:
		emitter.sfx_size = 1
	elif data.max_hp < 10:
		emitter.sfx_size = 0
	elif data.max_hp < 30 and data.explosion_scale < 1.7:
		emitter.sfx_size = 1
	else:
		emitter.sfx_size = 2
	if data.bank_amount > 0.0 or not data.thruster_offsets.is_empty():
		# 敵機機頭朝下
		FlightVisual.attach(self, sprite, Vector2.DOWN, data.bank_amount, data.flight_ref_speed,
				data.thruster_offsets, data.thruster_color, data.thruster_width, data.thruster_length)


func _physics_process(delta: float) -> void:
	age += delta
	if is_hazard():
		_hazard_process(delta)
		return
	if data.drop_hazard and is_on_screen() and global_position.y < get_viewport_rect().size.y * 0.7:
		_drop_cd -= delta
		if _drop_cd <= 0.0:
			_drop_cd = data.drop_hazard_interval
			var h := spawn_enemy(data.drop_hazard, global_position + Vector2(0, 30), get_parent())
			if h:
				h.velocity = Vector2(randf_range(-40.0, 40.0), 110.0)
	if data.ground:
		_ground_process(delta)
	elif movement:
		var off := movement.offset_at(age * move_time_scale)
		if flip_x:
			off.x = -off.x
		position = spawn_pos + off
	if data.spin != 0.0:
		sprite.rotation += data.spin * delta * (-1.0 if flip_x else 1.0)
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


## 所有可以打的位置（多弱點用；雷射會找對得到的那一個）
func aim_points() -> Array[Vector2]:
	var out: Array[Vector2] = [aim_point()]
	if data.weak_radius > 0.0:
		for off in data.extra_weak_offsets:
			out.append(global_position + off)
	return out


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
	health.take_damage(GameManager.scale_player_damage(amount))


## 只有在畫面內、而且離玩家不會太近時才開火（避免貼臉彈）。
func _can_fire() -> bool:
	return is_on_screen() and global_position.y < get_viewport_rect().size.y * 0.75


func _can_despawn() -> bool:
	return true


func _on_died() -> void:
	if is_hazard():
		# 被玩家打中紅點／藍點 → 原地爆炸，順便炸傷附近的敵人
		GameManager.add_score(data.score)
		_explode(true)
		return
	GameManager.add_score(data.score)
	Events.enemy_killed.emit(data, global_position)
	_try_drop()
	if data.death_spawn:
		if data.death_spawn_count > 1:
			_split_on_death.call_deferred(data.death_spawn, data.death_spawn_count, global_position, get_parent())
		else:
			_spawn_on_death.call_deferred(data.death_spawn, global_position, get_parent())
	if data.ground and not data.death_decals.is_empty():
		GroundDecal.spawn(data.death_decals.pick_random(), global_position, get_parent())
	queue_free()


## 碎裂：生出 count 個碎片，左右交替散開
static func _split_on_death(d: EnemyData, count: int, pos: Vector2, parent: Node) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	for i in count:
		var e := (load("res://src/entities/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
		var side := -1.0 if i % 2 == 0 else 1.0
		e.setup(d, pos + Vector2(side * (12.0 + 10.0 * i), randf_range(-12.0, 12.0)), null, side < 0.0)
		parent.add_child(e)


## 在 parent 底下生出一隻敵機（危險物也用這個）
static func spawn_enemy(d: EnemyData, pos: Vector2, parent: Node) -> Enemy:
	if d == null or parent == null or not is_instance_valid(parent):
		return null
	var e := (load("res://src/entities/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	e.setup(d, pos)
	parent.add_child(e)
	return e


static func _spawn_on_death(d: EnemyData, pos: Vector2, parent: Node) -> void:
	if spawn_enemy(d, pos, parent) == null:
		return
	if NeonFx.instance:
		NeonFx.instance.float_text(pos + Vector2(0, -40), "EJECT!", Color(1.0, 0.35, 0.3))


func _try_drop() -> void:
	if data.drop_item and randf() < data.drop_chance:
		Item.spawn(data.drop_item, global_position, get_parent())
	if not data.bonus_pool.is_empty() and randf() < data.bonus_chance:
		var bonus := GameManager.next_drop(data.id, data.bonus_pool) as ItemData
		if bonus:
			Item.spawn(bonus, global_position + Vector2(randf_range(-30, 30), -20), get_parent())


# ---------- 危險物：太空水雷、敵方追蹤飛彈 ----------

func is_hazard() -> bool:
	return data != null and data.hazard_kind != &""


func _hazard_process(delta: float) -> void:
	if _hazard_done:
		return
	emitter.enabled = false
	var p := Player.instance
	var target := p.global_position if p and p.alive else global_position + Vector2(0, 400)
	match data.hazard_kind:
		&"mine":
			# 慢慢往下飄，左右輕微擺動
			velocity = velocity.move_toward(Vector2(0, 55), 60.0 * delta)
			position += (velocity + Vector2(sin(age * 1.7) * 18.0, 0)) * delta
			sprite.rotation += delta * 0.6
			if p and p.alive and global_position.distance_to(p.global_position) < data.trigger_radius:
				_explode(false)
				return
		&"missile":
			if velocity == Vector2.ZERO:
				velocity = Vector2.DOWN * data.home_speed
			var want := (target - global_position).angle()
			var cur := velocity.angle()
			var diff := wrapf(want - cur, -PI, PI)
			cur += clampf(diff, -data.home_turn * delta, data.home_turn * delta)
			velocity = Vector2.RIGHT.rotated(cur) * data.home_speed
			position += velocity * delta
			rotation = cur
			if NeonFx.instance and Engine.get_physics_frames() % 3 == 0:
				NeonFx.instance.emit(global_position - velocity.normalized() * 40.0, -velocity * 0.2, 0.35, 5.0, Color(0.3, 0.8, 1.0))
			if p and p.alive and global_position.distance_to(p.global_position) < 34.0:
				_explode(false)
				return
			if age > data.home_life:
				_explode(false)
				return
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(2.5, 2.5, 2.5) if _flash > 0.0 else Color.WHITE
	if not get_viewport_rect().grow(SCREEN_MARGIN).has_point(global_position) and age > 1.0:
		queue_free()


## 爆炸：範圍內的戰機受傷；by_player = 被玩家打爆，會炸傷附近敵人
func _explode(by_player: bool) -> void:
	if _hazard_done:
		return
	_hazard_done = true
	var at := global_position
	if NeonFx.instance:
		NeonFx.instance.explode(at, data.explosion_scale)
		NeonFx.instance.ring(at, 10.0, data.blast_radius, 0.35, Color(1.0, 0.45, 0.3), 5.0)
	Events.screen_shake.emit(6.0, 0.2)
	var p := Player.instance
	if p and p.alive and at.distance_to(p.global_position) < data.blast_radius:
		p.take_hit(data.blast_damage)
	if data.blast_ring > 0 and BulletPool.instance and not by_player:
		var tex := load("res://assets/sprites/bullets/enemy_orb.png") as Texture2D
		for i in data.blast_ring:
			var dir := Vector2.DOWN.rotated(TAU * i / data.blast_ring + age)
			BulletPool.instance.spawn(at, dir * 210.0, tex, 7.0, 2, false)
	if by_player:
		for node in get_tree().get_nodes_in_group(&"enemies"):
			var e := node as Enemy
			if e == null or e == self or e.health.dead or e is Boss:
				continue
			if e.global_position.distance_to(at) < data.blast_radius + e.data.hit_radius:
				e.take_damage(data.blast_enemy_damage)
	queue_free()


# ---------- 地面砲台 ----------

func _ground_process(delta: float) -> void:
	if not ground_stopped:
		position.y += ScrollBackground.ground_speed * delta
		if position.y >= ground_stop_y:
			position.y = ground_stop_y
			ground_stopped = true
	if data.aim_rotate:
		var p := Player.instance
		if p and p.alive:
			var want := (p.global_position - global_position).angle() + PI / 2.0 - deg_to_rad(data.aim_offset_deg)
			sprite.rotation = lerp_angle(sprite.rotation, want, minf(1.0, 4.0 * delta))
	else:
		sprite.rotation += delta * data.ground_spin
