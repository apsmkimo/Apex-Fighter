# 程式架構

## 目錄

```
res://
├─ assets/              純素材，不放程式
│  ├─ sprites/          player / enemies / bullets / items
│  ├─ audio/            bgm / sfx（佔位音，可直接換成同名檔）
│  └─ fonts/            （預留，中文字型放這裡）
├─ data/                遊戲內容（.tres），企劃調數值都在這裡
│  ├─ ships/            戰機，Database 會自動掃描
│  ├─ weapons/          武器與火力等級
│  ├─ enemies/          敵機與 Boss
│  ├─ patterns/         彈幕與移動方式
│  ├─ items/            道具
│  ├─ audio/            MusicCatalog（標題／選機／關卡／Boss／結算的預設曲）
│  └─ stages/           關卡（波次時間表 + Boss），Database 會自動掃描
├─ src/
│  ├─ autoload/         Events（訊號總線）、GameManager（狀態/存檔/換畫面）、Database（載入資料）、AudioManager（BGM／音效）
│  ├─ audio/            MusicCatalog（各畫面預設 BGM）
│  ├─ components/       HealthComponent、BulletEmitter（可組合的小零件）
│  ├─ entities/
│  │  ├─ player/        Player、ShipData
│  │  ├─ enemies/       Enemy、EnemyData
│  │  ├─ bosses/        Boss、BossData、BossPhase
│  │  ├─ bullets/       Bullet、BulletPool（物件池）
│  │  └─ items/         Item、ItemData
│  ├─ weapons/          Weapon、WeaponData、WeaponLevel
│  ├─ patterns/
│  │  ├─ bullet/        BulletPattern 與 Aimed / Spread / Ring
│  │  └─ movement/      MovePattern 與 Straight / Sine / StopAndGo / Hover
│  ├─ stages/           Stage（流程）、WaveSpawner、ScrollBackground、StageData、WaveData
│  ├─ ui/               UiKit、AudioPanel、hud/、menus/（標題、選機、結算）
│  └─ effects/          Explosion、ShakeCamera
├─ tests/               smoke_test（自動跑完第一關）
└─ docs/
```

## 畫面流程

標題 → 選機 → 關卡 → 結算 →（重來／換機／標題）

## 資料與邏輯分離

| 程式（行為，共用） | 資料（內容，可以很多份） |
|---|---|
| `Player` | `ShipData` + `WeaponData` |
| `Enemy` / `Boss` | `EnemyData` / `BossData` |
| `BulletEmitter` | `BulletPattern` 子類別 |
| `Enemy` 的移動 | `MovePattern` 子類別 |
| `Stage` + `WaveSpawner` | `StageData` + `WaveData` |
| `AudioManager` | `MusicCatalog`、`StageData.bgm`、`BossData.bgm`、`assets/audio/sfx/` |

## 碰撞層

| 層 | 名稱 | 誰偵測 |
|---|---|---|
| 1 | player | — |
| 2 | player_bullet | 偵測敵機（層 3） |
| 3 | enemy | — |
| 4 | enemy_bullet | — |
| 5 | item | — |

玩家本體偵測層 3、4（被打），玩家的 PickupArea 偵測層 5（吃道具）。

## 訊號總線 Events

分數、殘機、炸彈、火力、敵機被擊破、玩家被擊中／被擊落、Boss 出現/血量/階段/擊破、WARNING、過關、遊戲結束、畫面震動。
另外還有給音效用的：`weapon_fired`、`missile_fired`、`enemy_damaged`、`item_picked`、`player_hurt`、`boss_phase_changed`、`ui_pressed`、`ship_selected`、`music_requested`。
新系統（成就、統計）只要 `Events.xxx.connect()` 就能加入，不用改既有程式。

## 音效（AudioManager）

- Autoload `AudioManager`。玩法只發 `Events` 訊號，音效自己聽，不在各處呼叫播放。
- 三條匯流排：**Master**、**BGM**、**SFX**（`default_bus_layout.tres`）。拉桿是 0～1 的線性音量，另有各自的靜音。
- 音量寫在跟最高分同一個 `user://save.cfg` 的 `[audio]` 區段。`GameManager` 存檔時會先讀舊檔，不會把音量清掉。
- **BGM** 用兩條 player 交叉淡化。畫面曲（標題、選機、關卡、Boss、結算）放在 `data/audio/music_catalog.tres`。`StageData.bgm`、`BossData.bgm` 有填就覆寫關卡曲／Boss 曲。
- **音效** 掃 `assets/audio/sfx/`，檔名（不含副檔名）就是 id，例如 `explode_small.wav`。主武器會先找 `shot_<武器 id>`，沒有再退回 `shot_bullet`／`shot_laser`／`shot_arc`。
- 連射用固定大小的 player 池，加上每種聲音的最短間隔與同時發聲上限，避免幾百發子彈把手機音效通道塞滿。UI 音效另外一組，暫停時還聽得到按鈕。
- 暫停選單：BGM 音量壓低、戰鬥音效凍結。App 切到背景：全部暫停，回到前景再恢復（無視窗的 headless 測試不會進這段）。
- headless（Dummy 音訊）仍會載入音檔、走節流和播放池，但不呼叫 `play()`。這個驅動在程序結束時會把還在播的 playback 報成錯誤，所以無頭測試只驗證系統本身。

## 命名規則

- 檔案、資料夾：`snake_case`
- 類別（class_name）：`PascalCase`
- 一個場景配一個同名腳本，放同一個資料夾

## 霓虹視覺系統（Neon Tech）
- `src/stages/scroll_background.gd`：程式繪製背景。漸層＋掃描光帶、星雲、4 層視差星星（會閃爍）、光塵、流星。發光部分在加亮混合的子節點 `GlowLayer`。
- `src/effects/neon_fx.gd`：共用特效層 `NeonFx.instance`。粒子用固定大小 Packed 陣列（上限 700 顆、光環 32 個），整層一次 `_draw`、一個加亮材質、一張共用光點貼圖。提供 `explode / impact / muzzle / pickup / shield_burst / hurt_burst / float_text`。
- `src/effects/power_aura.gd`：火力等級光效（翼端燈 → 能量線 → 核心光 → 六角護罩 → 環繞能量球）。
- 子彈：每顆子彈多一個共用貼圖與材質的光暈 Sprite（玩家為拖尾、敵人為圓形光暈），可合批。
- HUD：`src/ui/hud/` 下的 `neon_draw.gd`（繪圖工具與圖示）、`status_panel.gd`（左下分段 HP 與圖示數字）、`bomb_button.gd`、`stage_banner.gd`（STAGE／WARNING／CLEAR 動畫）。
- 截圖測試：`xvfb-run godot --rendering-method gl_compatibility --resolution 720x1280 --path . res://tests/screenshot.tscn`，圖存到 user://shots/。
