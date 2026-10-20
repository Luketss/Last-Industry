extends RefCounted
## Dark industrial UI theme built in code.

const BG := Color(0.055, 0.05, 0.045, 0.9)
const BORDER := Color(0.85, 0.5, 0.16, 0.55)
const ACCENT := Color(0.95, 0.6, 0.22)
const TEXT := Color(0.86, 0.83, 0.78)
const DIM := Color(0.58, 0.55, 0.5)
const OK := Color(0.45, 0.95, 0.5)
const WARN := Color(1.0, 0.75, 0.25)
const BAD := Color(1.0, 0.35, 0.25)
const LEVEL_COLORS := [OK, WARN, BAD]


static func panel_style(alpha: float = 0.9, border: Color = BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(BG.r, BG.g, BG.b, alpha)
	s.border_color = border
	s.set_border_width_all(1)
	s.border_width_top = 2
	s.set_corner_radius_all(2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(2)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		s.set_border_width_all(1)
		match state:
			"normal":
				s.bg_color = Color(0.12, 0.11, 0.1, 0.95)
				s.border_color = Color(0.35, 0.3, 0.25)
			"hover":
				s.bg_color = Color(0.2, 0.15, 0.1, 0.95)
				s.border_color = ACCENT
			"pressed":
				s.bg_color = Color(0.4, 0.24, 0.1, 0.95)
				s.border_color = ACCENT
			"disabled":
				s.bg_color = Color(0.08, 0.08, 0.08, 0.8)
				s.border_color = Color(0.2, 0.2, 0.2)
			"focus":
				s.draw_center = false
				s.border_color = Color(ACCENT, 0.5)
		t.set_stylebox(state, "Button", s)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.9, 0.75))
	t.set_color("font_pressed_color", "Button", Color(1, 0.95, 0.85))
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.4))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	bar_bg.set_corner_radius_all(1)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = ACCENT
	bar_fg.set_corner_radius_all(1)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	t.set_font_size("font_size", "ProgressBar", 11)
	var tip := panel_style(0.96)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	return t
