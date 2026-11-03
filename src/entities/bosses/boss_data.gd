class_name BossData
extends EnemyData
## Boss 設定：在 EnemyData 之上加入多階段彈幕。

@export var boss_name := "BOSS"
# SMCPKG_SUPPORT>>>CursorM9BossBgm
## Boss 戰 BGM。留空就用 MusicCatalog 的 boss。中階 Boss 與最終 Boss 可以各放一首。
@export var bgm: AudioStream
# SMCPKG_SUPPORT<<<CursorM9BossBgmEnd
## 進場時間，這段時間內無敵、不開火
@export var entry_time := 3.0
@export var phases: Array[BossPhase] = []

@export_group("Ultimate")
## 大絕招：先儲備能量，再往下發射大範圍雷射
@export var ult_enabled := true
## 進場後第一次大絕招的時間
@export var ult_first_delay := 9.0
## 兩次大絕招間隔（從上一次結束算起）
@export var ult_interval := 14.0
@export var ult_charge_time := 2.6
@export var ult_fire_time := 1.6
## 雷射寬度（像素）
@export var ult_width := 210.0
## 打到玩家扣的血（玩家 6 血：滿血只擋得住一次）
@export var ult_damage := 4
## 砲口位置（相對 Boss 中心）
@export var ult_origin := Vector2(0, 80)
@export var ult_color := Color(1.0, 0.25, 0.85)
## 大絕招種類，依序輪流使用：beam = 往下大範圍雷射、eye_laser = 紅眼掃射雷射、web = 吐絲封住行動
@export var ult_kinds: Array[StringName] = [&"beam"]

@export_subgroup("Eye Laser")
## 眼睛位置（相對 Boss 中心）
@export var ult_eye_offset := Vector2(0, -20)
@export var ult_eye_width := 44.0
## 掃射角度範圍（度）
@export var ult_eye_sweep_deg := 34.0
@export var ult_eye_charge := 2.0
@export var ult_eye_fire := 1.8

@export_subgroup("Pincer")
## 兩支鉗子雷射：右鉗位置（左鉗自動左右對稱），從內往外張開掃射
@export var ult_pincer_offset := Vector2(120, -40)
@export var ult_pincer_width := 30.0
@export var ult_pincer_charge := 1.8
@export var ult_pincer_fire := 1.8

@export_subgroup("Nova")
## 核心放出數圈擴散衝擊波，每圈有一個缺口可以鑽過去
@export var ult_nova_rings := 3
@export var ult_nova_gap_deg := 55.0
@export var ult_nova_speed := 320.0
@export var ult_nova_width := 24.0
@export var ult_nova_charge := 2.0

@export_subgroup("Feather")
## 雙翼砲台齊射：從這些位置連續朝玩家附近灑出子彈
@export var ult_feather_points: PackedVector2Array = PackedVector2Array()
@export var ult_feather_time := 2.4
@export var ult_feather_rate := 0.06
@export var ult_feather_speed := 380.0
@export var ult_feather_charge := 1.6
@export var ult_feather_texture: Texture2D

@export_subgroup("Missile")
## 追蹤飛彈：從這些砲口依序發射（打中藍點可以提早引爆）
@export var ult_missile_data: EnemyData
@export var ult_missile_points: PackedVector2Array = PackedVector2Array()
@export var ult_missile_count := 4
@export var ult_missile_charge := 1.3

@export_subgroup("Time Bomb")
## 計時炸彈：丟到畫面中下方，停留後爆炸
@export var ult_bomb_count := 3
@export var ult_bomb_fuse := 4.0
@export var ult_bomb_radius := 150.0
@export var ult_bomb_damage := 3
@export var ult_bomb_charge := 1.2

@export_subgroup("Ram")
## 本體高速旋轉、在戰場上到處衝撞碾壓
@export var ult_ram_time := 5.0
@export var ult_ram_speed := 560.0
## 自轉速度（弧度／秒）
@export var ult_ram_spin := 14.0
## 碾壓判定半徑
@export var ult_ram_radius := 130.0
@export var ult_ram_charge := 1.6

@export_subgroup("Debris Rain")
## 報廢衛星雨：從畫面上方隨機落下大量殘骸
@export var ult_debris: Array[EnemyData] = []
@export var ult_debris_count := 22
@export var ult_debris_time := 3.6
@export var ult_debris_charge := 1.8
## 從 Boss 身上掉落的外緣半徑
@export var ult_debris_edge := 240.0

@export_group("Look")
## 弱點標記顏色（透明 = 用 ult_color）
@export var weak_color := Color(0, 0, 0, 0)
## 在弱點位置畫發光能源爐
@export var reactor_core := false

@export_subgroup("Web")
## 吐絲位置（相對 Boss 中心）
@export var ult_web_origin := Vector2(0, 90)
@export var ult_web_count := 5
@export var ult_web_spread_deg := 60.0
@export var ult_web_speed := 270.0
## 被絲網黏住無法移動的秒數（左右滑動可以提早掙脫）
@export var ult_web_stun := 2.2
@export var ult_web_charge := 1.2
