class_name UiKit
extends RefCounted
## 共用的 UI 小工具，讓各畫面風格一致。

const ACCENT := Color(0.45, 0.8, 1.0)


static func label(text: String, size := 32, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override(&"outline_size", 6)
	# 陰影當成柔和外光，確保在星空背景上清楚
	l.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override(&"shadow_offset_x", 0)
	l.add_theme_constant_override(&"shadow_offset_y", 3)
	l.add_theme_constant_override(&"shadow_outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, size := 36, min_size := Vector2(360, 96)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override(&"font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func centered_column(parent: Control, separation := 24) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", separation)
	center.add_child(col)
	return col


static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
