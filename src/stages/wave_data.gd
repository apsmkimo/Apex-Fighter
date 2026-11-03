class_name WaveData
extends Resource
## 關卡時間表上的一波敵機。

## 關卡開始後第幾秒出現
@export var time := 0.0
@export var enemy: EnemyData
@export var count := 1
## 同一波每隻之間的間隔秒數
@export var interval := 0.3
## 出生的水平位置（0 = 左邊，1 = 右邊）
@export_range(0.0, 1.0) var start_x := 0.5
## 每多一隻，水平位置位移多少
@export var step_x := 0.0
## 不為空時覆寫敵機預設的移動方式
@export var movement_override: MovePattern
## 同時在左右對稱的位置再生一隻（移動也左右相反）
@export var mirror := false
## 砲台封鎖：這波的地面砲台停在畫面上方，地圖暫停捲動，全部打掉才會繼續前進
@export var hold := false
