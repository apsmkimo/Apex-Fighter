class_name BulletPattern
extends Resource
## 彈幕的基底類別。
## 新增彈幕：繼承這個類別，覆寫 get_directions()。

@export var bullet_texture: Texture2D
@export var bullet_speed := 320.0
@export var bullet_radius := 7.0
@export var damage := 1
## 每次發射連發幾輪、每輪間隔
@export var burst_count := 1
@export var burst_interval := 0.12


## 回傳這一輪所有子彈的方向（單位向量）。shot_index 是第幾輪，可做旋轉彈幕。
func get_directions(_origin: Vector2, _target: Vector2, _shot_index: int) -> Array[Vector2]:
	return [Vector2.DOWN]


func fire(origin: Vector2, target: Vector2, shot_index: int) -> void:
	if BulletPool.instance == null:
		return
	for dir in get_directions(origin, target, shot_index):
		BulletPool.instance.spawn(origin, dir * bullet_speed, bullet_texture, bullet_radius, damage, false)


## 工具：以 center 方向為中心，展開 count 發、總角度 spread_deg。
static func fan(center: Vector2, count: int, spread_deg: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if count <= 1:
		out.append(center.normalized())
		return out
	var step := deg_to_rad(spread_deg) / (count - 1)
	var start := -deg_to_rad(spread_deg) / 2.0
	for i in count:
		out.append(center.normalized().rotated(start + step * i))
	return out
