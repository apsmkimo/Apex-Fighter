class_name MoveHover
extends MovePattern
## Boss 用：進場後在畫面上方左右來回。

@export var stop_distance := 360.0
@export var enter_time := 3.0
@export var amplitude := 170.0
## 左右一趟的秒數
@export var period := 6.0
## 前後（上下）來回的幅度與速度
@export var y_amplitude := 20.0
@export var y_speed := 1.3


func offset_at(t: float) -> Vector2:
	if t < enter_time:
		var k := 1.0 - pow(1.0 - t / enter_time, 2.0)
		return Vector2(0, stop_distance * k)
	var s := t - enter_time
	return Vector2(amplitude * sin(s / period * TAU), stop_distance + y_amplitude * sin(s * y_speed))
