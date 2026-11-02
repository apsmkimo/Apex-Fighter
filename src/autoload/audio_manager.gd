extends Node
## 音效與 BGM（Autoload: AudioManager）
## 只聽 Events，不讓玩法直接呼叫這裡（音量 UI 除外）。
## 匯流排：Master / BGM / SFX。音量與靜音寫進 user://save.cfg 的 audio 區段。
##
## BGM：兩條 player 交叉淡化。畫面曲來自 MusicCatalog，
## 關卡與 Boss 若有填 bgm 就覆寫。
## 音效：固定數量的 player 池＋每種聲音的節流與同時發聲上限，
## 避免連射在手機上把音效通道塞爆。

const CATALOG_PATH := "res://data/audio/music_catalog.tres"
const SFX_DIR := "res://assets/audio/sfx/"
const SFX_POOL := 16
const UI_POOL := 4
const FADE_SEC := 0.65
## 暫停選單時把 BGM 壓低的分貝（音效則直接凍結）
const PAUSE_DUCK_DB := -12.0

const THROTTLE := {
	&"enemy_hit": 0.045,
	&"explode_small": 0.05,
	&"explode_large": 0.08,
	&"explode_boss": 0.25,
	&"missile": 0.18,
	&"ui": 0.04,
	&"item": 0.06,
	&"power": 0.08,
	&"player_hit": 0.08,
	&"shield_block": 0.08,
}
const VOICE_LIMIT := {
	&"enemy_hit": 3,
	&"explode_small": 4,
	&"explode_large": 2,
	&"explode_boss": 1,
	&"missile": 2,
	&"ui": 3,
	&"player_death": 1,
	&"player_hit": 2,
	&"warning": 1,
	&"stage_clear": 1,
	&"bomb": 1,
	&"boss_phase": 1,
	&"ultimate": 1,
	&"power": 1,
	&"shield": 1,
}

var _linear := {"Master": 0.9, "BGM": 0.7, "SFX": 0.85}
var _muted := {"Master": false, "BGM": false, "SFX": false}

var _catalog: MusicCatalog
var _sfx_paths := {}
var _streams := {}
var _bgm: Array[AudioStreamPlayer] = []
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _active := 0
var _current_key := ""
var _fade: Tween
var _boss_stream: AudioStream
var _clearing := false
var _tree_paused := false
var _app_active := true
var _last_sfx := {}

signal settings_changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_settings()
	_apply_volumes()
	_catalog = load(CATALOG_PATH) as MusicCatalog
	_index_sfx()
	for i in 2:
		_bgm.append(_make_player(&"BGM", false))
	for i in SFX_POOL:
		_sfx_pool.append(_make_player(&"SFX", false))
	for i in UI_POOL:
		_ui_pool.append(_make_player(&"SFX", true))
	_connect_events()


func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused != _tree_paused:
		_tree_paused = paused
		_apply_suspend()


func _notification(what: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_set_app_active(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_set_app_active(true)


# ---------- 音量（UI 用） ----------

func linear_of(bus: String) -> float:
	return float(_linear.get(bus, 1.0))


func is_muted(bus: String) -> bool:
	return bool(_muted.get(bus, false))


func set_linear(bus: String, value: float) -> void:
	if not _linear.has(bus):
		return
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(float(_linear[bus]), value):
		return
	_linear[bus] = value
	_apply_volumes()
	_save_settings()
	settings_changed.emit()


func set_muted(bus: String, muted: bool) -> void:
	if not _muted.has(bus):
		return
	if bool(_muted[bus]) == muted:
		return
	_muted[bus] = muted
	_apply_volumes()
	_save_settings()
	settings_changed.emit()


## 給測試或除錯直接播一個音效 id（檔名不含副檔名）
func play_sfx(id: StringName) -> void:
	_play(id, id == &"ui" or id == &"ship_select")


# ---------- 內部：匯流排與存檔 ----------

func _ensure_buses() -> void:
	_ensure_bus(&"BGM")
	_ensure_bus(&"SFX")


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")


func _apply_volumes() -> void:
	var duck := PAUSE_DUCK_DB if (_tree_paused and _app_active) else 0.0
	_apply_bus(&"Master", 0.0)
	_apply_bus(&"BGM", duck)
	_apply_bus(&"SFX", 0.0)


func _apply_bus(bus: String, extra_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var linear := clampf(float(_linear[bus]), 0.0, 1.0)
	# 0 會讓 linear_to_db 變成 -inf，改成接近無聲
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)) + extra_db)
	AudioServer.set_bus_mute(idx, bool(_muted[bus]))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(GameManager.SAVE_PATH) != OK or not cfg.has_section("audio"):
		return
	for bus in _linear.keys():
		var key := String(bus).to_lower()
		_linear[bus] = clampf(float(cfg.get_value("audio", key, _linear[bus])), 0.0, 1.0)
		_muted[bus] = bool(cfg.get_value("audio", "mute_" + key, _muted[bus]))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(GameManager.SAVE_PATH)
	for bus in _linear.keys():
		var key := String(bus).to_lower()
		cfg.set_value("audio", key, float(_linear[bus]))
		cfg.set_value("audio", "mute_" + key, bool(_muted[bus]))
	cfg.save(GameManager.SAVE_PATH)


