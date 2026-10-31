class_name MoveSine
extends MovePattern
## 一邊往下一邊左右蛇行。

@export var speed := 220.0
@export var amplitude := 140.0
## 每秒擺動幾次
@export var frequency := 0.5


func offset_at(t: float) -> Vector2:
	return Vector2(amplitude * sin(t * frequency * TAU), speed * t)
