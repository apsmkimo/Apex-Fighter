class_name Boss
extends Enemy
## Boss：多階段彈幕、進場無敵、血條、換階段清彈。

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
		e.configure(phase.patterns[i], iv, 0.6 + 0.2 * i)
		e.enabled = false
		e.bullet_damage = data.bullet_damage
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
