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

@export_subgroup("Spore Ring")
## spore_ring：從 ult_feather_points 各點朝外（以 Boss 中心為準）噴射，使用 feather 的速度、頻率、貼圖、時間、蓄力

@export_subgroup("Sweep Missiles")
## eye_laser 掃射時同時發射幾枚追蹤飛彈（用 ult_missile_data / ult_missile_points）
@export var ult_eye_missiles := 0

@export_subgroup("Devour")
## devour：全場變暗 → 張開巨口（換圖）→ 旋渦吸入子彈、小怪、殘骸，拉扯玩家 → 吐出超巨型火球
@export var ult_devour_texture: Texture2D
@export var ult_vortex_texture: Texture2D
@export var ult_fireball_texture: Texture2D
@export var ult_fireball_burst: Texture2D
## 被吸進去的殘骸外觀（純特效）
@export var ult_devour_debris: Array[Texture2D] = []
## 巨口位置（相對 Boss 中心）
@export var ult_mouth := Vector2(0, 30)
@export var ult_devour_charge := 1.6
@export var ult_devour_time := 3.6
## 拉扯玩家的速度（像素/秒，越靠近越強）
@export var ult_devour_pull := 170.0
@export var ult_vortex_size := 820.0
@export var ult_fireball_size := 250.0
@export var ult_fireball_speed := 230.0
@export var ult_fireball_ring := 18

@export_subgroup("Black Gold")
## 第六關黑金機甲用的絕招：
##   x_strike   全砲口聚能（ult_feather_points）→ 十道紅光砲在地面交織成巨大 X，踩到持續扣血，2 秒後引爆
##   focus_ring 浮游砲飛到空中圍成圓 → 六道雷射聚焦成超巨型紅光球 → 炸開全場衝擊波＋岩漿坑；每打掉一片傷害減 1/6
##   annihilate 核心打開露出紅光黑洞 → 超寬湮滅光柱緩慢橫掃全場；躲在飄進來的隕石後面才安全
@export var ult_x_texture: Texture2D
@export var ult_x_size := 640.0
@export var ult_pit_texture: Texture2D
@export var ult_orb_texture: Texture2D
@export var ult_focus_radius := 210.0
@export var ult_beam_texture: Texture2D
@export var ult_hole_texture: Texture2D
@export var ult_cover_textures: Array[Texture2D] = []
@export var ult_annihilate_width := 300.0
@export var ult_annihilate_sweep_deg := 64.0
@export var ult_annihilate_time := 5.0

@export_group("Float Cannons")
## 浮游砲：在這些位置（相對 Boss 中心）各放一座，自動追蹤玩家射擊，可以被打掉
@export var float_cannon: EnemyData
@export var float_slots: PackedVector2Array = PackedVector2Array()

@export_group("Core Reveal")
## 血量降到這個比例才露出核心弱點（0 = 一開始就露出）。露出前整個機身都打得到，但裝甲只吃 armor_damage_mult 的傷害
@export var core_reveal_ratio := 0.0
@export var armor_damage_mult := 0.6

@export_group("Look")
## 被打倒時依序播放的大型爆炸圖（第一張先爆、第二張接著擴大）
@export var death_blasts: Array[Texture2D] = []
@export var death_blast_size := 640.0
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
