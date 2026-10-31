class_name MoveStopAndGo
extends MovePattern
## 飛進畫面、停下來攻擊一陣子，再離開。

@export var stop_distance := 300.0
@export var enter_time := 1.2
@export var wait_time := 3.0
@export var exit_velocity := Vector2(0, 180)


func offset_at(t: float) -> Vector2:
	if t < enter_time:
		var k := 1.0 - pow(1.0 - t / enter_time, 3.0)  # ease out
		return Vector2(0, stop_distance * k)
	var stop := Vector2(0, stop_distance)
	if t < enter_time + wait_time:
		return stop
	return stop + exit_velocity * (t - enter_time - wait_time)
