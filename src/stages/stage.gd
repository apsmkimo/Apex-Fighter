extends Node2D
## 關卡流程：波次 → 清場 → WARNING → Boss → 過關／遊戲結束。
## 關卡內容全部來自 GameManager.current_stage（StageData），這支程式所有關卡共用。

enum State { WAVES, BOSS_WARNING, BOSS, CLEAR, OVER }

const PLAYER_SCENE := preload("res://src/entities/player/player.tscn")
const BOSS_SCENE := preload("res://src/entities/bosses/boss.tscn")
const EXPLOSION_SCENE := preload("res://src/effects/explosion.tscn")

var data: StageData
var state := State.WAVES

@onready var background: ScrollBackground = $Background
@onready var enemies: Node2D = $Enemies
@onready var actors: Node2D = $Actors
@onready var effects: Node2D = $Effects
@onready var camera: ShakeCamera = $Camera
@onready var spawner: WaveSpawner = $WaveSpawner
@onready var hud: Hud = $Hud


func _ready() -> void:
	# 直接在編輯器按 F6 執行這個場景時，自動用第一台戰機和第一關
	if GameManager.current_stage == null:
		GameManager.start_run(Database.ships[0], Database.first_stage())
	data = GameManager.current_stage
	camera.position = get_viewport_rect().size / 2.0
	background.setup(data)

	var player := PLAYER_SCENE.instantiate() as Player
	player.setup(GameManager.selected_ship)
	actors.add_child(player)

	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_hit.connect(_on_player_hit)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.game_over.connect(_on_game_over)
	Events.screen_shake.connect(camera.shake)
	Events.bomb_used.connect(_on_bomb_used)

	hud.show_stage_title(data.display_name)
	GameManager.emit_all()
	spawner.start(data, enemies)


func _physics_process(_delta: float) -> void:
	if state == State.WAVES and spawner.done and get_tree().get_nodes_in_group(&"enemies").is_empty():
		_start_boss_warning()


func _start_boss_warning() -> void:
	state = State.BOSS_WARNING
	Events.stage_warning.emit("WARNING")
	await get_tree().create_timer(data.boss_warning_time).timeout
	if state != State.BOSS_WARNING:
		return
	if data.boss == null:
		_on_boss_defeated()
		return
	state = State.BOSS
	var boss := BOSS_SCENE.instantiate() as Boss
	boss.setup(data.boss, Vector2(get_viewport_rect().size.x / 2.0, -120.0))
	enemies.add_child(boss)


func spawn_explosion(at: Vector2, size_scale := 1.0) -> void:
	var fx := EXPLOSION_SCENE.instantiate() as Explosion
	fx.size_scale = size_scale
	fx.position = at
	effects.add_child(fx)


func _on_enemy_killed(enemy_data: Resource, at: Vector2) -> void:
	var s := 1.0
	if enemy_data is EnemyData:
		s = (enemy_data as EnemyData).explosion_scale
	spawn_explosion(at, s)


func _on_player_hit() -> void:
	if Player.instance:
		spawn_explosion(Player.instance.global_position, 1.4)


func _on_bomb_used(at: Vector2) -> void:
	for i in 8:
		spawn_explosion(at + Vector2.RIGHT.rotated(TAU * i / 8.0) * 160.0, 1.6)


func _on_boss_defeated() -> void:
	if state == State.CLEAR or state == State.OVER:
		return
	state = State.CLEAR
	if BulletPool.instance:
		BulletPool.instance.clear_enemy_bullets()
	Events.screen_shake.emit(20.0, 1.2)
	Events.stage_cleared.emit()
	await get_tree().create_timer(3.5).timeout
	GameManager.end_run(true)
	GameManager.goto_result()


func _on_game_over() -> void:
	if state == State.CLEAR:
		return
	state = State.OVER
	await get_tree().create_timer(2.0).timeout
	GameManager.end_run(false)
	GameManager.goto_result()


# ---------- 暫停：Esc、Android 返回鍵、切到背景 ----------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		hud.toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		hud.toggle_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and not get_tree().paused:
		hud.toggle_pause()
