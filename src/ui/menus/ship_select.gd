extends Control
## 選機畫面（依設計稿）：銀河背景、左右滑動的戰機輪盤、機甲難度按鈕、LAUNCH / BACK。
## 戰機自動列出 Database.ships；之後新增戰機只要在 data/ships/ 加 .tres，輪盤會自動多一台。
##
## 輪盤規則：中間 scale 1.2、不透明、發光＋懸浮平台；兩側 scale 0.6、透明度 0.4、變暗＋模糊。
## 所有元件放在 720x1280 的設計畫布上，等比縮放對齊背景。

const DESIGN := Vector2(720, 1280)
const BG := preload("res://assets/ui/select_bg.jpg")
const LOGO := preload("res://assets/ui/title_logo.png")
const BTN_LAUNCH := preload("res://assets/ui/btn_launch.png")
const BTN_BACK := preload("res://assets/ui/btn_back.png")
const CARD_SHADER := preload("res://assets/shaders/ship_card.gdshader")
const GLOW_SHADER := preload("res://assets/shaders/ship_glow.gdshader")

## 輪盤中心、兩側距離、卡片基準大小
const WHEEL_CENTER := Vector2(360, 455)
const SIDE_OFFSET := 245.0
const CARD_SIZE := Vector2(260, 260)
const CENTER_SCALE := 1.2
const SIDE_SCALE := 0.6
const SIDE_ALPHA := 0.4
const GLOW_PAD := 1.5

const CYAN := Color(0.45, 0.85, 1.0)
const GOLD := Color(1.0, 0.82, 0.35)

var _canvas: Control
var _cards: Array[Control] = []
var _index := 0
## 輪盤目前位置（可以是小數，拖曳中／動畫中）
var _pos := 0.0
var _tween: Tween
var _dragging := false
var _drag_start_x := 0.0
var _drag_start_pos := 0.0
var _drag_moved := 0.0
var _t := 0.0

var _platform: Control
var _name: Label
var _desc: Label
var _stats: RichTextLabel
var _weapon: RichTextLabel
var _bars: Control
var _diff_row: HBoxContainer
var _launch: TextureButton
var _hud: HudFrame
var _arrows: Array[Button] = []


func _ready() -> void:
	var fill := ColorRect.new()
	fill.color = Color(0.01, 0.01, 0.04)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fill)
	_canvas = Control.new()
	_canvas.size = DESIGN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	_add_tex(BG, Vector2.ZERO, DESIGN)
	_add_tex(LOGO, Vector2(360 - 190, 62), Vector2(380, 380.0 * LOGO.get_height() / LOGO.get_width()))

	var title := _label("«  SELECT YOUR SHIP  »", 40, CYAN)
	title.add_theme_color_override(&"font_shadow_color", Color(0.2, 0.7, 1.0, 0.55))
	title.add_theme_constant_override(&"shadow_outline_size", 16)
	_place(title, 168, 52)

	_build_wheel()
	_build_info()
	_build_difficulty()
	_build_buttons()

	_hud = HudFrame.new()
	_hud.canvas = _canvas
	_hud.close_pressed.connect(GameManager.goto_title)
	add_child(_hud)

	var initial := GameManager.selected_ship if GameManager.selected_ship else null
	_index = maxi(Database.ships.find(initial), 0)
	_pos = _index
	_update_info()
	_hud.ship_class = Database.ships[_index].ship_class if not Database.ships.is_empty() else "A"

	resized.connect(_fit)
	_fit()
	# SMCPKG_SUPPORT>>>CursorM9SelectMusic
	Events.music_requested.emit(&"ship_select")
	# SMCPKG_SUPPORT<<<CursorM9SelectMusicEnd


# ---------------------------------------------------------------- 輪盤

