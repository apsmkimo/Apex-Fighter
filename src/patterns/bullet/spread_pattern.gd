class_name SpreadPattern
extends BulletPattern
## 固定方向的扇形彈（不瞄準玩家）。

@export var count := 5
@export var spread_deg := 50.0
## 0 = 正下方，正值往右轉
@export var direction_deg := 0.0


func get_directions(_origin: Vector2, _target: Vector2, _shot_index: int) -> Array[Vector2]:
	return BulletPattern.fan(Vector2.DOWN.rotated(deg_to_rad(-direction_deg)), BulletPattern.diff_count(count), spread_deg)
