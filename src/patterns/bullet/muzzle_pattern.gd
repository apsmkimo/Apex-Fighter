class_name MuzzlePattern
extends BulletPattern
## 多砲口齊射：從每個砲口位置（相對發射器）各射一組。
## aim = true 每個砲口各自朝玩家；false 沿砲管方向（中心 → 砲口）射出，並以 sweep_deg 左右擺動做扇形掃射。

@export var muzzles: PackedVector2Array = PackedVector2Array()
@export var aim := true
@export var count := 1
@export var spread_deg := 0.0
## 扇形掃射：每輪的擺動幅度（度）與每輪前進的相位
@export var sweep_deg := 0.0
@export var sweep_step := 0.55
## 左右交替：偶數輪只射左半邊、奇數輪只射右半邊
@export var alternate := false


func fire(origin: Vector2, target: Vector2, shot_index: int, dmg := -1) -> void:
	if BulletPool.instance == null:
		return
	var d := dmg if dmg >= 0 else damage
	var sway := deg_to_rad(sweep_deg) * sin(shot_index * sweep_step)
	for m in muzzles:
		if alternate and ((m.x < 0.0) != (shot_index % 2 == 0)):
			continue
		var from := origin + m
		var center: Vector2
		if aim:
			center = target - from
			if center.length_squared() < 1.0:
				center = Vector2.DOWN
		else:
			# 掃射時左右兩邊對稱擺動
			center = m.normalized().rotated(sway * (1.0 if m.x >= 0.0 else -1.0))
		for dir in BulletPattern.fan(center, BulletPattern.diff_count(count), spread_deg):
			BulletPool.instance.spawn(from, dir * bullet_speed, bullet_texture, bullet_radius, d, false)
	if NeonFx.instance and not muzzles.is_empty():
		NeonFx.instance.muzzle(origin + muzzles[shot_index % muzzles.size()], Color(1.0, 0.25, 0.2))
