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

signal enemy_killed(data: Resource, at: Vector2)
signal player_hit
signal player_respawned
signal bomb_used(at: Vector2)

signal boss_spawned(boss: Node)
signal boss_hp_changed(ratio: float)
signal boss_defeated

signal stage_warning(text: String)
signal stage_cleared
signal game_over

signal screen_shake(strength: float, duration: float)
