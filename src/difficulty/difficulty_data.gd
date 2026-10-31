class_name DifficultyData
extends Resource
## 難度設定。只影響敵人的彈量與血量，關卡、波次、場景完全相同。
## 新增難度：在 data/difficulty/ 複製一份 .tres 改數值，選機畫面會自動多一個選項。

@export var id: StringName = &"normal"
@export var display_name := "NORMAL"
@export var sort_order := 1
@export var color := Color.WHITE

@export_group("Enemy")
## 敵機與 Boss 血量倍率
@export var hp_mult := 1.0
## 每一輪彈幕的子彈數倍率（只作用在原本就超過 1 發的彈幕）
@export var bullet_count_mult := 1.0
## 開火間隔倍率（小於 1 = 開火更頻繁）
@export var fire_interval_mult := 1.0


func scale_hp(hp: int) -> int:
	return maxi(1, roundi(hp * hp_mult))


func scale_count(count: int) -> int:
	if count <= 1:
		return count
	return maxi(2, roundi(count * bullet_count_mult))


func scale_interval(interval: float) -> float:
	return interval * fire_interval_mult
