extends RefCounted
## Dark industrial UI theme. Frames are Kenney's sci-fi UI pack restyled to the
## game palette (assets/ui, see scripts/import_assets.py); titles and buttons use
## Kenney Future. Flat styles are the fallback when an asset is missing.

const BG := Color(0.055, 0.05, 0.045, 0.9)
const BORDER := Color(0.85, 0.5, 0.16, 0.55)
const ACCENT := Color(0.95, 0.6, 0.22)
const TEXT := Color(0.86, 0.83, 0.78)
const DIM := Color(0.58, 0.55, 0.5)
const OK := Color(0.45, 0.95, 0.5)
const WARN := Color(1.0, 0.75, 0.25)
const BAD := Color(1.0, 0.35, 0.25)
const INFO := Color(0.55, 0.85, 1.0)
const LEVEL_COLORS := [OK, WARN, BAD]

const UI := "res://assets/ui/%s.png"
const ICON := "res://assets/icons/%s.png"
const TITLE_FONT := "res://assets/fonts/Kenney Future.ttf"
const BUTTON_FONT := "res://assets/fonts/Kenney Future Narrow.ttf"

static var _fonts := {}


static func texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


## UI icon from Kenney's game icons (white, tinted by the control) or a rendered
## structure icon: "ui/gear", "buildings/miner".
static func icon(name: String) -> Texture2D:
	return texture(ICON % name)


## Kenney Future with the engine font as fallback for glyphs it lacks (–, ★, ⚡…).
static func font(path: String = TITLE_FONT) -> Font:
	if not _fonts.has(path):
		var f: Font = null
		if ResourceLoader.exists(path):
			var ff: FontFile = load(path)
			f = ff.duplicate()
			f.fallbacks = [ThemeDB.fallback_font]
		_fonts[path] = f
	return _fonts[path]


static func _framed(name: String, margin: int, content: Vector4) -> StyleBox:
	var tex := texture(UI % name)
	if tex == null:
		return null
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin + (4 if name.begins_with("button") and name != "button_pressed" else 0)
	s.content_margin_left = content.x
	s.content_margin_top = content.y
	s.content_margin_right = content.z
	s.content_margin_bottom = content.w
	return s


static func panel_style(alpha: float = 0.9, border: Color = BORDER) -> StyleBox:
	var name := "panel_info" if border.b > border.r else ("panel_solid" if alpha > 0.95 else "panel")
	var framed := _framed(name, 12, Vector4(12, 9, 12, 9))
	if framed != null:
		framed.modulate_color = Color(1, 1, 1, clampf(alpha / 0.9, 0.0, 1.0))
		return framed
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


static func _button_style(state: String) -> StyleBox:
	var file := {"normal": "button", "hover": "button_hover", "pressed": "button_pressed", "disabled": "button_disabled"}
	if file.has(state):
		var framed := _framed(file[state], 8, Vector4(10, 6, 10, 8))
		if framed != null:
			return framed
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
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	for cls in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			t.set_stylebox(state, cls, _button_style(state))
		t.set_stylebox("hover_pressed", cls, _button_style("pressed"))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color(1, 0.9, 0.75))
		t.set_color("font_pressed_color", cls, Color(1, 0.95, 0.85))
		t.set_color("font_hover_pressed_color", cls, Color(1, 0.95, 0.85))
		t.set_color("font_disabled_color", cls, Color(0.4, 0.4, 0.4))
		t.set_color("icon_normal_color", cls, Color(0.85, 0.8, 0.72))
		t.set_color("icon_hover_color", cls, ACCENT.lightened(0.2))
		t.set_color("icon_pressed_color", cls, Color(1, 0.95, 0.85))
		t.set_color("icon_disabled_color", cls, Color(0.4, 0.4, 0.4))
		t.set_constant("h_separation", cls, 8)
		var bf := font(BUTTON_FONT)
		if bf != null:
			t.set_font("font", cls, bf)
	var clear := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(state, "CheckButton", clear)
	var bar_bg := _framed("bar_bg", 6, Vector4(2, 2, 2, 2))
	var bar_fg := _framed("bar_fill", 6, Vector4(2, 2, 2, 2))
	if bar_bg == null:
		bar_bg = StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		bar_fg = StyleBoxFlat.new()
		bar_fg.bg_color = ACCENT
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	t.set_font_size("font_size", "ProgressBar", 11)
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(0.16, 0.15, 0.13)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	slider.set_corner_radius_all(2)
	var grabber := slider.duplicate()
	grabber.bg_color = ACCENT.darkened(0.25)
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", grabber)
	t.set_stylebox("grabber_area_highlight", "HSlider", grabber)
	var sep := StyleBoxLine.new()
	sep.color = Color(BORDER, 0.35)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	var tip := panel_style(0.96)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	return t
