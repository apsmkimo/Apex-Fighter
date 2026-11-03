class_name Player
extends Area2D
## 玩家戰機。外觀、速度、判定、武器都來自 ShipData，所以換機體不用改這支程式。
## 操作：手指在畫面任意位置拖曳＝相對移動；自動連射；炸彈按鈕或 X 鍵。

static var instance: Player

const INVINCIBLE_TIME := 2.5
## 被打中但沒死時的短暫無敵，避免同一波子彈連續扣血
const HIT_INVINCIBLE := 1.0
const SHIELD_TIME := 20.0
const EDGE := Vector2(24, 40)

var ship: ShipData
var alive := false
var invincible := 0.0
var hp := 6
var max_hp := 6
## 護盾剩餘秒數，> 0 時可抵銷一次攻擊
var shield := 0.0
var _shield_fx: Node2D
var _aura: PowerAura
## 被 Boss 絲網黏住的剩餘秒數（> 0 時不能移動，左右滑動可以加速掙脫）
var webbed := 0.0
var _web_fx: WebFx
var _exhaust_timer := 0.0
var _last_pos := Vector2.ZERO
var _entering := false

var _pylons: MissilePylons
@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt_shape: CollisionShape2D = $CollisionShape2D
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_shape: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var weapon: Weapon = $Weapon
@onready var missiles: MissileLauncher = $MissileLauncher


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
	weapon.data = GameManager.weapon if GameManager.weapon else ship.weapon
	weapon.level = GameManager.power_level
	missiles.level = GameManager.missile_level
	Events.weapon_changed.connect(func(w: Resource) -> void: weapon.data = w as WeaponData)
	Events.missile_changed.connect(func(lv: int) -> void: missiles.level = lv)
	# 機翼掛載飛彈：導彈等級越高掛越多（每邊最多 3 枚），顏色依戰機
	_pylons = MissilePylons.new()
	_pylons.tex = MissilePylons.texture_for(ship)
	_pylons.hull = ship.texture.get_size() if ship.texture else Vector2(80, 100)
	_pylons.count = GameManager.missile_level
	sprite.add_child(_pylons)
	Events.missile_changed.connect(func(lv: int) -> void: _pylons.count = lv)
	FlightVisual.attach(self, sprite, Vector2.UP, ship.bank_amount, maxf(ship.speed * 0.8, 300.0),
			ship.thruster_offsets, ship.thruster_color, ship.thruster_width, ship.thruster_length)
	max_hp = ship.max_hp
	_shield_fx = ShieldFx.new()
	add_child(_shield_fx)
	# 火力等級光效
	_aura = PowerAura.new()
	_aura.color = ship.ui_glow
	_aura.hull = ship.texture.get_size() if ship.texture else Vector2(64, 100)
	_aura.level = GameManager.power_level
	add_child(_aura)
	_web_fx = WebFx.new()
	add_child(_web_fx)
	area_entered.connect(_on_hurt)
	pickup_area.area_entered.connect(_on_pickup)
	Events.power_changed.connect(_on_power_changed)
	_spawn_in()


func _unhandled_input(event: InputEvent) -> void:
	if not alive or _entering:
		return
	if event is InputEventScreenDrag:
		var rel := (event as InputEventScreenDrag).relative
		if webbed > 0.0:
			_struggle(rel.length())
			return
		position += rel * ship.touch_sensitivity
		_clamp()
	elif event.is_action_pressed(&"bomb"):
		use_bomb()


func _physics_process(delta: float) -> void:
	if alive and not _entering:
		var dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if webbed > 0.0:
			if Input.is_action_just_pressed(&"move_left") or Input.is_action_just_pressed(&"move_right"):
				_struggle(60.0)
			dir = Vector2.ZERO
		if dir != Vector2.ZERO:
			position += dir * ship.speed * delta
			_clamp()
	if shield > 0.0:
		var before := int(ceil(shield))
		shield = maxf(shield - delta, 0.0)
		if int(ceil(shield)) != before:
			Events.shield_changed.emit(shield)
	if webbed > 0.0:
		webbed = maxf(webbed - delta, 0.0)
	_web_fx.left = webbed if alive else 0.0
	_shield_fx.visible = shield > 0.0 and alive
	_aura.visible = alive and sprite.visible and _aura.level > 0
	_emit_exhaust(delta)
	_shield_fx.set_meta(&"left", shield)
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
	Events.bomb_used.emit(global_position)  # 關卡會產生全螢幕火焰
	Events.screen_shake.emit(16.0, 0.5)


