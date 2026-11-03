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
## 每條命的血量（一般子彈 2、Boss 子彈 3、Boss 大絕招 4）
@export var max_hp := 6
@export var start_lives := 3
@export var start_bombs := 3
@export var max_bombs := 5
@export var bomb_damage := 80
## 炸彈全螢幕特效風格：0 烈焰 1 日冕新星 2 雷暴 3 神盾衝擊波 4 海嘯 5 毒霧 6 虛空坍縮
@export_range(0, 6) var bomb_style := 0
## 炸彈名稱（顯示用）
@export var bomb_name := "FIRESTORM"
## 火力倍率：所有對敵傷害乘上這個數
@export var damage_mult := 1.0

@export_group("Weapon")
@export var weapon: WeaponData
## 撿到特殊武器道具（紫金星）時換成的武器。戰機分兩組，各組拿到不同武器
@export var special_weapon: WeaponData
