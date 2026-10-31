# 程式架構

## 目錄

```
res://
├─ assets/              純素材，不放程式
│  ├─ sprites/          player / enemies / bullets / items
│  ├─ audio/            bgm / sfx（預留）
│  └─ fonts/            （預留，中文字型放這裡）
├─ data/                遊戲內容（.tres），企劃調數值都在這裡
│  ├─ ships/            戰機，Database 會自動掃描
│  ├─ weapons/          武器與火力等級
│  ├─ enemies/          敵機與 Boss
│  ├─ patterns/         彈幕與移動方式
│  ├─ items/            道具
│  └─ stages/           關卡（波次時間表 + Boss），Database 會自動掃描
├─ src/
│  ├─ autoload/         Events（訊號總線）、GameManager（狀態/存檔/換畫面）、Database（載入資料）
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
│  ├─ ui/               UiKit、hud/、menus/（標題、選機、結算）
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

分數、殘機、炸彈、火力、敵機被擊破、玩家被擊中、Boss 出現/血量/擊破、WARNING、過關、遊戲結束、畫面震動。
新系統（音效、成就、統計）只要 `Events.xxx.connect()` 就能加入，不用改既有程式。

## 命名規則

- 檔案、資料夾：`snake_case`
- 類別（class_name）：`PascalCase`
- 一個場景配一個同名腳本，放同一個資料夾
