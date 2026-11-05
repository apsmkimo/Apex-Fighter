class_name Boss
extends Enemy
## Boss：多階段彈幕、進場無敵、血條、換階段清彈。

## 中階 Boss（大絕招音效用）
var is_mid := false
var phase_index := -1
var _phase_emitters: Array[BulletEmitter] = []
var ultimate: BossUltimate
var float_rig: FloatCannonRig
## 核心尚未露出（第二階段才露出）
var core_hidden := false
var _armor_acc := 0.0
var _armor_plate: ArmorPlate


func _ready() -> void:
	super._ready()
	# 圖層：Boss 蓋在敵彈、飛彈、小怪上面，子彈看起來從 Boss 底下飛出（玩家 z 4 仍在最上）
	z_index = 3
	Events.boss_spawned.emit(self)
	health.damaged.connect(_on_damaged)
	if boss_data().float_cannon and not boss_data().float_slots.is_empty():
		float_rig = FloatCannonRig.new()
		float_rig.boss = self
		add_child(float_rig)
	if boss_data().ult_enabled:
		ultimate = BossUltimate.new()
		ultimate.setup(self)
		add_child(ultimate)
	if data.weak_radius > 0.0 and boss_data().core_reveal_ratio > 0.0:
		# 核心被裝甲蓋住：先打整個機身
		core_hidden = true
		(shape.shape as CircleShape2D).radius = data.hit_radius
		shape.position = Vector2.ZERO
		_armor_plate = ArmorPlate.new()
		_armor_plate.position = data.weak_offset
		_armor_plate.radius = data.weak_radius * 1.15
		add_child(_armor_plate)
	elif data.weak_radius > 0.0:
		_add_weak_markers()
	_enter_phase(0)


func _add_weak_markers() -> void:
	if data.weak_radius > 0.0:
		var wc := boss_data().weak_color if boss_data().weak_color.a > 0.0 else boss_data().ult_color
		if boss_data().reactor_core:
			var core := ReactorCore.new()
			core.position = data.weak_offset
			core.radius = data.weak_radius
			core.color = wc
			add_child(core)
		var offs: Array[Vector2] = [data.weak_offset]
		for o in data.extra_weak_offsets:
			offs.append(o)
		for o in offs:
			var mark := WeakPointMarker.new()
			mark.position = o
			mark.radius = data.weak_radius
			mark.color = wc
			add_child(mark)


## 第二階段：裝甲炸開，露出核心弱點
func _reveal_core() -> void:
	if health.dead:
		return
	(shape.shape as CircleShape2D).radius = data.weak_radius
	shape.position = data.weak_offset
	_add_weak_markers()
	var at := global_position + data.weak_offset
	if _armor_plate:
		_armor_plate.queue_free()
		_armor_plate = null
	if NeonFx.instance:
		NeonFx.instance.explode(at, 2.4)
		NeonFx.instance.ring(at, 20.0, 220.0, 0.5, Color(1.0, 0.85, 0.5), 6.0)
		for i in 24:
			var dir := Vector2.RIGHT.rotated(TAU * i / 24.0)
			NeonFx.instance.emit(at + dir * 30.0, dir * randf_range(200.0, 420.0), 0.6, 3.5, Color(1.0, 0.86, 0.55), NeonFx.Kind.SPARK, 2.0)
		NeonFx.instance.float_text(at + Vector2(0, -80), "CORE EXPOSED!", Color(1.0, 0.4, 0.3))
	Events.screen_shake.emit(14.0, 0.5)


func boss_data() -> BossData:
	return data as BossData


func take_damage(amount: int) -> void:
	if age < boss_data().entry_time:
		return  # 進場中無敵
	if core_hidden:
		# 裝甲：只吃一部分傷害（累積小數，不會整發被吃掉）
		_armor_acc += amount * boss_data().armor_damage_mult
		var d := int(_armor_acc)
		_armor_acc -= d
		if d <= 0:
			return
		amount = d
	super.take_damage(amount)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var firing := age >= boss_data().entry_time and not health.dead
	# 儲備能量與發射雷射時暫停一般彈幕
	if ultimate and ultimate.busy():
		firing = false
	for e in _phase_emitters:
		e.enabled = firing


func _can_fire() -> bool:
	return false  # Boss 不用基底的單一發射器，改用階段發射器


func _can_despawn() -> bool:
	return false


func _on_damaged(_amount: int, _current: int) -> void:
	var ratio := health.ratio()
	Events.boss_hp_changed.emit(ratio)
	if core_hidden and ratio <= boss_data().core_reveal_ratio and not health.dead:
		core_hidden = false
		_reveal_core.call_deferred()
	var phases := boss_data().phases
	var next := phase_index
	while next < phases.size() - 1 and ratio <= phases[next].hp_ratio_end:
		next += 1
	if next != phase_index:
		_enter_phase(next)
		if BulletPool.instance:
			BulletPool.instance.clear_enemy_bullets()
		Events.screen_shake.emit(10.0, 0.35)


