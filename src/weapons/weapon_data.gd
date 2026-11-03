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

## BULLET = 一般子彈；LASER = 細雷射光束（火力越高光束越多條）；ARC = 連鎖閃電
enum Kind { BULLET, LASER, ARC }
@export var kind: Kind = Kind.BULLET
## 子彈會穿透敵機（每顆子彈對同一隻敵機只打一次）
@export var pierce := false
## 追蹤彈：每秒最多轉向幾弧度（0 = 直線）
@export var homing := 0.0
## 爆裂彈：打中後對周圍半徑內的敵人造成 splash_damage（0 = 不爆）
@export var splash_radius := 0.0
@export var splash_damage := 0

@export_group("Laser")
## 各火力等級的光束寬度（像素）
@export var laser_widths: PackedFloat32Array = PackedFloat32Array([14, 20, 28, 38])
## 各火力等級每次判定的傷害
@export var laser_damage: PackedInt32Array = PackedInt32Array([1, 2, 2, 3])
## 傷害判定間隔（秒）
@export var laser_tick := 0.05
@export var laser_color := Color(0.25, 0.6, 1.0)
## 光束數量上限；超過後每級改成每條光束傷害 +1
const MAX_BEAMS := 7
## 光束之間的水平間距
@export var laser_spacing := 20.0
## 單一巨型光束：只有一條，火力越高越粗、傷害越高
@export var laser_single := false
## 光束左右掃動的幅度（像素，0 = 不掃動），相鄰光束反向交叉
@export var laser_sweep := 0.0

@export_group("Arc")
## 連鎖閃電：每隔 arc_interval 秒打一次，從最近的敵人開始往旁邊跳
@export var arc_interval := 0.12
@export var arc_damage := 2
## 第一下的最遠距離、每次跳躍的最遠距離
@export var arc_range := 560.0
@export var arc_jump := 230.0
## 連鎖次數上限；超過後每級傷害 +1
const MAX_CHAINS := 8


## 介面與特效用的代表色
static func ui_color(w: WeaponData) -> Color:
	if w == null:
		return Color(0.6, 0.9, 1.0)
	return NeonFx.tex_color(w.bullet_texture) if w.kind == Kind.BULLET else w.laser_color


## 設計好的等級數（不是上限）
func max_level() -> int:
	return maxi(levels.size(), 1)


## 超過設計等級的部分（0 = 還在設計範圍內）
func extra_levels(level: int) -> int:
	var designed := levels.size()
	if kind == Kind.LASER:
		designed = MAX_BEAMS
	elif kind == Kind.ARC:
		designed = MAX_CHAINS - 1
	return maxi(level - (maxi(designed, 1) - 1), 0)


## 一般武器超過設計等級：前 MAX_EXTRA_PAIRS 級每級多一對外側子彈，之後每級傷害 +1
const MAX_EXTRA_PAIRS := 4


func extra_pairs(level: int) -> int:
	return mini(extra_levels(level), MAX_EXTRA_PAIRS)


func bullet_damage(level: int) -> int:
	return damage + maxi(extra_levels(level) - MAX_EXTRA_PAIRS, 0)


## 雷射光束條數：POWER 1 = 1 條，每升一級多 1 條，最多 MAX_BEAMS 條
func laser_beams(level: int) -> int:
	if laser_single:
		return 1
	return clampi(level + 1, 1, MAX_BEAMS)


## 每條光束寬度（細雷射，隨等級微幅變粗）
func laser_width(level: int) -> float:
	var base := laser_widths[0] if not laser_widths.is_empty() else 8.0
	if laser_single:
		return base + minf(level, 8) * 7.0
	return base + minf(level, 6) * 0.5


## 每條光束每次判定的傷害；光束數滿了之後才開始加傷害
func laser_hit_damage(level: int) -> int:
	var base := laser_damage[0] if not laser_damage.is_empty() else 1
	if laser_single:
		return base + level / 2 + extra_levels(level)
	return base + extra_levels(level)


## 連鎖閃電：一次最多打幾隻（POWER 1 = 2 隻）
func arc_chains(level: int) -> int:
	return clampi(level + 2, 2, MAX_CHAINS)


func arc_hit_damage(level: int) -> int:
	return arc_damage + extra_levels(level)


func get_level(index: int) -> WeaponLevel:
	return levels[clampi(index, 0, levels.size() - 1)]
