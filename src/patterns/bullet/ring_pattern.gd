class_name RingPattern
extends BulletPattern
## 全方位環形彈。rotation_per_shot_deg 不為 0 時每輪旋轉，就是螺旋彈。

@export var count := 12
@export var rotation_per_shot_deg := 0.0
## 每次開火整圈隨機轉一個角度（報廢衛星的亂射雷射）
@export var random_rotation := false


func get_directions(_origin: Vector2, _target: Vector2, shot_index: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var base := deg_to_rad(rotation_per_shot_deg * shot_index)
	if random_rotation:
		base += randf() * TAU
	var n := BulletPattern.diff_count(count)
	for i in n:
		out.append(Vector2.DOWN.rotated(base + TAU * i / n))
	return out
