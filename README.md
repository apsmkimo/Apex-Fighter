# Apex Fighter

雷電風格的直向捲軸射擊遊戲，Android 版，使用 **Godot 4.7.2+（GDScript）** 開發。

目前內容：**3 台戰機（FALCON、PHOENIX、THUNDERBIRD）、1 個關卡（STAGE 1，15 波敵機 + 三階段 Boss）、3 種難度（EASY／NORMAL／HARD，只影響敵人彈量與血量）**。架構從一開始就支援多台戰機與多個關卡。

## 快速開始

1. 安裝 [Godot 4.7.2 以上](https://godotengine.org/download)（標準版，不需要 .NET）
2. Godot 專案管理器 → 匯入 → 選這個資料夾的 `project.godot`
3. 按 F5 執行。電腦上可以用滑鼠拖曳（模擬手指）或方向鍵移動，X / 空白鍵放炸彈，Esc 暫停

## 操作（手機）

| 動作 | 方式 |
|---|---|
| 移動 | 手指在畫面任意位置拖曳（相對移動，手指不會擋住戰機） |
| 射擊 | 自動連射 |
| 炸彈 | 右下角 BOMB 按鈕 |
| 暫停 | 右上角 II 或 Android 返回鍵；切到背景會自動暫停 |

## 文件

- [專案計畫與進度](docs/PROJECT_PLAN.md)
- [程式架構](docs/ARCHITECTURE.md)
- [如何新增戰機、敵機、彈幕、關卡](docs/ADDING_CONTENT.md)
- [匯出 Android APK](docs/ANDROID_EXPORT.md)

## 自動測試

用無敵自動駕駛跑完整個第一關，確認波次 → Boss → 過關流程正常：

```bash
godot --headless --fixed-fps 60 --path . --scene res://tests/smoke_test.tscn
```

輸出 `[test] PASS stage cleared ...` 就是通過。

## 素材

目前的圖都是程式產生的佔位圖（placeholder），之後換成正式美術只要替換 `assets/sprites/` 裡同名的 PNG。
音效與 BGM 也是程式產生的佔位音，換成同名檔即可，見 [如何新增內容](docs/ADDING_CONTENT.md)。
