class_name SplitPattern
extends AimedPattern
## 分裂飛彈：朝玩家發射，飛到一半裂成扇形小彈。

@export var split_time := 0.7
@export var split_count := 5
@export var split_spread := 70.0
@export var split_texture: Texture2D


func fire(origin: Vector2, target: Vector2, shot_index: int, dmg := -1) -> void:
	if BulletPool.instance == null:
		return
	var d := dmg if dmg >= 0 else damage
	for dir in get_directions(origin, target, shot_index):
		var b := BulletPool.instance.spawn(origin, dir * bullet_speed, bullet_texture, bullet_radius, d, false)
		b.split_time = split_time
		b.split_count = BulletPattern.diff_count(split_count)
		b.split_spread = split_spread
		b.split_tex = split_texture