func _enter_phase(index: int) -> void:
	phase_index = index
	# SMCPKG_SUPPORT>>>CursorM9Phase
	if index > 0:
		Events.boss_phase_changed.emit(index)
	# SMCPKG_SUPPORT<<<CursorM9PhaseEnd
	for e in _phase_emitters:
		e.queue_free()
	_phase_emitters.clear()
	var phases := boss_data().phases
	if index < 0 or index >= phases.size():
		return
	var phase := phases[index]
	for i in phase.patterns.size():
		var e := BulletEmitter.new()
		var iv := phase.intervals[i] if i < phase.intervals.size() else 1.0
		if GameManager.difficulty:
			iv = GameManager.difficulty.scale_interval(iv)
		iv *= GameManager.BOSS_FIRE_INTERVAL_MULT
		e.configure(phase.patterns[i], iv, 0.6 + 0.2 * i)
		e.enabled = false
		e.bullet_damage = data.bullet_damage
		# 只讓第一個彈幕出聲，避免 Boss 同時好幾組一起響
		e.sfx_size = 1 if _phase_emitters.is_empty() else -1
		add_child(e)
		_phase_emitters.append(e)


func _on_died() -> void:
	if ultimate:
		ultimate.cancel()
	for e in _phase_emitters:
		e.enabled = false
	GameManager.add_score(data.score)
	Events.enemy_killed.emit(data, global_position)
	var blasts := boss_data().death_blasts
	if NeonFx.instance and not blasts.is_empty():
		var sz := boss_data().death_blast_size
		for i in blasts.size():
			NeonFx.instance.burst(global_position, blasts[i], sz * (0.75 + 0.35 * i), 0.9 + 0.3 * i, 0.35 * i)
		Events.screen_shake.emit(18.0, 1.0)
	Events.boss_defeated.emit()
	queue_free()


## 蓋住核心的黑金裝甲板（第二階段炸開）
class ArmorPlate extends Node2D:
	var radius := 46.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(Vector2.RIGHT.rotated(TAU * i / 6.0 + PI / 6.0) * radius)
		draw_colored_polygon(pts.slice(0, 6), Color(0.07, 0.06, 0.06, 0.96))
		draw_polyline(pts, Color(0.95, 0.8, 0.5, 0.95), 3.0)
		var inner := PackedVector2Array()
		for i in 7:
			inner.append(Vector2.RIGHT.rotated(TAU * i / 6.0 + PI / 6.0) * radius * 0.62)
		draw_polyline(inner, Color(0.8, 0.62, 0.35, 0.8), 2.0)
		for i in 6:
			var d := Vector2.RIGHT.rotated(TAU * i / 6.0 + PI / 6.0)
			draw_line(d * radius * 0.62, d * radius, Color(0.75, 0.6, 0.35, 0.8), 2.0)
		# 縫隙透出的紅光
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		draw_circle(Vector2.ZERO, radius * 0.18, Color(1.0, 0.15, 0.1, 0.5 + 0.4 * pulse))


## 弱點提示：在發光核心外圍畫旋轉的虛線瞄準圈，提醒玩家只有打這裡才有效
class WeakPointMarker extends Node2D:
	var radius := 40.0
	var color := Color(1, 0.3, 0.3)
	var _t := 0.0

	func _ready() -> void:
		z_index = 4
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		var c := Color(color.r, color.g, color.b, 0.35 + 0.3 * pulse)
		for i in 6:
			var a := _t * 1.2 + TAU * i / 6.0
			draw_arc(Vector2.ZERO, radius + 4.0, a, a + 0.6, 8, c, 2.5)
		for i in 4:
			var a := -_t * 0.8 + TAU * i / 4.0
			var d := Vector2.RIGHT.rotated(a)
			draw_line(d * (radius + 10.0), d * (radius + 20.0), c, 2.0)


## 發光能源爐：在弱點畫一顆脈動的能量核心（中階 Boss 螳螂用）
class ReactorCore extends Node2D:
	var radius := 34.0
	var color := Color(0.4, 1.0, 0.5)
	var _t := 0.0

	func _ready() -> void:
		z_index = 3
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		# 外層光暈
		for i in 5:
			var r := radius * (1.6 - i * 0.22) + pulse * 4.0
			draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.08 + i * 0.05))
		# 爐心
		draw_circle(Vector2.ZERO, radius * 0.45 + pulse * 3.0, Color(color.r * 0.6 + 0.4, color.g * 0.6 + 0.4, color.b * 0.6 + 0.4, 0.9))
		draw_circle(Vector2.ZERO, radius * 0.22, Color(1, 1, 1, 0.95))
		# 旋轉的能量葉片
		for i in 6:
			var a := _t * 2.2 + TAU * i / 6.0
			var d := Vector2.RIGHT.rotated(a)
			draw_line(d * radius * 0.5, d * radius * 0.95, Color(color.r, color.g, color.b, 0.7), 3.0)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(color.r, color.g, color.b, 0.6 + 0.3 * pulse), 2.5)