func _build_wheel() -> void:
	# 懸浮平台（畫在戰機底下）
	_platform = Control.new()
	_platform.size = Vector2(420, 140)
	_platform.position = Vector2(WHEEL_CENTER.x - 210, WHEEL_CENTER.y + 85)
	_platform.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_platform.draw.connect(_draw_platform)
	_canvas.add_child(_platform)

	for ship in Database.ships:
		var card := Control.new()
		card.size = CARD_SIZE
		card.pivot_offset = CARD_SIZE / 2.0
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex: Texture2D = ship.portrait if ship.portrait else ship.texture

		var glow := TextureRect.new()
		glow.name = "Glow"
		glow.texture = tex
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glow.size = CARD_SIZE * GLOW_PAD
		glow.position = -CARD_SIZE * (GLOW_PAD - 1.0) / 2.0
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gm := ShaderMaterial.new()
		gm.shader = GLOW_SHADER
		gm.set_shader_parameter(&"glow_color", ship.ui_glow)
		gm.set_shader_parameter(&"pad", GLOW_PAD)
		glow.material = gm
		card.add_child(glow)

		var img := TextureRect.new()
		img.name = "Ship"
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size = CARD_SIZE
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cm := ShaderMaterial.new()
		cm.shader = CARD_SHADER
		img.material = cm
		card.add_child(img)

		if not ship.unlocked:
			var lock := _label("LOCKED", 34, Color(1, 1, 1, 0.9))
			lock.size = Vector2(CARD_SIZE.x, 50)
			lock.position = Vector2(0, CARD_SIZE.y / 2.0 - 25)
			card.add_child(lock)

		_canvas.add_child(card)
		_cards.append(card)

	# 滑動區（透明，接收拖曳與點擊）
	var swipe := Control.new()
	swipe.position = Vector2(0, WHEEL_CENTER.y - 220)
	swipe.size = Vector2(DESIGN.x, 440)
	swipe.mouse_filter = Control.MOUSE_FILTER_STOP
	swipe.gui_input.connect(_on_swipe_input)
	_canvas.add_child(swipe)

	# 左右箭頭
	for dir in [-1, 1]:
		var arrow := Button.new()
		arrow.flat = true
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.size = Vector2(64, 110)
		arrow.position = Vector2(4 if dir < 0 else DESIGN.x - 68, WHEEL_CENTER.y + 10)
		arrow.draw.connect(_draw_arrow.bind(arrow, dir))
		arrow.pressed.connect(_step.bind(dir))
		_canvas.add_child(arrow)
		_arrows.append(arrow)


func _draw_arrow(b: Button, dir: int) -> void:
	var c := b.size / 2.0
	var pulse := 0.65 + 0.35 * sin(_t * 4.0 + (0.0 if dir > 0 else PI))
	var col := Color(CYAN.r, CYAN.g, CYAN.b, pulse)
	var w := 14.0 * dir
	var pts := PackedVector2Array([c + Vector2(-w, -24), c + Vector2(w, 0), c + Vector2(-w, 24)])
	b.draw_polyline(pts, Color(col, col.a * 0.35), 10.0, true)
	b.draw_polyline(pts, col, 4.0, true)


func _draw_platform() -> void:
	var c := _platform.size / 2.0
	var cyan := Color(0.35, 0.85, 1.0)
	var pulse := 0.8 + 0.2 * sin(_t * 2.5)
	# 底光
	for i in 6:
		var k := 1.0 - i / 6.0
		_ellipse(c, 175.0 * k, 42.0 * k, Color(cyan, 0.06 * pulse), true)
	# 外環、內環
	_ellipse(c, 180, 44, Color(cyan, 0.75 * pulse), false, 2.5)
	_ellipse(c, 130, 31, Color(cyan, 0.5 * pulse), false, 1.5)
	_ellipse(c, 80, 19, Color(cyan, 0.85 * pulse), false, 2.0)
	# 旋轉的刻度
	for i in 24:
		var a := _t * 0.6 + i * TAU / 24.0
		var p1 := c + Vector2(cos(a) * 150, sin(a) * 36)
		var p2 := c + Vector2(cos(a) * 162, sin(a) * 39)
		_platform.draw_line(p1, p2, Color(cyan, 0.7 * pulse), 2.0, true)
	# 往上的光束
	var beam := PackedVector2Array([c + Vector2(-80, 0), c + Vector2(80, 0), c + Vector2(40, -150), c + Vector2(-40, -150)])
	_platform.draw_colored_polygon(beam, Color(cyan, 0.07 * pulse))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color, filled: bool, width := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 49:
		var a := i * TAU / 48.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	if filled:
		_platform.draw_colored_polygon(pts, col)
	else:
		_platform.draw_polyline(pts, col, width, true)


func _layout_wheel() -> void:
	var n := _cards.size()
	for i in n:
		var r := float(i) - _pos
		if n > 2:   # 環狀：最左邊的下一台是最右邊
			r = fposmod(r + n / 2.0, n) - n / 2.0
		var k := clampf(absf(r), 0.0, 1.0)
		var card := _cards[i]
		var s := lerpf(CENTER_SCALE, SIDE_SCALE, k)
		var bob := sin(_t * 2.0) * 6.0 * (1.0 - k)
		card.scale = Vector2(s, s)
		card.position = WHEEL_CENTER - CARD_SIZE / 2.0 + Vector2(r * SIDE_OFFSET, k * 40.0 + bob)
		card.modulate.a = lerpf(1.0, SIDE_ALPHA, k) * clampf(2.0 - absf(r), 0.0, 1.0)
		card.visible = absf(r) < 1.9
		card.z_index = 10 - int(absf(r) * 5.0)
		var ship_mat := (card.get_node("Ship") as TextureRect).material as ShaderMaterial
		ship_mat.set_shader_parameter(&"blur", 0.022 * k)
		ship_mat.set_shader_parameter(&"dim", 0.3 * k)
		var glow_mat := (card.get_node("Glow") as TextureRect).material as ShaderMaterial
		glow_mat.set_shader_parameter(&"strength", (1.0 - k) * (0.9 + 0.25 * sin(_t * 3.0)))


func _on_swipe_input(event: InputEvent) -> void:
	var pressed_event: bool = event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	if pressed_event:
		if event.pressed:
			_dragging = true
			_drag_start_x = event.position.x
			_drag_start_pos = _pos
			_drag_moved = 0.0
			if _tween:
				_tween.kill()
		elif _dragging:
			_dragging = false
			_release(event.position.x)
	elif _dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		var dx: float = event.position.x - _drag_start_x
		_drag_moved = maxf(_drag_moved, absf(dx))
		_pos = _drag_start_pos - dx / SIDE_OFFSET


func _release(x: float) -> void:
	if _drag_moved < 12.0:
		# 點擊：點到兩側的戰機就轉過去
		if x < WHEEL_CENTER.x - 130:
			_step(-1)
		elif x > WHEEL_CENTER.x + 130:
			_step(1)
		else:
			_snap_to(_index)
		return
	var dx := x - _drag_start_x
	var target := roundi(_pos)
	if absf(dx) > 50.0 and target == _index:
		target = _index - int(signf(dx))   # 滑動夠遠就至少換一台
	_snap_to(target)


func _step(dir: int) -> void:
	_snap_to(_index + dir)


func _snap_to(target: int) -> void:
	var n := _cards.size()
	if n == 0:
		return
	if n <= 2:
		target = clampi(target, 0, n - 1)
	# 讓 _pos 走最短的路徑到 target
	var new_index := posmod(target, n)
	var dest := float(target)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_pos", dest, 0.28)
	_tween.tween_callback(func(): _pos = fposmod(_pos, n) if n > 2 else _pos)
	if new_index != _index:
		_index = new_index
		_update_info()
		# SMCPKG_SUPPORT>>>CursorM9ShipSfx
		Events.ship_selected.emit()
		# SMCPKG_SUPPORT<<<CursorM9ShipSfxEnd


# ---------------------------------------------------------------- 資訊

func _build_info() -> void:
	_name = _label("", 54, Color.WHITE)
	_name.add_theme_color_override(&"font_shadow_color", Color(0.3, 0.75, 1.0, 0.6))
	_name.add_theme_constant_override(&"shadow_outline_size", 14)
	_place(_name, 646, 66)

	_desc = _label("", 21, Color(0.85, 0.9, 1.0))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(620, 54)
	_desc.position = Vector2(50, 714)
	_canvas.add_child(_desc)

	_stats = _rich(760)
	_weapon = _rich(794)

	_bars = Control.new()
	_bars.size = Vector2(600, 50)
	_bars.position = Vector2(60, 832)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	_canvas.add_child(_bars)


func _rich(y: float) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.add_theme_font_size_override(&"normal_font_size", 25)
	r.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	r.add_theme_constant_override(&"outline_size", 6)
	r.size = Vector2(DESIGN.x, 34)
	r.position = Vector2(0, y)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(r)
	return r


func _update_info() -> void:
	if Database.ships.is_empty():
		return
	var ship: ShipData = Database.ships[_index]
	_name.text = ship.display_name
	_desc.text = ship.description
	var g := GOLD.to_html(false)
	var dot := "[color=#8899aa]  ·  [/color]"
	_stats.text = "[center][color=#%s]SPEED[/color]%s%d%s[color=#%s]LIFE[/color]%s%d%s[color=#%s]BOMB[/color]%s%d[/center]" % [
		g, dot, int(ship.speed), dot, g, dot, ship.start_lives, dot, g, dot, ship.start_bombs]
	var wname := ship.weapon.display_name if ship.weapon else "-"
	_weapon.text = "[center][color=#%s]WEAPON[/color]   %s[/center]" % [g, wname]
	_bars.queue_redraw()
	if _hud:
		_hud.ship_class = ship.ship_class
	if _launch:
		_launch.disabled = not ship.unlocked
		_launch.modulate.a = 1.0 if ship.unlocked else 0.4


func _draw_bars() -> void:
	if Database.ships.is_empty():
		return
	var ship: ShipData = Database.ships[_index]
	var vals := [clampf(ship.speed / 650.0, 0.1, 1.0), ship.stat_maneuver, ship.stat_firepower]
	var names := ["SPEED", "MANEUVER", "FIREPOWER"]
	var font := get_theme_default_font()
	var col_w := 190.0
	for i in 3:
		var x := i * (col_w + 15.0)
		_bars.draw_string(font, Vector2(x, 14), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.85, 0.9, 1.0, 0.9))
		var segs := 10
		var sw := (col_w - (segs - 1) * 3.0) / segs
		var filled := roundi(vals[i] * segs)
		for s in segs:
			var r := Rect2(x + s * (sw + 3.0), 24, sw, 9)
			var on := s < filled
			_bars.draw_rect(r, Color(CYAN, 0.95) if on else Color(0.4, 0.5, 0.6, 0.35))


# ---------------------------------------------------------------- 難度

func _build_difficulty() -> void:
	_diff_row = HBoxContainer.new()
	_diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_diff_row.add_theme_constant_override(&"separation", 18)
	_diff_row.size = Vector2(DESIGN.x, 66)
	_diff_row.position = Vector2(0, 892)
	_canvas.add_child(_diff_row)
	for d in Database.difficulties:
		var b := Button.new()
		b.text = d.display_name
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(196, 64)
		b.add_theme_font_size_override(&"font_size", 28)
		b.pressed.connect(_select_difficulty.bind(d))
		_diff_row.add_child(b)
	_refresh_difficulty()


## 機甲膠囊按鈕：選中的那顆用難度顏色發光
func _capsule_style(c: Color, selected: bool, pressed_look := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.1, 0.92) if not selected else Color(c.r * 0.12, c.g * 0.18, c.b * 0.14, 0.95)
	if pressed_look:
		sb.bg_color = sb.bg_color.lightened(0.08)
	sb.set_corner_radius_all(14)
	sb.corner_detail = 6
	sb.set_border_width_all(3 if selected else 2)
	sb.border_color = c if selected else Color(0.5, 0.56, 0.64, 0.9)
	sb.shadow_color = Color(c.r, c.g, c.b, 0.55) if selected else Color(0, 0, 0, 0.5)
	sb.shadow_size = 12 if selected else 4
	sb.anti_aliasing = true
	return sb


func _select_difficulty(d: DifficultyData) -> void:
	# SMCPKG_SUPPORT>>>CursorM9DiffSfx
	Events.ui_pressed.emit()
	# SMCPKG_SUPPORT<<<CursorM9DiffSfxEnd
	GameManager.set_difficulty(d)
	_refresh_difficulty()


func _refresh_difficulty() -> void:
	for i in _diff_row.get_child_count():
		var b := _diff_row.get_child(i) as Button
		var d: DifficultyData = Database.difficulties[i]
		var sel := d == GameManager.difficulty
		b.button_pressed = sel
		for st in [&"normal", &"hover", &"focus", &"disabled"]:
			b.add_theme_stylebox_override(st, _capsule_style(d.color, sel))
		for st in [&"pressed", &"hover_pressed"]:
			b.add_theme_stylebox_override(st, _capsule_style(d.color, sel, true))
		var fc := d.color if sel else Color(0.92, 0.95, 1.0)
		for k in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
			b.add_theme_color_override(k, fc)
		b.text = ("»  %s  «" % d.display_name) if sel else d.display_name


# ---------------------------------------------------------------- 按鈕

func _build_buttons() -> void:
	_launch = _image_button(BTN_LAUNCH, Vector2(360, 1062), 560.0)
	_launch.pressed.connect(_on_launch)
	var back := _image_button(BTN_BACK, Vector2(360, 1214), 290.0)
	back.pressed.connect(GameManager.goto_title)


func _image_button(tex: Texture2D, center: Vector2, width: float) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.size = Vector2(width, width * tex.get_height() / tex.get_width())
	b.position = center - b.size / 2.0
	b.pivot_offset = b.size / 2.0
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(func(): b.scale = Vector2.ONE * 0.94)
	b.button_up.connect(func(): b.scale = Vector2.ONE)
	# SMCPKG_SUPPORT>>>CursorM9ImageBtn
	b.pressed.connect(func() -> void: Events.ui_pressed.emit())
	# SMCPKG_SUPPORT<<<CursorM9ImageBtnEnd
	_canvas.add_child(b)
	return b


func _on_launch() -> void:
	if Database.ships.is_empty():
		return
	var ship: ShipData = Database.ships[_index]
	if not ship.unlocked:
		return
	GameManager.selected_ship = ship
	GameManager.goto_map()


# ---------------------------------------------------------------- 共用

func _process(delta: float) -> void:
	_t += delta
	_layout_wheel()
	_platform.queue_redraw()
	for c in _canvas.get_children():
		if c is Button and (c as Button).flat:
			c.queue_redraw()
	if _launch and not _launch.disabled and not _launch.is_pressed():
		var k := 1.0 + 0.1 * (0.5 + 0.5 * sin(_t * 3.0))
		_launch.modulate = Color(k, k, k)


func _add_tex(tex: Texture2D, pos: Vector2, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(r)
	return r


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := UiKit.label(text, font_size, color)
	l.add_theme_constant_override(&"shadow_offset_x", 0)
	l.add_theme_constant_override(&"shadow_offset_y", 0)
	return l


func _place(l: Label, y: float, h: float) -> void:
	l.size = Vector2(DESIGN.x, h)
	l.position = Vector2(0, y)
	_canvas.add_child(l)


## 等比縮放蓋滿螢幕，左右最多裁約 5%
func _fit() -> void:
	var s := minf(maxf(size.x / DESIGN.x, size.y / DESIGN.y), size.x / DESIGN.x * 1.1)
	_canvas.scale = Vector2(s, s)
	_canvas.position = (size - DESIGN * s) / 2.0
	# 箭頭貼齊實際螢幕左右邊，長螢幕裁切時才不會被切掉
	for i in _arrows.size():
		var a := _arrows[i]
		var screen_x := 10.0 * s if i == 0 else size.x - 10.0 * s - a.size.x * s
		a.position.x = (screen_x - _canvas.position.x) / s


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameManager.goto_title()
