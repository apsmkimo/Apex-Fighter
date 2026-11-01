extends Node
## 自動測試：無敵自動駕駛跑完第一關，檢查波次 → Boss → 過關流程。
## 執行：godot --headless --fixed-fps 60 res://tests/smoke_test.tscn

const TIMEOUT := 300.0

var t := 0.0
var _boss_seen := false
var _kills := 0
var _max_bullets := 0
var _log_timer := 0.0
var _bombs_used := 0
var _picked := {}


func _ready() -> void:
	Events.boss_spawned.connect(func(_b: Node) -> void: _boss_seen = true; print("[test] boss spawned at %.1fs" % t))
	Events.enemy_killed.connect(func(_d: Resource, _p: Vector2) -> void: _kills += 1)
	Events.stage_cleared.connect(_on_cleared)
	Events.boss_ultimate.connect(func(st: String) -> void: print("[test] boss ultimate %s at %.1fs" % [st, t]))
	Events.game_over.connect(func() -> void: _fail("game over"))
	_start.call_deferred()


func _start() -> void:
	# 可用環境變數 SMOKE_SHIP 指定測試的戰機 id（預設第一台）
	var ship: Resource = Database.ships[0]
	var want := OS.get_environment("SMOKE_SHIP")
	for s in Database.ships:
		if String(s.id) == want:
			ship = s
	var dw := OS.get_environment("SMOKE_DIFFICULTY")
	if dw != "" and Database.get_difficulty(StringName(dw)):
		GameManager.set_difficulty(Database.get_difficulty(StringName(dw)))
	print("[test] ship = %s  difficulty = %s" % [ship.display_name, GameManager.difficulty.display_name])
	GameManager.start_run(ship, Database.first_stage())
	# SMOKE_WEAPON 指定開局武器（例如 blue_laser），SMOKE_MISSILE 指定導彈等級
	var ww := OS.get_environment("SMOKE_WEAPON")
	if ww != "":
		GameManager.weapon = load("res://data/weapons/%s.tres" % ww)
	var mw := OS.get_environment("SMOKE_MISSILE")
	if mw != "":
		GameManager.missile_level = int(mw)
	print("[test] weapon = %s  missile = %d" % [GameManager.weapon.display_name, GameManager.missile_level])
	add_child((load(GameManager.SCENE_STAGE) as PackedScene).instantiate())
	Events.bomb_used.connect(func(_p: Vector2) -> void: _bombs_used += 1)


func _physics_process(delta: float) -> void:
	t += delta
	if t > TIMEOUT:
		_fail("timeout")
		return
	_log_timer += delta
	if _log_timer > 10.0:
		_log_timer = 0.0
		print("[test] t=%.0fs enemies=%d bullets=%d score=%d power=%d lives=%d" % [t, get_tree().get_nodes_in_group(&"enemies").size(),
			BulletPool.instance.active_count() if BulletPool.instance else 0, GameManager.score, GameManager.power_level, GameManager.lives])
	var p := Player.instance
	if p == null:
		return
	p.invincible = 999.0  # 無敵
	# 每 25 秒丟一次炸彈，測試全螢幕火焰
	if int(t / 25.0) > _bombs_used and GameManager.bombs > 0:
		p.use_bomb()
	_picked[GameManager.weapon.display_name] = true
	var target_x := get_viewport().get_visible_rect().size.x / 2.0
	var best := INF
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var d: float = absf((e as Node2D).global_position.x - p.global_position.x)
		if d < best and (e as Enemy).is_on_screen():
			best = d
			target_x = (e as Node2D).global_position.x
	p.position.x = move_toward(p.position.x, target_x, 400.0 * delta)
	if BulletPool.instance:
		_max_bullets = maxi(_max_bullets, BulletPool.instance.active_count())


func _on_cleared() -> void:
	await get_tree().create_timer(0.5).timeout
	print("[test] PASS stage cleared at %.1fs kills=%d score=%d max_bullets=%d boss=%s bombs=%d weapons=%s missile=%d" % [t, _kills, GameManager.score, _max_bullets, _boss_seen, _bombs_used, _picked.keys(), GameManager.missile_level])
	get_tree().quit(0)


func _fail(reason: String) -> void:
	print("[test] FAIL: %s at %.1fs (kills=%d)" % [reason, t, _kills])
	get_tree().quit(1)
