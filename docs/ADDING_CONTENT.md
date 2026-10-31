# 新增內容

所有內容都是 `data/` 裡的 .tres 檔，可以在 Godot 編輯器的屬性面板直接編輯。

## 新增一台戰機

1. 把圖放到 `assets/sprites/player/`（機頭朝上）
2. 在 `data/weapons/` 複製 `vulcan.tres`，改子彈圖、速度、傷害，在 `levels` 裡設定每一級的發射位置與角度
3. 在 `data/ships/` 複製 `falcon.tres`，改 `id`（不可重複）、名稱、說明、圖、速度、判定、殘機、炸彈，`weapon` 指向新武器
4. `sort_order` 決定選機畫面的順序；`unlocked = false` 會顯示但不能選

選機畫面會自動出現新戰機，不需要改任何程式。

## 新增一種敵機

在 `data/enemies/` 新增 EnemyData：圖、血量、判定半徑、分數、移動方式（`movement`）、彈幕（`bullet_pattern`）、發射間隔、掉落道具與機率。

需要特殊行為（例如會分裂、會追蹤）時，新增腳本 `extends Enemy`，覆寫需要的函式，再做一個對應的 .tscn。

## 新增彈幕

```gdscript
class_name CrossPattern
extends BulletPattern

func get_directions(_origin: Vector2, _target: Vector2, shot_index: int) -> Array[Vector2]:
	var base := deg_to_rad(shot_index * 10.0)
	return [Vector2.DOWN.rotated(base), Vector2.UP.rotated(base),
			Vector2.LEFT.rotated(base), Vector2.RIGHT.rotated(base)]
```

存成 `src/patterns/bullet/cross_pattern.gd`，在編輯器新增 Resource 選 CrossPattern 就能用。

## 新增移動方式

繼承 `MovePattern`，覆寫 `offset_at(t)`，回傳出生後 t 秒相對出生點的位移。

## 新增關卡

在 `data/stages/` 新增 StageData：背景顏色、捲動速度、`waves`（每一波：出現時間、敵機、數量、間隔、水平位置、位移、覆寫移動、是否左右對稱）、`boss`。
`sort_order` 決定關卡順序。目前遊戲只會進第一關，做第二關時要在 Stage 過關後改成載入下一個 StageData。

## Boss 階段

BossData 的 `phases` 依序排列；每個階段的 `hp_ratio_end` 是「血量比例低於這個值時進入下一階段」，最後一個階段設 0。每個階段可以同時有多個彈幕，`intervals` 是對應的發射間隔。
