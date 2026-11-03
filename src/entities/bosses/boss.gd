class_name Boss
extends Enemy
## Boss：多階段彈幕、進場無敵、血條、換階段清彈。

## 中階 Boss（大絕招音效用）
var is_mid := false
var phase_index := -1
var _phase_emitters: Array[BulletEmitter] = []
var ultimate: BossUltimate


func _ready() -> void:
	super._ready()
	Events.boss_spawned.emit(self)
	health.damaged.connect(_on_damaged)
	if boss_data().ult_enabled:
		ultimate = BossUltimate.new()
		ultimate.setup(self)
		add_child(ultimate)
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
	_enter_phase(0)


func boss_data() -> BossData:
	return data as BossData


func take_damage(amount: int) -> void:
	if age < boss_data().entry_time:
		return  # 進場中無敵
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
	Events.boss_defeated.emit()
	queue_free()


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
