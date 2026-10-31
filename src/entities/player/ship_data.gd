class_name ShipData
extends Resource
## 一台戰機的全部設定。
## 新增戰機：在 data/ships/ 複製一份 .tres，換圖、改數值、指定武器，選機畫面會自動出現。

@export var id: StringName = &"falcon"
@export var display_name := "Falcon"
@export_multiline var description := ""
@export var sort_order := 0
@export var unlocked := true

@export_group("Visual")
@export var texture: Texture2D

@export_group("Handling")
## 鍵盤移動速度（像素/秒）
@export var speed := 520.0
## 手指拖曳的移動倍率
@export var touch_sensitivity := 1.3
## 被擊中的判定半徑，要比機身小很多
@export var hitbox_radius := 6.0
## 吃道具的範圍
@export var pickup_radius := 44.0

@export_group("Stock")
@export var start_lives := 3
@export var start_bombs := 3
@export var max_bombs := 5
@export var bomb_damage := 80

@export_group("Weapon")
@export var weapon: WeaponData