func _clamp() -> void:
	var size := get_viewport_rect().size
	position = position.clamp(EDGE, size - EDGE)


func _on_power_changed(level: int, _max_level: int) -> void:
	weapon.level = level
	if _aura:
		_aura.level = level


func _on_hurt(area: Area2D) -> void:
	if not alive or invincible > 0.0:
		return
	if area is Bullet and not (area as Bullet).is_player_bullet:
		var b := area as Bullet
		b.release()
		take_hit(b.damage)
	elif area is Enemy and not (area as Enemy).is_hazard():
		take_hit((area as Enemy).data.contact_damage)


## 受到攻擊：先由護盾抵銷，再扣血，血量歸零才失去一條命。
func take_hit(amount: int) -> void:
	if not alive or _entering or invincible > 0.0:
		return
	if shield > 0.0:
		shield = 0.0
		invincible = 0.6
		Events.shield_changed.emit(0.0)
		Events.shield_blocked.emit(global_position)
		Events.screen_shake.emit(6.0, 0.2)
		return
	hp = maxi(hp - maxi(amount, 1), 0)
	Events.player_hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()
	else:
		invincible = HIT_INVINCIBLE
		# SMCPKG_SUPPORT>>>CursorM9Hurt
		Events.player_hurt.emit()
		# SMCPKG_SUPPORT<<<CursorM9HurtEnd
		Events.screen_shake.emit(8.0, 0.25)
		if NeonFx.instance:
			NeonFx.instance.hurt_burst(global_position)


## 引擎尾焰粒子：往前飛時噴得多又長，後退時幾乎沒有。每台引擎每 2~3 幀一顆，粒子量很低。
func _emit_exhaust(delta: float) -> void:
	var vel := (global_position - _last_pos) / maxf(delta, 0.001)
	_last_pos = global_position
	if not alive or not sprite.visible or NeonFx.instance == null or ship.thruster_offsets.is_empty():
		return
	_exhaust_timer -= delta
	if _exhaust_timer > 0.0:
		return
	var forward := clampf(-vel.y / maxf(ship.speed, 1.0), -1.0, 1.0)   # 1 = 全速往前
	_exhaust_timer = 0.045 if forward > 0.2 else 0.07
	if forward < -0.5:
		return
	var side := clampf(vel.x / maxf(ship.speed, 1.0), -1.0, 1.0)
	for off in ship.thruster_offsets:
		var v := Vector2(-side * 60.0 + randf_range(-25, 25), 220.0 + 260.0 * maxf(forward, 0.0))
		NeonFx.instance.emit(global_position + off + Vector2(0, 6), v, randf_range(0.18, 0.3),
				ship.thruster_width * 0.5, ship.thruster_color, NeonFx.Kind.DOT, 2.0)


## 被絲網黏住：護盾可以擋掉；否則 sec 秒內不能移動（仍會自動開火）
func apply_web(sec: float) -> void:
	if not alive or _entering:
		return
	if shield > 0.0:
		shield = 0.0
		Events.shield_changed.emit(0.0)
		Events.shield_blocked.emit(global_position)
		return
	webbed = maxf(webbed, sec)
	Events.screen_shake.emit(5.0, 0.2)
	if NeonFx.instance:
		NeonFx.instance.float_text(global_position + Vector2(0, -70), "STUCK! SWIPE!", Color(0.85, 0.88, 1.0))


## 左右亂滑可以提早掙脫絲網
func _struggle(amount: float) -> void:
	webbed = maxf(webbed - amount / 900.0, 0.0)


func add_shield() -> void:
	shield = SHIELD_TIME
	Events.shield_changed.emit(shield)


func _on_pickup(area: Area2D) -> void:
	if alive and area is Item:
		(area as Item).collect()


