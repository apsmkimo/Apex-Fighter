class_name EnemyData
extends Resource
## 一種敵機的設定。新增敵機：在 data/enemies/ 新增 .tres。

@export var id: StringName
@export var texture: Texture2D
@export var max_hp := 3
@export var hit_radius := 22.0
@export var score := 100
@export var explosion_scale := 1.0

@export_group("Flight Visual")
## 機身左右傾斜幅度（0 = 不傾斜）
@export var bank_amount := 0.0
## 引擎口位置（相對機身中心）；空的就不畫引擎火焰
@export var thruster_offsets: PackedVector2Array = PackedVector2Array()
@export var thruster_color := Color(1.0, 0.3, 0.9)
@export var thruster_width := 14.0
@export var thruster_length := 30.0
## 多快的移動速度算「全力」（像素/秒），決定傾斜與火焰變化的靈敏度
@export var flight_ref_speed := 120.0

@export_group("Weak Point")
## weak_radius > 0 時只有打到弱點（發光核心）附近才有傷害，打到其他地方被裝甲擋掉
@export var weak_offset := Vector2.ZERO
@export var weak_radius := 0.0
## 額外的弱點位置（多個發光點，半徑同 weak_radius）
@export var extra_weak_offsets: PackedVector2Array = PackedVector2Array()

@export_group("Ground")
## 地面單位（砲台）：跟著地表捲動，戰機撞不到，砲身會轉向戰機
@export var ground := false
## 砲身是否轉向戰機（圖的砲口朝上）
@export var aim_rotate := true

@export_group("Hazard")
## 非空 = 太空危險物：mine（水雷）或 missile（追蹤飛彈）。不開火，靠爆炸傷人
@export var hazard_kind: StringName = &""
## 爆炸範圍內的戰機會受傷
@export var blast_radius := 110.0
@export var blast_damage := 3
## 被玩家打爆時，爆炸對附近敵人的傷害
@export var blast_enemy_damage := 20
## 水雷：戰機靠近到這個距離就引爆
@export var trigger_radius := 80.0
## 飛彈：速度、轉向速度（弧度/秒）、壽命
@export var home_speed := 280.0
@export var home_turn := 2.0
@export var home_life := 7.0

@export_group("Hazard Drop")
## 會投放危險物的敵機（例如中兵投放水雷）
@export var drop_hazard: EnemyData
@export var drop_hazard_interval := 3.0
@export var drop_hazard_first := 1.5

@export_group("Death")
## 被打爆後掉出來繼續攻擊的單位（例如戰機裡的機器人）
@export var death_spawn: EnemyData

@export_group("Movement")
## 預設移動方式，波次可以覆寫
@export var movement: MovePattern

@export_group("Attack")
## 子彈打中玩家扣的血（玩家預設 6 血：一般 2 = 可擋 3 發，Boss 3 = 可擋 2 發）
@export var bullet_damage := 2
## 撞到玩家扣的血
@export var contact_damage := 2
@export var bullet_pattern: BulletPattern
@export var fire_interval := 1.5
@export var first_fire_delay := 0.8

@export_group("Drop")
@export var drop_item: ItemData
@export_range(0.0, 1.0) var drop_chance := 0.0
## 額外掉寶：依序輪替 pool 裡的道具（例如武器、導彈）
@export var bonus_pool: Array[ItemData] = []
@export_range(0.0, 1.0) var bonus_chance := 0.0
