class_name UiKit
extends RefCounted

const CREAM := Color("#fff8e7")
const BROWN := Color("#6b4a32")
const SHADOW := Color(0.25, 0.15, 0.05, 0.25)

static func box(bg: Color, radius: int, shadow := true, border := 0, border_col := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 12
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = SHADOW
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 6)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_col
	sb.content_margin_left = radius * 0.5
	sb.content_margin_right = radius * 0.5
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func label(text: String, size: int, col := BROWN) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

static func pop_in(c: CanvasItem, from := 0.6) -> void:
	c.scale = Vector2(from, from)
	c.modulate.a = 0.0
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(c, "modulate:a", 1.0, 0.15)
