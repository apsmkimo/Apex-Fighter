class_name AimedPattern
extends BulletPattern
## 自機狙：朝玩家發射，可以展開成扇形。

@export var count := 1
@export var spread_deg := 0.0


func get_directions(origin: Vector2, target: Vector2, _shot_index: int) -> Array[Vector2]:
	var to := target - origin
	if to.length_squared() < 1.0:
		to = Vector2.DOWN
	return BulletPattern.fan(to, count, spread_deg)