func _die() -> void:
	alive = false
	webbed = 0.0
	shield = 0.0
	Events.shield_changed.emit(0.0)
	weapon.firing = false
	missiles.firing = false
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
	hp = max_hp
	Events.player_hp_changed.emit(hp, max_hp)
	_entering = true
	invincible = INVINCIBLE_TIME
	weapon.firing = false
	missiles.firing = false
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2(size.x / 2.0, size.y - 220.0), 0.7) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	_entering = false
	weapon.firing = true
	missiles.firing = true
	Events.player_respawned.emit()


## 護盾外觀：藍色六角能量罩，最後 3 秒閃爍
class ShieldFx extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		z_index = 2
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		visible = false

	func _process(delta: float) -> void:
		_t += delta
		if visible:
			queue_redraw()

	func _draw() -> void:
		var left: float = get_meta(&"left", 0.0)
		var a := 1.0
		if left < 3.0:
			a = 0.35 + 0.65 * float(int(_t * 10.0) % 2)
		var r := 58.0 + 3.0 * sin(_t * 6.0)
		draw_circle(Vector2.ZERO, r, Color(0.2, 0.6, 1.0, 0.12 * a))
		var pts := PackedVector2Array()
		for i in 7:
			var ang := _t * 0.8 + i * TAU / 6.0
			pts.append(Vector2(cos(ang), sin(ang)) * r)
		draw_polyline(pts, Color(0.4, 0.85, 1.0, 0.8 * a), 3.0, true)
		draw_arc(Vector2.ZERO, r - 6.0, 0, TAU, 40, Color(0.5, 0.9, 1.0, 0.35 * a), 2.0, true)


## 絲網外觀：黏在機身上的白色蛛網，快掙脫時變淡
class WebFx extends Node2D:
	var left := 0.0:
		set(v):
			left = v
			visible = v > 0.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 3
		visible = false

	func _process(delta: float) -> void:
		_t += delta
		if visible:
			queue_redraw()

	func _draw() -> void:
		var a := clampf(left / 1.2, 0.25, 0.9)
		var col := Color(0.9, 0.92, 1.0, a)
		var r := 46.0 + 2.0 * sin(_t * 12.0)   # 輕微抖動，表示在掙扎
		for i in 10:
			var ang := TAU * i / 10.0 + 0.15
			draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(ang) * r, col, 1.6)
		for ring in 3:
			var rr := r * (0.35 + 0.28 * ring)
			var pts := PackedVector2Array()
			for i in 11:
				pts.append(Vector2.RIGHT.rotated(TAU * i / 10.0 + 0.15) * rr * (0.92 + 0.08 * (i % 2)))
			draw_polyline(pts, col, 1.4)


## 機翼下的掛載飛彈
class MissilePylons extends Node2D:
	const MAX_PER_SIDE := 3
	const TEX_RED := preload("res://assets/sprites/player/pylon_missile_red.png")
	const TEX_YELLOW := preload("res://assets/sprites/player/pylon_missile_yellow.png")
	const TEX_SILVER := preload("res://assets/sprites/player/pylon_missile_silver.png")
	var tex: Texture2D
	var hull := Vector2(80, 100)
	var count := 0:
		set(v):
			count = v
			queue_redraw()

	static func texture_for(s: ShipData) -> Texture2D:
		match s.id:
			&"phoenix":
				return TEX_RED
			&"thunderbird":
				return TEX_YELLOW
		return TEX_SILVER

	func _draw() -> void:
		var per_side := mini(count, MAX_PER_SIDE)
		if per_side <= 0 or tex == null:
			return
		var sz := tex.get_size() * (hull.y * 0.36 / tex.get_size().y)
		for k in per_side:
			var x := hull.x * 0.17 + k * maxf(sz.x * 1.25, hull.x * 0.1)
			var y := hull.y * 0.08 + k * 4.0
			for side: float in [-1.0, 1.0]:
				var r := Rect2(Vector2(side * x - sz.x * 0.5, y - sz.y * 0.5), sz)
				draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.25))
				draw_texture_rect(tex, r, false)
