class_name UiKit
extends RefCounted
## Shared look and feel: large readable fonts, high contrast, and simple helpers.

const FONT_BODY := 18
const FONT_SMALL := 16
const FONT_TITLE := 28
const FONT_HUGE := 40

const COLOR_PANEL := Color(0.08, 0.12, 0.2, 0.98)
const COLOR_BORDER := Color(0.45, 0.7, 0.98, 1.0)
const COLOR_TEXT := Color(0.95, 0.97, 1.0, 1.0)
const COLOR_MUTED := Color(0.78, 0.84, 0.92, 1.0)
const COLOR_GOOD := Color(0.6, 0.95, 0.7, 1.0)
const COLOR_BAD := Color(1.0, 0.65, 0.6, 1.0)
const COLOR_WARN := Color(1.0, 0.85, 0.45, 1.0)


static func panel_style(bg: Color = COLOR_PANEL, border: Color = COLOR_BORDER, margin: int = 20) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_border_width_all(3)
	st.border_color = border
	st.set_corner_radius_all(10)
	st.content_margin_left = margin
	st.content_margin_right = margin
	st.content_margin_top = margin - 4
	st.content_margin_bottom = margin - 4
	return st


static func label(text: String, size: int = FONT_BODY, color: Color = COLOR_TEXT, wrap: bool = true) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


static func button(text: String, size: int = FONT_BODY, min_size: Vector2 = Vector2(0, 48)) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", size)
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_ALL
	return btn


## Full-screen dimmed overlay holding one centered card. Returns [overlay, vbox_inside_card].
static func make_overlay(card_width: float = 760.0) -> Array:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.08, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(card_width, 0)
	card.add_theme_stylebox_override("panel", panel_style())
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	return [overlay, box]


static func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

