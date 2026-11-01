class_name EnemyData
extends Resource
## 一種敵機的設定。新增敵機：在 data/enemies/ 新增 .tres。

@export var id: StringName
@export var texture: Texture2D
@export var max_hp := 3
@export var hit_radius := 22.0
@export var score := 100
@export var explosion_scale := 1.0

@export_group("Movement")
## 預設移動方式，波次可以覆寫
@export var movement: MovePattern

@export_group("Attack")
@export var bullet_pattern: BulletPattern
@export var fire_interval := 1.5
@export var first_fire_delay := 0.8

@export_group("Drop")
@export var drop_item: ItemData
@export_range(0.0, 1.0) var drop_chance := 0.0
## 額外掉寶：依序輪替 pool 裡的道具（例如武器、導彈）
@export var bonus_pool: Array[ItemData] = []
@export_range(0.0, 1.0) var bonus_chance := 0.0
