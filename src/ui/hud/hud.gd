class_name Hud
extends CanvasLayer
## 遊戲中介面（霓虹科技風）：
## - 上方：SCORE／HI SCORE（小標題＋大數字）、暫停鈕、Boss 發光血條
## - 左下：HudStatusPanel（分段 HP 條＋圖示數字）
## - 右下：BombButton（大圓形炸彈鈕）
## - 中央：StageBanner（STAGE／WARNING／CLEAR／GAME OVER 動畫提示）
## - 全畫面：受擊紅閃／護盾藍閃的邊緣光暈
## 只監聽 Events 的訊號，不直接讀遊戲物件（炸彈鈕除外，按下時呼叫 Player.instance）。

var _score: Label
var _hi: Label
var _status: HudStatusPanel
var _bomb_btn: BombButton
var _banner: StageBanner
var _vignette: TextureRect
var _boss_bar: ProgressBar
var _boss_name: Label
var _pause_panel: Control
var _root: Control
var _last_hp := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Events.score_changed.connect(_on_score)
	Events.hi_score_changed.connect(_on_hi)
	Events.lives_changed.connect(func(v: int) -> void: _status.lives = v; _status.queue_redraw())
	Events.bombs_changed.connect(_on_bombs)
	Events.power_changed.connect(func(lv: int, _m: int) -> void: _status.power = lv; _status.queue_redraw())
	Events.weapon_changed.connect(_on_weapon)
	Events.missile_changed.connect(func(lv: int) -> void: _status.missile = lv; _status.queue_redraw())
	Events.player_hp_changed.connect(_on_hp)
	Events.shield_changed.connect(func(s: float) -> void: _status.shield = s; _status.queue_redraw())
	Events.shield_blocked.connect(func(_p: Vector2) -> void: _flash_vignette(Color(0.3, 0.85, 1.0), 0.5))
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_hp_changed.connect(_on_boss_hp)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.boss_ultimate.connect(_on_boss_ultimate)
	Events.stage_warning.connect(_on_warning)
	Events.stage_cleared.connect(_on_stage_cleared)
	Events.game_over.connect(_on_game_over)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 讓觸控穿透到遊戲
	add_child(_root)

	# 受擊光暈（最底層，不擋觸控）
	_vignette = TextureRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.texture = _make_vignette_tex()
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate = Color(1, 1, 1, 0)
	_root.add_child(_vignette)

	# ---- 上方 ----
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22
	top.offset_right = -20
	top.offset_top = 14
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	var score_box := _stat_box("SCORE", NeonDraw.CYAN, HORIZONTAL_ALIGNMENT_LEFT)
	_score = score_box.get_child(1)
	top.add_child(score_box)
	var hi_box := _stat_box("HI SCORE", NeonDraw.AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	_hi = hi_box.get_child(1)
	top.add_child(hi_box)
	var pause_btn := _neon_button("II", 30, Vector2(76, 64), NeonDraw.CYAN)
	pause_btn.pressed.connect(toggle_pause)
	top.add_child(pause_btn)

	_boss_name = UiKit.label("", 22, Color(1, 0.55, 0.9))
	_boss_name.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_name.offset_top = 96
	_boss_name.visible = false
	_root.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_bar.offset_left = 44
	_boss_bar.offset_right = -44
	_boss_bar.offset_top = 128
	_boss_bar.offset_bottom = 144
	_boss_bar.max_value = 1.0
	_boss_bar.step = 0.0
	_boss_bar.show_percentage = false
	_boss_bar.visible = false
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = NeonDraw.MAGENTA
	fill.set_corner_radius_all(3)
	fill.shadow_color = Color(1, 0.3, 0.85, 0.6)   # shadow 當成外發光
	fill.shadow_size = 8
	_boss_bar.add_theme_stylebox_override(&"fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.02, 0.1, 0.75)
	bg.border_color = Color(1, 0.3, 0.85, 0.7)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(3)
	_boss_bar.add_theme_stylebox_override(&"background", bg)
	_root.add_child(_boss_bar)

	# ---- 左下狀態面板 ----
	_status = HudStatusPanel.new()
	_root.add_child(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE, 16)
	_status.offset_bottom = -18
	_status.offset_top = -18 - HudStatusPanel.H

	# ---- 右下炸彈鈕 ----
	_bomb_btn = BombButton.new()
	_root.add_child(_bomb_btn)
	_bomb_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 18)
	_bomb_btn.pressed.connect(_on_bomb_pressed)

	# ---- 中央提示 ----
	_banner = StageBanner.new()
	_root.add_child(_banner)

	# ---- 暫停選單 ----
	_pause_panel = Control.new()
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.06, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_panel.add_child(dim)
	add_child(_pause_panel)
	var col := UiKit.centered_column(_pause_panel)
	col.add_child(UiKit.label("PAUSED", 56, NeonDraw.CYAN))
	var resume := _neon_button("RESUME", 34, Vector2(360, 92), NeonDraw.CYAN)
	resume.pressed.connect(toggle_pause)
	col.add_child(resume)
	var quit := _neon_button("TITLE", 34, Vector2(360, 92), NeonDraw.MAGENTA)
	quit.pressed.connect(GameManager.goto_title)
	col.add_child(quit)


## 小標題＋大數字
func _stat_box(title: String, col: Color, align: HorizontalAlignment) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", -6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UiKit.label(title, 18, col)
	t.horizontal_alignment = align
	box.add_child(t)
	var v := UiKit.label("0", 34, Color.WHITE)
	v.horizontal_alignment = align
	v.add_theme_color_override(&"font_shadow_color", Color(col.r, col.g, col.b, 0.5))
	box.add_child(v)
	return box


## 霓虹外框按鈕（StyleBoxFlat 的 shadow 當外發光）
func _neon_button(text: String, font_size: int, min_size: Vector2, col: Color) -> Button:
	var b := UiKit.button(text, font_size, min_size)
	for state in [&"normal", &"hover", &"pressed", &"focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.05, 0.14, 0.7) if state != &"pressed" else Color(col.r, col.g, col.b, 0.35)
		sb.border_color = col
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.shadow_color = Color(col.r, col.g, col.b, 0.45)
		sb.shadow_size = 6
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override(&"font_color", col.lightened(0.4))
	b.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	b.add_theme_color_override(&"font_outline_color", NeonDraw.OUTLINE)
	b.add_theme_constant_override(&"outline_size", 6)
	return b


## 邊緣光暈貼圖：中間透明、四周不透明（白色，用 modulate 上色）
func _make_vignette_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0.85))
	g.set_offset(0, 0.55)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.05, 0.5)
	t.width = 128
	t.height = 128
	return t


func _flash_vignette(col: Color, strength: float) -> void:
	_vignette.modulate = Color(col.r, col.g, col.b, strength)
	var tw := create_tween()
	tw.tween_property(_vignette, "modulate:a", 0.0, 0.45)


func toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_pause_panel.visible = paused


func show_stage_title(text: String) -> void:
	_banner.play(text, "MISSION START", NeonDraw.CYAN, 2.6)


func _on_bomb_pressed() -> void:
	if Player.instance and not get_tree().paused:
		Player.instance.use_bomb()


func _on_score(v: int) -> void:
	_score.text = str(v)


func _on_hi(v: int) -> void:
	_hi.text = str(v)


func _on_bombs(v: int) -> void:
	_status.bombs = v
	_status.queue_redraw()
	_bomb_btn.count = v


func _on_weapon(w: Resource) -> void:
	var wd := w as WeaponData
	if wd == null:
		return
	_status.weapon_name = wd.display_name.to_upper()
	_status.weapon_color = wd.laser_color if wd.kind == WeaponData.Kind.LASER else NeonFx.tex_color(wd.bullet_texture)
	_status.queue_redraw()


func _on_hp(hp: int, max_hp: int) -> void:
	if _last_hp >= 0 and hp < _last_hp:
		_flash_vignette(NeonDraw.RED, 0.75)   # 受擊紅閃
	_last_hp = hp
	_status.set_hp(hp, max_hp)


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


func _on_boss_ultimate(state: String) -> void:
	if state == "charge":
		_banner.play("DANGER", "ENERGY SURGE DETECTED", NeonDraw.MAGENTA, 1.8, true)


func _on_warning(text: String) -> void:
	_banner.play(text, "HUGE ENEMY APPROACHING", NeonDraw.RED, 3.0, true)


func _on_stage_cleared() -> void:
	_banner.play("STAGE CLEAR", "MISSION COMPLETE", NeonDraw.GREEN, 3.2)


func _on_game_over() -> void:
	_banner.play("GAME OVER", "SIGNAL LOST", NeonDraw.RED, 2.2)
