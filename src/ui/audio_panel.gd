class_name AudioPanel
extends PanelContainer
## 主音量／BGM／音效的拉桿與靜音。只讀寫 AudioManager，本身不播放聲音以外的邏輯。

signal close_requested

var _box: VBoxContainer
var _syncing := false
var _sliders := {}
var _mutes := {}


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.12, 0.9)
	sb.border_color = NeonDraw.CYAN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(NeonDraw.CYAN.r, NeonDraw.CYAN.g, NeonDraw.CYAN.b, 0.35)
	sb.shadow_size = 8
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	add_theme_stylebox_override(&"panel", sb)
	custom_minimum_size = Vector2(520, 0)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 8)
	add_child(_box)
	_box.add_child(UiKit.label("AUDIO", 28, NeonDraw.CYAN))
	_add_row(&"Master", "MASTER")
	_add_row(&"BGM", "BGM")
	_add_row(&"SFX", "SFX")
	AudioManager.settings_changed.connect(_refresh)
	_refresh()


## 標題畫面的彈出面板用：多一顆關閉鈕
func enable_close() -> void:
	var close := UiKit.button("CLOSE", 22, Vector2(200, 52))
	close.pressed.connect(func() -> void: close_requested.emit())
	_box.add_child(close)


func _add_row(bus: StringName, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var lab := UiKit.label(title, 22, NeonDraw.CYAN)
	lab.custom_minimum_size = Vector2(108, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(lab)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(240, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	_style_slider(slider)
	slider.value_changed.connect(func(v: float) -> void:
		if _syncing:
			return
		AudioManager.set_linear(bus, v / 100.0)
	)
	row.add_child(slider)
	_sliders[bus] = slider

	var mute := Button.new()
	mute.toggle_mode = true
	mute.focus_mode = Control.FOCUS_NONE
	mute.custom_minimum_size = Vector2(96, 44)
	mute.add_theme_font_size_override(&"font_size", 20)
	mute.pressed.connect(func() -> void:
		if _syncing:
			return
		AudioManager.set_muted(bus, mute.button_pressed)
		Events.ui_pressed.emit()
	)
	row.add_child(mute)
	_mutes[bus] = mute
	_box.add_child(row)


func _style_slider(slider: HSlider) -> void:
	var col := NeonDraw.CYAN
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.04, 0.07, 0.14, 0.95)
	track.border_color = Color(col.r, col.g, col.b, 0.55)
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	slider.add_theme_stylebox_override(&"slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(3)
	slider.add_theme_stylebox_override(&"grabber_area", fill)
	var hi := fill.duplicate() as StyleBoxFlat
	hi.bg_color = col.lightened(0.2)
	slider.add_theme_stylebox_override(&"grabber_area_highlight", hi)


func _refresh() -> void:
	_syncing = true
	for bus in _sliders:
		var slider: HSlider = _sliders[bus]
		slider.value = round(AudioManager.linear_of(bus) * 100.0)
		var mute: Button = _mutes[bus]
		mute.button_pressed = AudioManager.is_muted(bus)
		mute.text = "MUTE" if mute.button_pressed else "ON"
	_syncing = false
