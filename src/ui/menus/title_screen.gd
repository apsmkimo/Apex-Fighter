extends Control
## 標題畫面：整張背景圖（含 APEX FIGHTER 標題）＋ HI SCORE ＋ START 圖片按鈕。
## 所有元件放在一塊 720x1280 的「畫布」上，依螢幕比例等比放大到蓋滿，
## 這樣不論手機長寬比，按鈕都會對齊背景圖上設計好的位置。

const DESIGN := Vector2(720, 1280)
const BG := preload("res://assets/ui/title_bg.jpg")
const BTN_START := preload("res://assets/ui/btn_start.png")
## 按鈕在設計稿（720x1280）上的中心與寬度
const START_CENTER := Vector2(350, 959)
const START_WIDTH := 325.0
const HISCORE_Y := 630.0

var _canvas: Control
var _start: TextureButton
var _t := 0.0


func _ready() -> void:
	# 畫布外露出的部分（極長或極寬的螢幕）用深色填滿
	var fill := ColorRect.new()
	fill.color = Color(0.02, 0.02, 0.06)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fill)

	_canvas = Control.new()
	_canvas.size = DESIGN
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)

	var bg := TextureRect.new()
	bg.texture = BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = DESIGN
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(bg)
	# 上下邊緣淡出，接到外面的填色
	for top in [true, false]:
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.02, 0.06, 1.0 if top else 0.0))
		g.set_color(1, Color(0.02, 0.02, 0.06, 0.0 if top else 1.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		var edge := TextureRect.new()
		edge.texture = gt
		edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		edge.size = Vector2(DESIGN.x, 40)
		edge.position = Vector2(0, 0 if top else DESIGN.y - 40)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(edge)

	_canvas.add_child(_make_hiscore())

	_start = TextureButton.new()
	_start.texture_normal = BTN_START
	_start.ignore_texture_size = true
	_start.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var h := START_WIDTH * BTN_START.get_height() / BTN_START.get_width()
	_start.size = Vector2(START_WIDTH, h)
	_start.position = START_CENTER - _start.size / 2.0
	_start.pivot_offset = _start.size / 2.0
	_start.focus_mode = Control.FOCUS_NONE
	_start.button_down.connect(func(): _start.scale = Vector2.ONE * 0.94)
	_start.button_up.connect(func(): _start.scale = Vector2.ONE)
	# SMCPKG_SUPPORT>>>CursorM9TitleBtn
	# _start.pressed.connect(GameManager.goto_ship_select)
	_start.pressed.connect(func() -> void:
		Events.ui_pressed.emit()
		GameManager.goto_ship_select()
	)
	# SMCPKG_SUPPORT<<<CursorM9TitleBtnEnd
	_canvas.add_child(_start)

	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		var quit := UiKit.button("QUIT", 28, Vector2(200, 64))
		quit.position = Vector2(START_CENTER.x - 100, START_CENTER.y + 110)
		quit.pressed.connect(get_tree().quit)
		_canvas.add_child(quit)

	resized.connect(_fit)
	_fit()
	# SMCPKG_SUPPORT>>>CursorM9TitleAudio
	_build_audio()
	Events.music_requested.emit(&"title")
	# SMCPKG_SUPPORT<<<CursorM9TitleAudioEnd


## HI SCORE：金色字＋左右裝飾線，仿設計稿
func _make_hiscore() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gold := Color(1.0, 0.82, 0.35)
	row.add_child(_ornament(gold, false))
	var l := UiKit.label("HI SCORE  %d" % GameManager.hi_score, 34, gold)
	l.add_theme_color_override(&"font_outline_color", Color(0.25, 0.12, 0.0, 0.9))
	l.add_theme_constant_override(&"outline_size", 8)
	l.add_theme_color_override(&"font_shadow_color", Color(1.0, 0.6, 0.1, 0.45))
	l.add_theme_constant_override(&"shadow_outline_size", 14)
	l.add_theme_constant_override(&"shadow_offset_x", 0)
	l.add_theme_constant_override(&"shadow_offset_y", 0)
	row.add_child(l)
	row.add_child(_ornament(gold, true))
	row.size = Vector2(DESIGN.x, 50)
	row.position = Vector2(0, HISCORE_Y - 25)
	return row


## 一段裝飾線：細線＋菱形端點
func _ornament(c: Color, flip: bool) -> Control:
	var o := Control.new()
	o.custom_minimum_size = Vector2(70, 20)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.draw.connect(func():
		var y := 10.0
		var tip := 0.0 if not flip else 70.0
		var end := 70.0 if not flip else 0.0
		o.draw_line(Vector2(tip, y), Vector2(end, y), Color(c.r, c.g, c.b, 0.85), 2.0, true)
		var d := tip + (6.0 if not flip else -6.0)
		o.draw_colored_polygon(PackedVector2Array([
			Vector2(d - 5, y), Vector2(d, y - 5), Vector2(d + 5, y), Vector2(d, y + 5)]), c))
	return o


## 畫布等比放大並置中。盡量蓋滿螢幕，但左右最多只裁約 5%，避免標題被切到；
## 超長螢幕上下多出來的部分，用背景色＋漸層接起來。
func _fit() -> void:
	var s := minf(maxf(size.x / DESIGN.x, size.y / DESIGN.y), size.x / DESIGN.x * 1.1)
	_canvas.scale = Vector2(s, s)
	_canvas.position = (size - DESIGN * s) / 2.0


# SMCPKG_SUPPORT>>>CursorM9TitleAudioUi
func _build_audio() -> void:
	var audio_btn := UiKit.button("AUDIO", 26, Vector2(220, 64))
	audio_btn.position = Vector2(36, 1188)
	var panel := AudioPanel.new()
	panel.position = Vector2(90, 820)
	panel.visible = false
	audio_btn.pressed.connect(func() -> void: panel.visible = not panel.visible)
	panel.close_requested.connect(func() -> void: panel.visible = false)
	_canvas.add_child(panel)
	panel.enable_close()
	_canvas.add_child(audio_btn)
# SMCPKG_SUPPORT<<<CursorM9TitleAudioUiEnd


func _process(delta: float) -> void:
	# START 按鈕微微呼吸發光
	_t += delta
	if _start and not _start.is_pressed():
		var k := 1.0 + 0.12 * (0.5 + 0.5 * sin(_t * 3.0))
		_start.modulate = Color(k, k, k)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
