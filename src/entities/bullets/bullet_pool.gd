class_name BulletPool
extends Node2D
## 子彈物件池：預先建立一批子彈重複使用，手機上才不會因為大量產生/刪除而卡頓。
## 放在關卡場景裡，任何地方都可以用 BulletPool.instance 取得。

static var instance: BulletPool

@export var bullet_scene: PackedScene
@export var prewarm := 400

var _free: Array[Bullet] = []
var _active: Array[Bullet] = []


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	for i in prewarm:
		_free.append(_make())


func spawn(pos: Vector2, vel: Vector2, tex: Texture2D, radius: float, dmg: int, player_owned: bool) -> Bullet:
	var b: Bullet = _free.pop_back() if not _free.is_empty() else _make()
	b.activate(pos, vel, tex, radius, dmg, player_owned)
	_active.append(b)
	return b


## 由 Bullet.release() 呼叫，不要直接呼叫。
func recycle(b: Bullet) -> void:
	_active.erase(b)
	_free.append(b)


## 炸彈、玩家被擊落、Boss 換階段時清除敵彈。
func clear_enemy_bullets() -> void:
	for b in _active.duplicate():
		if not b.is_player_bullet:
			b.release()


## 場上的敵彈（Boss 吸入用）
func enemy_bullets() -> Array[Bullet]:
	var out: Array[Bullet] = []
	for b in _active:
		if not b.is_player_bullet:
			out.append(b)
	return out


func active_count() -> int:
	return _active.size()


func _make() -> Bullet:
	var b := bullet_scene.instantiate() as Bullet
	add_child(b)
	return b
