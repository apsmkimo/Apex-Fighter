class_name Hud
extends CanvasLayer
## 遊戲中介面：分數、最高分、殘機、炸彈、火力、Boss 血條、WARNING、炸彈與暫停按鈕、暫停選單。
## 只監聽 Events 的訊號，不直接讀遊戲物件。

var _score: Label
var _hi: Label
var _lives: Label
var _bombs: Label
var _power: Label
var _weapon: Label
var _missile: Label
var _center: Label
var _boss_bar: ProgressBar
var _boss_name: Label
var _pause_panel: Control
var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Events.score_changed.connect(_on_score)
	Events.hi_score_changed.connect(_on_hi)
	Events.lives_changed.connect(_on_lives)
	Events.bombs_changed.connect(_on_bombs)
	Events.power_changed.connect(_on_power)
	Events.weapon_changed.connect(_on_weapon)
	Events.missile_changed.connect(_on_missile)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_hp_changed.connect(_on_boss_hp)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.stage_warning.connect(_on_warning)
	Events.stage_cleared.connect(_on_stage_cleared)
	Events.game_over.connect(_on_game_over)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 讓觸控穿透到遊戲
	add_child(_root)

	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 16
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	_score = UiKit.label("SCORE 0", 30)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_score)
	_hi = UiKit.label("HI 0", 26, Color(1, 0.85, 0.4))
	_hi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_hi)
	var pause_btn := UiKit.button("II", 30, Vector2(72, 60))
	pause_btn.pressed.connect(toggle_pause)
	top.add_child(pause_btn)

	_boss_name = UiKit.label("", 22, Color(1, 0.6, 0.8))
	_boss_name.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_name.offset_top = 84
	_boss_name.visible = false
	_root.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_bar.offset_left = 40
	_boss_bar.offset_right = -40
	_boss_bar.offset_top = 114
	_boss_bar.offset_bottom = 132
	_boss_bar.max_value = 1.0
	_boss_bar.step = 0.0
	_boss_bar.show_percentage = false
	_boss_bar.visible = false
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1, 0.3, 0.5)
	_boss_bar.add_theme_stylebox_override(&"fill", fill)
	_root.add_child(_boss_bar)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 20
	bottom.offset_top = -230
	bottom.offset_bottom = -20
	bottom.offset_right = 300
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	_lives = UiKit.label("LIFE 3", 26)
	_bombs = UiKit.label("BOMB 3", 26, Color(0.5, 1, 0.6))
	_power = UiKit.label("POWER 1", 26, Color(1, 0.5, 0.5))
	_weapon = UiKit.label("VULCAN", 26, Color(0.5, 0.85, 1))
	_missile = UiKit.label("", 26, Color(0.4, 1, 0.7))
	for l in [_lives, _bombs, _power, _weapon, _missile]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		bottom.add_child(l)

	var bomb_btn := UiKit.button("BOMB", 30, Vector2(150, 150))
	bomb_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bomb_btn.offset_left = -180
	bomb_btn.offset_top = -180
	bomb_btn.offset_right = -30
	bomb_btn.offset_bottom = -30
	bomb_btn.modulate = Color(1, 1, 1, 0.6)
	bomb_btn.button_down.connect(_on_bomb_pressed)
	_root.add_child(bomb_btn)

	_center = UiKit.label("", 64, Color(1, 0.35, 0.35))
	_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_center)

	_pause_panel = Control.new()
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_panel.add_child(dim)
	add_child(_pause_panel)
	var col := UiKit.centered_column(_pause_panel)
	col.add_child(UiKit.label("PAUSED", 56))
	var resume := UiKit.button("RESUME")
	resume.pressed.connect(toggle_pause)
	col.add_child(resume)
	var quit := UiKit.button("TITLE")
	quit.pressed.connect(GameManager.goto_title)
	col.add_child(quit)


func toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_pause_panel.visible = paused


func show_stage_title(text: String) -> void:
	_flash_text(text, Color(0.6, 0.9, 1.0), 2.0)


func _flash_text(text: String, color: Color, seconds: float) -> void:
	_center.text = text
	_center.add_theme_color_override(&"font_color", color)
	_center.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(_center, "modulate:a", 0.0, 0.5)


func _on_bomb_pressed() -> void:
	if Player.instance and not get_tree().paused:
		Player.instance.use_bomb()


func _on_score(v: int) -> void:
	_score.text = "SCORE %d" % v


func _on_hi(v: int) -> void:
	_hi.text = "HI %d" % v


func _on_lives(v: int) -> void:
	_lives.text = "LIFE %d" % v


func _on_bombs(v: int) -> void:
	_bombs.text = "BOMB %d" % v


func _on_power(level: int, max_level: int) -> void:
	_power.text = "POWER MAX" if level >= max_level - 1 else "POWER %d" % (level + 1)


func _on_weapon(w: Resource) -> void:
	_weapon.text = (w as WeaponData).display_name.to_upper() if w else ""


func _on_missile(level: int) -> void:
	_missile.text = "" if level <= 0 else ("MISSILE MAX" if level >= GameManager.MAX_MISSILE_LEVEL else "MISSILE %d" % level)


func _on_boss_spawned(boss: Node) -> void:
	_boss_bar.value = 1.0
	_boss_bar.visible = true
	_boss_name.visible = true
	if boss is Boss:
		_boss_name.text = (boss as Boss).boss_data().boss_name


func _on_boss_hp(ratio: float) -> void:
	_boss_bar.value = ratio


func _on_boss_defeated() -> void:
	_boss_bar.visible = false
	_boss_name.visible = false


func _on_warning(text: String) -> void:
	_center.text = text
	_center.add_theme_color_override(&"font_color", Color(1, 0.3, 0.3))
	_center.modulate.a = 1.0
	var tw := create_tween().set_loops(4)
	tw.tween_property(_center, "modulate:a", 0.15, 0.3)
	tw.tween_property(_center, "modulate:a", 1.0, 0.3)
	tw.finished.connect(func() -> void: _center.modulate.a = 0.0)


func _on_stage_cleared() -> void:
	_flash_text("STAGE CLEAR", Color(0.5, 1, 0.7), 3.0)


func _on_game_over() -> void:
	_flash_text("GAME OVER", Color(1, 0.4, 0.4), 2.0)
