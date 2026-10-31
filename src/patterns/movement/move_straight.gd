class_name MoveStraight
extends MovePattern
## 等速直線。

@export var velocity := Vector2(0, 260)


func offset_at(t: float) -> Vector2:
	return velocity * t
