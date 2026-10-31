class_name WeaponLevel
extends Resource
## 武器的一個火力等級：每次發射有幾發、各自的位置偏移與角度。

@export var fire_interval := 0.09
## 每一發相對於機頭的位置
@export var offsets: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
## 每一發的角度（度），0 = 正上方，正值往右偏
@export var angles_deg: PackedFloat32Array = PackedFloat32Array([0.0])
