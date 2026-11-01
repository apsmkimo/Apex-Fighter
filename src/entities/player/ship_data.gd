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
## 選機畫面用的大圖（沒有就用 texture）
@export var portrait: Texture2D
## 選機畫面 HUD 顯示的機種等級
@export var ship_class := "A"
## 選機畫面的光暈顏色
@export var ui_glow := Color(0.35, 0.8, 1.0)
## 選機畫面的能力條（0 ~ 1）。SPEED 由 speed 自動換算
@export_range(0.0, 1.0) var stat_maneuver := 0.6
@export_range(0.0, 1.0) var stat_firepower := 0.6
## 機身左右傾斜幅度（0 = 不傾斜，1 = 標準）
@export var bank_amount := 1.0
## 引擎口位置（相對機身中心），每個位置會畫一道火焰
@export var thruster_offsets: PackedVector2Array = PackedVector2Array([Vector2(0, 40)])
@export var thruster_color := Color(0.3, 0.9, 1.0)
@export var thruster_width := 10.0
@export var thruster_length := 26.0

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
