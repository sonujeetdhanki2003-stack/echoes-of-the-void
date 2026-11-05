class_name UIKit
extends RefCounted
## Small UI construction helpers so every screen shares one look: dark glass panels, cyan accents, Rajdhani.

const CYAN := Color(0.42, 0.86, 1.0)
const AMBER := Color(1.0, 0.72, 0.3)
const RED := Color(1.0, 0.3, 0.25)
const DIM := Color(0.62, 0.7, 0.78)
const WHITE := Color(0.92, 0.95, 1.0)
const BG := Color(0.02, 0.035, 0.05, 0.86)

static var _fonts := {}

static func font(name: String = "Rajdhani-SemiBold") -> Font:
	if not _fonts.has(name):
		_fonts[name] = load("res://assets/fonts/%s.ttf" % name)
	return _fonts[name]

static func label(text: String, size: int = 26, color: Color = WHITE, font_name: String = "Rajdhani-SemiBold") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(font_name))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func mono(text: String, size: int = 20, color: Color = DIM) -> Label:
	return label(text, size, color, "ShareTechMono-Regular")

static func wrap(l: Label, width: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l

static func _sb(bg: Color, border: Color, bw: int = 2, radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(0)
	s.border_width_left = bw
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

static func button(text: String, cb: Callable, size: int = 30, min_w: float = 380.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font("Rajdhani-SemiBold"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", _sb(Color(0.03, 0.06, 0.08, 0.7), Color(0.42, 0.86, 1.0, 0.35)))
	b.add_theme_stylebox_override("hover", _sb(Color(0.08, 0.2, 0.26, 0.9), CYAN, 4))
	b.add_theme_stylebox_override("focus", _sb(Color(0.08, 0.2, 0.26, 0.9), CYAN, 4))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.15, 0.35, 0.45, 0.95), CYAN, 6))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.03, 0.04, 0.05, 0.5), Color(0.3, 0.3, 0.3, 0.3)))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(min_w, size * 1.9)
	b.pressed.connect(func():
		Sfx.ui("ui_click", -4.0)
		cb.call())
	b.mouse_entered.connect(func(): Sfx.ui("ui_hover", -14.0))
	b.focus_mode = Control.FOCUS_ALL
	return b

static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = BG
	s.border_color = Color(0.42, 0.86, 1.0, 0.5)
	s.border_width_top = 2
	s.set_corner_radius_all(6)
	s.content_margin_left = 40
	s.content_margin_right = 40
	s.content_margin_top = 30
	s.content_margin_bottom = 30
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 18
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = min_size
	return p

static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.add_child(c)
	return cc

static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func slider(value: float, mn: float, mx: float, step: float, cb: Callable, width: float = 360.0) -> HSlider:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(width, 40)
	s.value_changed.connect(cb)
	return s

static func bar(width: float, height: float, fill: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(width, height)
	pb.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(2)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	pb.max_value = 100.0
	pb.value = 100.0
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb
