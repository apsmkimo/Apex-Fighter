class_name WeaponData
extends Resource
## 玩家武器設定。levels 是前幾級的設計；火力沒有上限，超過的等級由 extra_levels() 自動加強。

@export var id: StringName = &"vulcan"
@export var display_name := "Vulcan"
@export var bullet_texture: Texture2D
@export var bullet_speed := 1500.0
@export var bullet_radius := 8.0
@export var damage := 1
@export var levels: Array[WeaponLevel] = []

## BULLET = 一般子彈；LASER = 連續雷射光束（打到最前面的敵人為止）
enum Kind { BULLET, LASER }
@export var kind: Kind = Kind.BULLET

@export_group("Laser")
## 各火力等級的光束寬度（像素）
@export var laser_widths: PackedFloat32Array = PackedFloat32Array([14, 20, 28, 38])
## 各火力等級每次判定的傷害
@export var laser_damage: PackedInt32Array = PackedInt32Array([1, 2, 2, 3])
## 傷害判定間隔（秒）
@export var laser_tick := 0.05
@export var laser_color := Color(0.25, 0.6, 1.0)


## 設計好的等級數（不是上限）
func max_level() -> int:
	return maxi(levels.size(), 1)


## 超過設計等級的部分（0 = 還在設計範圍內）
func extra_levels(level: int) -> int:
	var designed := laser_widths.size() if kind == Kind.LASER else levels.size()
	return maxi(level - (maxi(designed, 1) - 1), 0)


## 一般武器超過設計等級：前 MAX_EXTRA_PAIRS 級每級多一對外側子彈，之後每級傷害 +1
const MAX_EXTRA_PAIRS := 4


func extra_pairs(level: int) -> int:
	return mini(extra_levels(level), MAX_EXTRA_PAIRS)


func bullet_damage(level: int) -> int:
	return damage + maxi(extra_levels(level) - MAX_EXTRA_PAIRS, 0)


func laser_width(level: int) -> float:
	var base := laser_widths[clampi(level, 0, laser_widths.size() - 1)] if not laser_widths.is_empty() else 20.0
	return minf(base + 6.0 * extra_levels(level), 90.0)


func laser_hit_damage(level: int) -> int:
	var base := laser_damage[clampi(level, 0, laser_damage.size() - 1)] if not laser_damage.is_empty() else 1
	return base + extra_levels(level)


func get_level(index: int) -> WeaponLevel:
	return levels[clampi(index, 0, levels.size() - 1)]
