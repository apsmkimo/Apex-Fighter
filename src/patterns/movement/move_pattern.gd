class_name MovePattern
extends Resource
## 移動方式的基底類別。
## 回傳「出生後經過 t 秒」相對出生點的位移。用時間算位置，路徑完全可預測、好調整。
## 新增移動方式：繼承這個類別並覆寫 offset_at()。


func offset_at(_t: float) -> Vector2:
	return Vector2.ZERO