func _make_player(bus: StringName, ui: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.set_meta(&"ui", ui)
	p.set_meta(&"sid", &"")
	add_child(p)
	return p


func _set_app_active(active: bool) -> void:
	if _app_active == active:
		return
	_app_active = active
	_apply_suspend()


## 暫停選單：BGM 壓低、戰鬥音效凍結，UI 音效仍可播。
## 切到背景：全部暫停，回到前景再恢復。
func _apply_suspend() -> void:
	_apply_volumes()
	var freeze_gameplay := _tree_paused or not _app_active
	var freeze_all := not _app_active
	for p in _bgm:
		p.stream_paused = freeze_all
	for p in _sfx_pool:
		p.stream_paused = freeze_gameplay
	for p in _ui_pool:
		p.stream_paused = freeze_all


# ---------- BGM ----------

func _connect_events() -> void:
	Events.music_requested.connect(_on_music_requested)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.stage_cleared.connect(_on_stage_cleared)
	Events.weapon_fired.connect(_on_weapon_fired)
	Events.missile_fired.connect(func() -> void: _play(&"missile", false))
	Events.enemy_damaged.connect(func(_at: Vector2) -> void: _play(&"enemy_hit", false))
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_hurt.connect(func() -> void: _play(&"player_hit", false))
	Events.player_hit.connect(func() -> void: _play(&"player_death", false))
	Events.item_picked.connect(_on_item_picked)
	Events.bomb_used.connect(func(_at: Vector2) -> void: _play(&"bomb", false))
	Events.shield_blocked.connect(func(_at: Vector2) -> void: _play(&"shield_block", false))
	Events.boss_phase_changed.connect(func(_i: int) -> void: _play(&"boss_phase", false))
	Events.boss_ultimate.connect(_on_boss_ultimate)
	Events.stage_warning.connect(func(_t: String) -> void: _play(&"warning", false))
	Events.ui_pressed.connect(func() -> void: _play(&"ui", true))
	Events.ship_selected.connect(func() -> void: _play(&"ship_select", true))


func _on_music_requested(context: StringName) -> void:
	_clearing = false
	if context != &"boss":
		_boss_stream = null
	_play_context(context, FADE_SEC)


func _on_boss_spawned(boss: Node) -> void:
	_boss_stream = null
	_clearing = false
	if boss is Boss:
		var bd := (boss as Boss).boss_data()
		if bd:
			_boss_stream = bd.bgm
	_play_context(&"boss", 0.45)


func _on_boss_defeated() -> void:
	_resume_stage_after_boss.call_deferred()


func _resume_stage_after_boss() -> void:
	# 最終 Boss 會在同一個訊號裡順便發出 stage_cleared，那時候不要把關卡曲播回來
	if _clearing:
		return
	_boss_stream = null
	_play_context(&"stage", 0.55)


func _on_stage_cleared() -> void:
	_clearing = true
	_play(&"stage_clear", false)


func _on_weapon_fired(weapon_id: StringName, kind: StringName) -> void:
	var specific := StringName("shot_%s" % String(weapon_id))
	if _sfx_paths.has(specific):
		_play(specific, false)
	else:
		_play(StringName("shot_%s" % String(kind)), false)


func _on_enemy_killed(data: Resource, _at: Vector2) -> void:
	if data is BossData:
		_play(&"explode_boss", false)
		return
	var scale := 1.0
	if data is EnemyData:
		scale = (data as EnemyData).explosion_scale
	_play((&"explode_large" if scale >= 1.4 else &"explode_small"), false)


func _on_item_picked(item_type: int) -> void:
	match item_type:
		ItemData.Type.POWER, ItemData.Type.WEAPON, ItemData.Type.SPECIAL:
			_play(&"power", false)
		ItemData.Type.SHIELD:
			_play(&"shield", false)
		ItemData.Type.MISSILE:
			_play(&"missile", false)
		_:
			_play(&"item", false)


func _on_boss_ultimate(state: String) -> void:
	if state == "charge":
		_play(&"ultimate", false)


func _play_context(context: StringName, fade: float) -> void:
	var stream := _stream_for(context)
	if stream == null:
		return
	_crossfade(_prepare(stream, true), fade)


func _stream_for(context: StringName) -> AudioStream:
	if context == &"stage":
		var stage := GameManager.current_stage
		if stage and stage.bgm:
			return stage.bgm
	elif context == &"boss":
		if _boss_stream:
			return _boss_stream
	if _catalog == null:
		return null
	match context:
		&"title":
			return _catalog.title
		&"ship_select":
			return _catalog.ship_select
		&"stage":
			return _catalog.stage
		&"boss":
			return _catalog.boss
		&"result":
			return _catalog.result
	return null


var _shut := false


## 先停掉所有聲音。遊戲結束前呼叫，音訊執行緒才有機會放開 playback。
func silence() -> void:
	_shut = true
	if _fade and _fade.is_valid():
		_fade.kill()
		_fade = null
	for p in _bgm:
		p.stop()
		p.stream = null
	for p in _sfx_pool:
		p.stop()
		p.stream = null
	for p in _ui_pool:
		p.stop()
		p.stream = null


func _exit_tree() -> void:
	silence()
	_streams.clear()
	_boss_stream = null
	_catalog = null


func _prepare(src: AudioStream, loop: bool) -> AudioStream:
	if src == null:
		return null
	var key := "%s#%s" % [src.resource_path, "loop" if loop else "once"]
	if _streams.has(key):
		return _streams[key]
	# 直接改這份音檔的迴圈旗標。BGM 與音效是不同檔案，不必再 duplicate 一份。
	_apply_loop(src, loop)
	src.set_meta(&"audio_key", key)
	_streams[key] = src
	return src


func _apply_loop(s: AudioStream, loop: bool) -> void:
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	elif s is AudioStreamOggVorbis:
		s.set(&"loop", loop)
	elif s is AudioStreamMP3:
		s.set(&"loop", loop)


func _crossfade(stream: AudioStream, fade: float) -> void:
	if _shut or stream == null:
		return
	var key := String(stream.get_meta(&"audio_key", ""))
	if key != "" and key == _current_key and _bgm[_active].playing:
		return
	_current_key = key
	if _fade and _fade.is_valid():
		_fade.kill()
	var cur := _bgm[_active]
	var nxt := _bgm[1 - _active]
	nxt.stop()
	nxt.stream = stream
	nxt.volume_db = -36.0 if fade > 0.02 else 0.0
	# 人在背景時先標成暫停，避免 play() 在切換瞬間漏出聲音
	nxt.stream_paused = not _app_active
	_output_play(nxt)
	_active = 1 - _active
	if fade <= 0.02:
		cur.stop()
		return
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(nxt, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if cur.playing:
		_fade.tween_property(cur, "volume_db", -36.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_fade.chain().tween_callback(cur.stop)


# ---------- 音效池 ----------

func _index_sfx() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		push_warning("AudioManager: 找不到 %s" % SFX_DIR)
		return
	for file in dir.get_files():
		var name := String(file).trim_suffix(".remap")
		if name.ends_with(".import"):
			continue
		var ext := name.get_extension().to_lower()
		if ext != "wav" and ext != "ogg" and ext != "mp3":
			continue
		var id := StringName(name.get_basename())
		var path := SFX_DIR + name
		# 同一張檔名同時有 ogg 與 wav 時，用 ogg（正式曲通常是 ogg）
		if _sfx_paths.has(id) and ext != "ogg":
			continue
		_sfx_paths[id] = path


func _sfx_stream(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	if not _sfx_paths.has(id):
		_streams[id] = null
		return null
	var src := load(String(_sfx_paths[id])) as AudioStream
	var prepared := _prepare(src, false)
	_streams[id] = prepared
	return prepared


func _play(id: StringName, ui: bool) -> void:
	if _shut:
		return
	var stream := _sfx_stream(id)
	if stream == null:
		return
	var now := Time.get_ticks_msec() * 0.001
	var gap := float(THROTTLE.get(id, 0.0))
	var sid := String(id)
	if gap <= 0.0 and sid.begins_with("shot_"):
		gap = 0.07
	if now - float(_last_sfx.get(id, -100.0)) < gap:
		return
	var limit := int(VOICE_LIMIT.get(id, 2 if sid.begins_with("shot_") else 3))
	var pool := _ui_pool if ui else _sfx_pool
	var active := 0
	var free: AudioStreamPlayer = null
	for p in pool:
		if p.playing:
			if p.get_meta(&"sid", &"") == id:
				active += 1
		elif free == null:
			free = p
	if active >= limit or free == null:
		return
	_last_sfx[id] = now
	free.set_meta(&"sid", id)
	free.stream = stream
	free.pitch_scale = randf_range(0.97, 1.04) if _vary_pitch(id) else 1.0
	var freeze_all := not _app_active
	var freeze_gameplay := _tree_paused or not _app_active
	free.stream_paused = freeze_all if ui else freeze_gameplay
	_output_play(free)


func _output_play(p: AudioStreamPlayer) -> void:
	# 無頭模式的 Dummy 驅動在程序結束時，會把還掛在混音器上的 playback 洩漏成錯誤。
	# 照樣把音檔指定好、走完節流與播放池；真正的 play() 只在有音訊裝置時呼叫。
	if DisplayServer.get_name() == "headless":
		return
	p.play()


func _vary_pitch(id: StringName) -> bool:
	var sid := String(id)
	if sid.begins_with("shot_") and sid != "shot_laser" and sid != "shot_blue_laser" and sid != "shot_arc" and sid != "shot_arc_thunder":
		return true
	return id == &"enemy_hit" or id == &"explode_small" or id == &"item" or id == &"missile"
