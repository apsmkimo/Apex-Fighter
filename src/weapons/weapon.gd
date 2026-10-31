class_name Weapon
extends Node2D
## 掛在玩家身上的武器，依照 WeaponData 與目前火力等級自動連射。

var data: WeaponData
var level := 0
var firing := false
var _cooldown := 0.0


func _physics_process(delta: float) -> void:
	if data == null or data.levels.is_empty() or not firing or BulletPool.instance == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var lv := data.get_level(level)
	_cooldown = lv.fire_interval
	for i in lv.offsets.size():
		var angle := deg_to_rad(lv.angles_deg[i]) if i < lv.angles_deg.size() else 0.0
		var dir := Vector2.UP.rotated(angle)
		BulletPool.instance.spawn(global_position + lv.offsets[i], dir * data.bullet_speed,
				data.bullet_texture, data.bullet_radius, data.damage, true)
