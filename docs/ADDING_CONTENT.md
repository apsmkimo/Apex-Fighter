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

## 替換或新增 BGM

畫面預設曲在 `data/audio/music_catalog.tres`：

| 欄位 | 什麼時候播 |
|---|---|
| `title` | 標題 |
| `ship_select` | 選機 |
| `stage` | 關卡（沒有被下面的欄位覆寫時） |
| `boss` | Boss 戰（沒有被下面的欄位覆寫時） |
| `result` | 結算（過關或遊戲結束同一首） |

關卡想用自己的曲子：在 StageData 的 `bgm` 指定音檔。Boss（含中階 Boss）想用自己的曲子：在 BossData 的 `bgm` 指定。留空就用上面的預設。換曲時會交叉淡化，同一首不會重頭播。

佔位檔是 `assets/audio/bgm/` 裡的 WAV。正式音樂直接蓋掉同名檔即可（WAV 或 OGG 都可以，見下面）。要改檔名或換一首完全不同的，就改 MusicCatalog／StageData／BossData 的欄位。

## 替換或新增音效

音效放在 `assets/audio/sfx/`。檔名就是 id，AudioManager 啟動時會掃描這個資料夾，**加檔案不用改程式**。

| 檔名 | 時機 |
|---|---|
| `shot_<武器 id>.wav` | 那一把主武器的射擊聲（例如 `shot_vulcan.wav`） |
| `shot_bullet.wav` / `shot_laser.wav` / `shot_arc.wav` | 沒有專屬檔時，依武器種類用的後備 |
| `enemy_hit.wav` | 敵機被打中 |
| `explode_small.wav` / `explode_large.wav` / `explode_boss.wav` | 小爆炸／較大爆炸（`explosion_scale` ≥ 1.4）／Boss |
| `item.wav` | 炸彈、勳章這類道具 |
| `power.wav` | 火力、換武器、特殊武器 |
| `bomb.wav` | 放炸彈 |
| `shield.wav` / `shield_block.wav` | 拿到護盾／護盾擋下攻擊 |
| `missile.wav` | 導彈（拿到與發射同一首；發射有節流） |
| `player_hit.wav` / `player_death.wav` | 被打中沒死／被擊落 |
| `warning.wav` | Boss WARNING |
| `boss_phase.wav` | Boss 換階段 |
| `ultimate.wav` | Boss 大絕招蓄力 |
| `stage_clear.wav` | 過關 |
| `ui.wav` | 按鈕 |
| `ship_select.wav` | 選機輪盤換機 |

連射（玩家子彈、敵機中彈、小爆炸）有最短間隔和同時發聲上限，所以正式音效也可以做很短，不必自己節流。

同一張檔名如果同時有 `.ogg` 和 `.wav`，會用 `.ogg`。

## 重新產生佔位音

目前的音檔是程式產生的 8-bit 復古佔位音，整個 `assets/audio/` 大約 400KB。要重做一次：

```bash
python3 tools/generate_audio_placeholders.py
```

換成正式檔之後就不必再跑這個腳本。

## 音量

標題畫面左下角 AUDIO，以及暫停選單裡，可以調 Master／BGM／SFX 和靜音。設定跟最高分存在同一個存檔。
