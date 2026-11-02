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
