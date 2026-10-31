class_name BossPhase
extends Resource
## Boss 的一個階段。血量比例降到 hp_ratio_end 以下時進入下一階段。

@export_range(0.0, 1.0) var hp_ratio_end := 0.5
## 這個階段同時使用的彈幕，每個彈幕對應 intervals 裡的發射間隔
@export var patterns: Array[BulletPattern] = []
@export var intervals: PackedFloat32Array = PackedFloat32Array()
