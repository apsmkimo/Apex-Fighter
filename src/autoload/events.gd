extends Node
## 全域訊號總線（Autoload: Events）
## 系統之間只透過這裡的訊號溝通，UI、音效、分數彼此不直接引用，方便日後替換或擴充。

signal score_changed(score: int)
signal hi_score_changed(hi_score: int)
signal lives_changed(lives: int)
signal bombs_changed(bombs: int)
signal power_changed(level: int, max_level: int)
signal weapon_changed(weapon: Resource)
signal missile_changed(level: int)
signal player_hp_changed(hp: int, max_hp: int)
## 護盾剩餘秒數；0 = 沒有護盾
signal shield_changed(seconds: float)
## 護盾擋下一次攻擊
signal shield_blocked(at: Vector2)
## 撿到道具（text 是飛出的提示字）
signal item_collected(text: String, at: Vector2, color: Color)

signal enemy_killed(data: Resource, at: Vector2)
# SMCPKG_SUPPORT>>>CursorM9Signals
# signal player_hit
## 玩家被擊落（失去一條命的那一下）。沒死的受擊看 player_hurt。
signal player_hit
## 玩家被打中但還活著
signal player_hurt
signal player_respawned
signal bomb_used(at: Vector2)
## 主武器打出一輪。kind = bullet / laser / arc
signal weapon_fired(weapon_id: StringName, kind: StringName)
## 追蹤導彈打出一輪（不是每一發）
signal missile_fired
## 敵機被打中、還沒死
signal enemy_damaged(at: Vector2)
## 撿到道具的種類（ItemData.Type 的數值）
signal item_picked(item_type: int)
## Boss 進入下一個階段（進場的第 0 階段不發）
signal boss_phase_changed(index: int)

signal boss_spawned(boss: Node)
signal boss_hp_changed(ratio: float)
signal boss_defeated
## Boss 大絕招：state = "charge" / "fire" / "end"
signal boss_ultimate(state: String)
## 敵機開火（音效用）：size 0 小兵、1 中兵、2 大兵／重砲
signal enemy_fired(size: int)

signal stage_warning(text: String)
signal stage_cleared
signal game_over

signal screen_shake(strength: float, duration: float)

## UI 按鈕（暫停選單、標題、結算、難度……）
signal ui_pressed
## 選機畫面換了一台戰機
signal ship_selected
## 要求播放某個畫面的 BGM：title / ship_select / stage / result
## boss 曲由 AudioManager 在 boss_spawned 時自己換，不用畫面再發一次
signal music_requested(context: StringName)
# SMCPKG_SUPPORT<<<CursorM9SignalsEnd
