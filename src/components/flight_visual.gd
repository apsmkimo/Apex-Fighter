class_name FlightVisual
extends Node
## 飛行外觀：依照實際移動速度做「機身左右傾斜」與「引擎火焰大小」。
## 只改外觀，不影響判定。玩家與 Boss 共用；設定來自 ShipData / EnemyData。
##   左右移動 → 機身橫向壓窄＋斜切＋明暗（假 3D 翻滾），外側引擎火焰變大
##   往前移動 → 引擎火焰拉長變亮
##   往後移動 → 引擎熄火，只剩餘光

const SHADER := preload("res://assets/shaders/bank_shade.gdshader")

var body: Node2D
var sprite: Sprite2D
## 機頭方向（玩家朝上、Boss 朝下）
var forward := Vector2.UP
## 傾斜幅度，0 = 不傾斜
var bank_amount := 1.0
## 多快的速度算「全力」（像素/秒）
var ref_speed := 500.0
var thrusters: Array[Thruster] = []

var bank := 0.0
var throttle := 1.0
var _offsets: PackedVector2Array
var _last_pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _mat: ShaderMaterial
var _base_scale := Vector2.ONE


## 建立並掛到 body 底下。offsets 是每個引擎口相對機身中心的位置。
static func attach(owner_body: Node2D, owner_sprite: Sprite2D, fwd: Vector2, amount: float, speed_ref: float,
		offsets: PackedVector2Array, color: Color, width: float, length: float) -> FlightVisual:
	var fv := FlightVisual.new()
	fv.body = owner_body
	fv.sprite = owner_sprite
	fv.forward = fwd.normalized()
	fv.bank_amount = amount
	fv.ref_speed = speed_ref
	fv._offsets = offsets
	for o in offsets:
		var t := Thruster.new()
		t.color = color
		t.width = width
		t.length = length
		t.direction = -fv.forward
		t.position = o
		owner_body.add_child(t)
		fv.thrusters.append(t)
	owner_body.add_child(fv)
	return fv


func _ready() -> void:
	_last_pos = body.global_position
	_base_scale = sprite.scale
	if bank_amount > 0.0:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		sprite.material = _mat


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var v := (body.global_position - _last_pos) / delta
	_last_pos = body.global_position
	if v.length() > ref_speed * 6.0:
		v = Vector2.ZERO  # 瞬間移位（重生等）不算
	_vel = _vel.lerp(v, 1.0 - exp(-delta * 12.0))

	# 左右傾斜：以機頭方向的右側為正
	var right := Vector2(-forward.y, forward.x)
	var side := clampf(_vel.dot(right) / ref_speed, -1.0, 1.0)
	var target_bank := side * bank_amount
	var rate := 10.0 if absf(target_bank) > absf(bank) else 5.0   # 回正慢一點，比較有重量感
	bank = lerpf(bank, target_bank, 1.0 - exp(-delta * rate))
	if bank_amount > 0.0:
		# 機頭朝下的 Boss，畫面上的左右跟機身的左右相反
		var screen_bank := bank * (1.0 if forward.y <= 0.0 else -1.0)
		sprite.scale = Vector2(_base_scale.x * (1.0 - absf(bank) * 0.22), _base_scale.y)
		sprite.skew = screen_bank * 0.10
		_mat.set_shader_parameter(&"bank", clampf(screen_bank, -1.0, 1.0))

	# 前後：往前加大火焰，往後熄火
	var fwd := _vel.dot(forward) / ref_speed
	var target_throttle := 1.0
	if fwd > 0.0:
		target_throttle = 1.0 + clampf(fwd * 1.6, 0.0, 0.9)
	else:
		target_throttle = clampf(1.0 + fwd * 3.0, 0.0, 1.0)
	throttle = lerpf(throttle, target_throttle, 1.0 - exp(-delta * 10.0))

	var squeeze := sprite.scale.x / _base_scale.x
	for i in thrusters.size():
		var t := thrusters[i]
		var o := _offsets[i]
		t.position = Vector2(o.x * squeeze, o.y)
		# 轉彎時外側引擎噴得比較大
		var outer := 1.0 - signf(o.x) * bank * 0.35 * (1.0 if forward.y <= 0.0 else -1.0)
		t.throttle = throttle * clampf(outer, 0.6, 1.4) if throttle > 0.05 else throttle
		t.visible = sprite.visible
