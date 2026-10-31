class_name WeaponData
extends Resource
## 玩家武器設定。levels 的長度就是火力等級數。

@export var id: StringName = &"vulcan"
@export var display_name := "Vulcan"
@export var bullet_texture: Texture2D
@export var bullet_speed := 1500.0
@export var bullet_radius := 8.0
@export var damage := 1
@export var levels: Array[WeaponLevel] = []


func max_level() -> int:
	return maxi(levels.size(), 1)


func get_level(index: int) -> WeaponLevel:
	return levels[clampi(index, 0, levels.size() - 1)]
