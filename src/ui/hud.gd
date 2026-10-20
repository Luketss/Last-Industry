extends CanvasLayer
## In-game interface: resources, energy, waves, objectives, transmissions, alerts,
## build bar, building inspector, statistics/diagnostics, help, pause and end screens.

const UiTheme = preload("res://src/ui/ui_theme.gd")
const Items = preload("res://src/sim/items.gd")
const Defs = preload("res://src/sim/defs.gd")
const Settings = preload("res://src/ui/settings.gd")
const Bindings = preload("res://src/ui/bindings.gd")
const Logistics = preload("res://src/sim/systems/logistics_system.gd")
const Genesis = preload("res://src/sim/systems/genesis_system.gd")
const I18n = preload("res://src/ui/i18n.gd")

var main
var root: Control
var top_label: RichTextLabel
var wave_label: RichTextLabel
var obj_label: Label
var obj_bar: ProgressBar
var trans_title: Label
var trans_label: Label
var alerts_box: VBoxContainer
var hotbar: GridContainer
var hot_buttons := {}
var hot_keys := {}
var credits_panel: PanelContainer
var genesis_panel: PanelContainer
var info_panel: PanelContainer
var info_title: Label
var info_status: Label
var info_hp: ProgressBar
var info_body: RichTextLabel
var info_recipes: HBoxContainer
var info_filters: GridContainer
var _filter_opts: Array = []
var info_toggle: Button
var info_demolish: Button
var tooltip: PanelContainer
var tooltip_label: RichTextLabel
var toast_label: Label
var stats_panel: PanelContainer
var stats_body: RichTextLabel
var help_panel: PanelContainer
var research_panel: PanelContainer
var research_list: VBoxContainer
var research_label: Label
var _research_key := ""
var pause_panel: PanelContainer
var end_panel: PanelContainer
var end_title: Label
var end_body: Label
var end_continue: Button
var menu_root: Control
var menu_continue: Button
var game_ui: Control
var options_panel: PanelContainer
var achievements_panel: PanelContainer
var achievements_list: RichTextLabel
var controls_panel: PanelContainer
var _bind_buttons := {}
var _rebinding := ""
var hint_panel: PanelContainer
var hint_label: Label
var _hint_id := ""
var _hint_timer := 0.0
var minimap: TextureRect
var _mini_base: Image
var _mini_img: Image
var _mini_tex: ImageTexture
var _mini_timer := 0.0
var _refresh := 0.0
var _toast_t := 0.0
var _trans_shown := -1
var _trans_chars := 0.0
var _info_for := -1


func _init(p_main) -> void:
	main = p_main


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.theme = UiTheme.build()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	game_ui = Control.new()
	game_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(game_ui)
	_build_top()
	_build_left()
	_build_alerts()
	_build_hotbar()
	_build_info()
	_build_tooltip()
	_build_overlays()
	_build_options()
	_build_genesis()
	_build_achievements()
	_build_minimap()
	_build_hint()
	_build_menu()
	_refresh_bindings()
	game_ui.visible = false


# --- construction helpers -------------------------------------------------------

## Anchors `c` to a screen point and lets it grow from there to its minimum size.
func _place(c: Control, preset: int, margin: Vector2 = Vector2.ZERO) -> void:
	c.set_anchors_preset(preset)
	var ax := c.anchor_left
	var ay := c.anchor_top
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN if ax == 1.0 else (Control.GROW_DIRECTION_BOTH if ax == 0.5 else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if ay == 1.0 else (Control.GROW_DIRECTION_BOTH if ay == 0.5 else Control.GROW_DIRECTION_END)
	var ox := -margin.x if ax == 1.0 else (margin.x if ax == 0.0 else 0.0)
	var oy := -margin.y if ay == 1.0 else (margin.y if ay == 0.0 else 0.0)
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	return p


func _label(parent: Control, text: String = "", size: int = 15, color: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


## Section title in the display font (Kenney Future).
func _heading(parent: Control, text: String, size: int = 14, color: Color = UiTheme.ACCENT) -> Label:
	var l := _label(parent, text, size, color)
	var f := UiTheme.font()
	if f != null:
		l.add_theme_font_override("font", f)
	return l


func _rich(parent: Control, fit: bool = true) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = fit
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _button(parent: Control, text: String, cb: Callable, icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = UiTheme.icon("ui/" + icon_name)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 22)
	b.mouse_entered.connect(func(): main.audio.play("hover"))
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


func _build_top() -> void:
	var p := _panel(game_ui)
	p.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p.offset_bottom = 40
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	p.add_child(hb)
	_heading(hb, I18n.t("LAST INDUSTRY"), 15)
	top_label = _rich(hb)
	top_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var wp := _panel(game_ui)
	wp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_label = _rich(wp)
	wave_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_place(wp, Control.PRESET_CENTER_TOP, Vector2(0, 48))


func _build_left() -> void:
	var p := _panel(game_ui)
	p.position = Vector2(12, 52)
	p.custom_minimum_size = Vector2(360, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 340
	p.add_child(vb)
	_heading(vb, I18n.t("OBJETIVO"), 11)
	obj_label = _label(vb, "")
	obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_label.custom_minimum_size.x = 340
	obj_bar = ProgressBar.new()
	obj_bar.custom_minimum_size = Vector2(340, 12)
	obj_bar.show_percentage = false
	vb.add_child(obj_bar)
	vb.add_child(HSeparator.new())
	research_label = _label(vb, "", 13, Color(0.55, 0.85, 1.0))
	research_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	research_label.custom_minimum_size.x = 340
	vb.add_child(HSeparator.new())
	trans_title = _label(vb, "", 12, Color(0.55, 0.85, 1.0))
	trans_label = _label(vb, "", 14, Color(0.72, 0.85, 0.9))
	trans_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trans_label.custom_minimum_size.x = 340


func _build_alerts() -> void:
	alerts_box = VBoxContainer.new()
	alerts_box.custom_minimum_size.x = 428
	alerts_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	alerts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(alerts_box)
	_place(alerts_box, Control.PRESET_TOP_RIGHT, Vector2(12, 52))
	toast_label = _label(game_ui, "", 18, Color(1, 0.9, 0.7))
	toast_label.custom_minimum_size.x = 700
	_place(toast_label, Control.PRESET_CENTER_TOP, Vector2(0, 104))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_constant_override("outline_size", 6)
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))


func _build_hotbar() -> void:
	var p := _panel(game_ui)
	_place(p, Control.PRESET_CENTER_BOTTOM, Vector2(0, 10))
	var menu: Array = main.data.game.build_menu
	hotbar = GridContainer.new()
	hotbar.columns = ceili(menu.size() / 2.0)
	hotbar.add_theme_constant_override("h_separation", 4)
	hotbar.add_theme_constant_override("v_separation", 4)
	p.add_child(hotbar)
	var keys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", ""]
	for i in menu.size():
		var type: String = menu[i]
		var def: Dictionary = main.data.buildings[type]
		var b := _button(hotbar, def.name, main.controller.set_tool.bind(type))
		b.custom_minimum_size = Vector2(106, 78)
		b.icon = UiTheme.icon("buildings/" + type)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_color_override("icon_normal_color", Color.WHITE)
		b.add_theme_color_override("icon_hover_color", Color(1.15, 1.1, 1.0))
		b.add_theme_color_override("icon_pressed_color", Color.WHITE)
		b.clip_text = true
		b.add_theme_font_override("font", ThemeDB.fallback_font)
		b.add_theme_font_size_override("font_size", 10)
		var key := _label(b, keys[i] if i < keys.size() else "", 11, UiTheme.ACCENT)
		key.position = Vector2(7, 4)
		key.add_theme_constant_override("outline_size", 4)
		key.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		hot_keys[type] = key
		b.tooltip_text = _build_tooltip_text(def)
		b.toggle_mode = true
		hot_buttons[type] = b


func _build_tooltip_text(def: Dictionary) -> String:
	var lines := [def.name, def.get("desc", ""), "", I18n.t("Custo: ") + _cost_text(def.get("cost", {}))]
	if float(def.get("power", 0)) > 0:
		lines.append(I18n.t("Energia: %d kW (%s)") % [int(def.power), I18n.t("defesa") if int(def.get("priority", 1)) == 0 else I18n.t("produção")])
	if def.has("power_out"):
		lines.append(I18n.t("Gera: %d kW") % int(def.power_out))
	if def.has("range"):
		lines.append(I18n.t("Alcance: %.1f  Dano: %d") % [float(def.range), int(def.damage)])
	lines.append(I18n.t("Integridade: %d") % int(def.hp))
	return "\n".join(lines)


func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s" % [int(cost[k]), main.data.item_name(k)])
	return ", ".join(parts) if not parts.is_empty() else "—"


func _build_info() -> void:
	info_panel = _panel(game_ui)
	_place(info_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(12, 200))
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 320
	info_panel.add_child(vb)
	info_title = _heading(vb, "", 16)
	info_status = _label(vb, "")
	info_hp = ProgressBar.new()
	info_hp.custom_minimum_size = Vector2(300, 12)
	info_hp.show_percentage = false
	vb.add_child(info_hp)
	info_body = _rich(vb)
	info_body.custom_minimum_size.x = 300
	info_recipes = HBoxContainer.new()
	vb.add_child(info_recipes)
	# Splitter routing: one item filter per output.
	info_filters = GridContainer.new()
	info_filters.columns = 2
	info_filters.add_theme_constant_override("h_separation", 10)
	vb.add_child(info_filters)
	for i in 3:
		_label(info_filters, [I18n.t("Esquerda"), I18n.t("Frente"), I18n.t("Direita")][i], 13, UiTheme.DIM)
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.custom_minimum_size.x = 200
		ob.add_theme_font_override("font", ThemeDB.fallback_font)
		ob.add_theme_font_size_override("font_size", 13)
		ob.item_selected.connect(_on_filter.bind(i))
		info_filters.add_child(ob)
		_filter_opts.append(ob)
	info_filters.visible = false
	var actions := HBoxContainer.new()
	vb.add_child(actions)
	info_toggle = _button(actions, I18n.t("Desligar"), _on_toggle)
	info_demolish = _button(actions, I18n.t("Demolir (Del)"), _on_demolish)
	info_panel.visible = false


func _build_tooltip() -> void:
	tooltip = PanelContainer.new()
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_theme_stylebox_override("panel", UiTheme.panel_style(0.85, Color(0.5, 0.5, 0.5, 0.4)))
	tooltip_label = _rich(tooltip)
	tooltip_label.custom_minimum_size.x = 240
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	game_ui.add_child(tooltip)
	tooltip.visible = false


func _center_panel(w: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = w
	root.add_child(p)
	_place(p, Control.PRESET_CENTER)
	p.visible = false
	return p


func _build_overlays() -> void:
	stats_panel = _center_panel(760)
	var sv := VBoxContainer.new()
	stats_panel.add_child(sv)
	_heading(sv, I18n.t("ESTATÍSTICAS E DIAGNÓSTICO  (Tab)"), 16)
	stats_body = _rich(sv)
	stats_body.custom_minimum_size = Vector2(740, 0)

	research_panel = _center_panel(860)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	research_panel.add_child(rv)
	_heading(rv, I18n.t("ÁRVORE DE PESQUISA  (T)"), 16)
	_label(rv, I18n.t("Laboratórios consomem pacotes recebidos por esteira. Fabrique-os na Montadora."), 13, UiTheme.DIM)
	research_list = VBoxContainer.new()
	research_list.add_theme_constant_override("separation", 4)
	rv.add_child(research_list)

	help_panel = _center_panel(820)
	var hv := VBoxContainer.new()
	help_panel.add_child(hv)
	_heading(hv, I18n.t("COMO OPERAR A INSTALAÇÃO  (H)"), 16)
	var help := _rich(hv)
	help.custom_minimum_size.x = 800
	help.text = I18n.t(HELP_TEXT)

	pause_panel = _center_panel(320)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	pause_panel.add_child(pv)
	_heading(pv, I18n.t("PAUSADO"), 22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for e in [[I18n.t("Continuar"), func(): main.set_menu_paused(false), "right"], [I18n.t("Salvar (F5)"), main.save_game, "save"],
			[I18n.t("Carregar (F9)"), main.load_game, "import"], [I18n.t("Ajuda (H)"), func(): help_panel.visible = not help_panel.visible, "question"],
			[I18n.t("Opções"), toggle_options, "gear"], [I18n.t("Conquistas"), toggle_achievements, "trophy"],
			[I18n.t("Menu principal"), main.to_main_menu, "home"], [I18n.t("Sair do jogo"), main.quit_game, "exitRight"]]:
		_menu_button(pv, e[0], e[1], e[2], Vector2(280, 40))

	end_panel = _center_panel(520)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 10)
	end_panel.add_child(ev)
	end_title = _heading(ev, "", 28)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body = _label(ev, "")
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_body.custom_minimum_size.x = 500
	end_continue = _menu_button(ev, I18n.t("Continuar no modo Sobrevivência"), main.continue_survival, "fastForward", Vector2(0, 42))
	_menu_button(ev, I18n.t("Nova partida"), main.start_new_game, "return", Vector2(0, 42))
	_menu_button(ev, I18n.t("Menu principal"), main.to_main_menu, "home", Vector2(0, 42))


## Large left-aligned button with an icon, used by the main, pause and end menus.
func _menu_button(parent: Control, text: String, cb: Callable, icon_name: String, size: Vector2) -> Button:
	var b := _button(parent, text, cb, icon_name)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", 16 if size.y >= 46 else 14)
	return b


func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu_root)
	# Darkens the left side behind the menu and leaves the orbiting base visible.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.018, 0.015, 0.92))
	grad.set_color(1, Color(0.02, 0.018, 0.015, 0.0))
	grad.add_point(0.45, Color(0.02, 0.018, 0.015, 0.7))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 256
	gt.height = 4
	var shade := TextureRect.new()
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 900
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(shade)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	vb.position = Vector2(110, -270)
	vb.add_theme_constant_override("separation", 10)
	menu_root.add_child(vb)
	var title := _heading(vb, I18n.t("LAST INDUSTRY"), 64, Color(0.93, 0.88, 0.8))
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	# Hazard stripe under the title.
	var stripe := ColorRect.new()
	stripe.custom_minimum_size = Vector2(560, 4)
	stripe.color = UiTheme.ACCENT
	vb.add_child(stripe)
	_label(vb, I18n.t("“Quando o mundo acabou, as máquinas continuaram trabalhando.”"), 19, UiTheme.ACCENT)
	_heading(vb, I18n.t("EXTRAIR · PRODUZIR · DEFENDER · SOBREVIVER"), 12, UiTheme.DIM)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 26
	vb.add_child(spacer)
	var size := Vector2(340, 48)
	_menu_button(vb, I18n.t("Nova partida"), main.start_new_game, "right", size)
	menu_continue = _menu_button(vb, I18n.t("Continuar"), main.load_game, "import", size)
	_menu_button(vb, I18n.t("Como jogar"), func(): help_panel.visible = not help_panel.visible, "question", size)
	_menu_button(vb, I18n.t("Opções"), toggle_options, "gear", size)
	_menu_button(vb, I18n.t("Conquistas"), toggle_achievements, "trophy", size)
	_menu_button(vb, I18n.t("Créditos"), toggle_credits, "information", size)
	_menu_button(vb, I18n.t("Sair"), main.quit_game, "exitRight", size)
	var ver := _label(menu_root, I18n.t("v%s — protótipo (MVP)  ·  Windows / Linux") % ProjectSettings.get_setting("application/config/version", "0.1.0"), 12, UiTheme.DIM)
	_place(ver, Control.PRESET_BOTTOM_LEFT, Vector2(16, 12))
	var art := _label(menu_root, I18n.t("Modelos, interface, ícones e sons: Kenney · Músicas: OpenGameArt.org — veja Créditos"), 12, UiTheme.DIM)
	_place(art, Control.PRESET_BOTTOM_RIGHT, Vector2(16, 12))
	_build_credits()


## Attribution for every third-party pack (assets/sources.json, written by
## scripts/import_assets.py). CC-BY tracks require this credit in-game.
func _build_credits() -> void:
	credits_panel = _center_panel(720)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	credits_panel.add_child(v)
	_heading(v, I18n.t("CRÉDITOS"), 18)
	var body := _rich(v)
	body.custom_minimum_size.x = 700
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.meta_clicked.connect(func(m): OS.shell_open(str(m)))
	var t := I18n.t("[b]Last Industry[/b] — design, código e áudio procedural do projeto.\n\n[b]Recursos de terceiros[/b] (OpenGameArt.org):\n")
	var f := FileAccess.open("res://assets/sources.json", FileAccess.READ)
	var src = JSON.parse_string(f.get_as_text()) if f != null else null
	if src is Dictionary:
		var keys: Array = src.keys()
		keys.sort()
		for k in keys:
			var e: Dictionary = src[k]
			t += "• %s — [color=#d8cfc2]%s[/color]  [color=#8f877c](%s)[/color]  [url=%s][color=#f29938]%s[/color][/url]\n" % [
				e.title, e.author, e.license, e.page, str(e.page).trim_prefix("https://")]
	t += I18n.t("\nFonte Kenney Future (CC0). Kits 3D recoloridos para a paleta do jogo.")
	body.text = t
	_button(v, I18n.t("Fechar"), toggle_credits, "cross")


func toggle_credits() -> void:
	credits_panel.visible = not credits_panel.visible


# --- state switches -------------------------------------------------------------

func show_main_menu(has_save: bool) -> void:
	menu_root.visible = true
	game_ui.visible = false
	pause_panel.visible = false
	end_panel.visible = false
	genesis_panel.visible = false
	stats_panel.visible = false
	menu_continue.disabled = not has_save


func show_game() -> void:
	menu_root.visible = false
	game_ui.visible = true
	pause_panel.visible = false
	end_panel.visible = false
	genesis_panel.visible = false
	help_panel.visible = false
	credits_panel.visible = false
	_trans_shown = -1
	_info_for = -1


func show_pause(v: bool) -> void:
	pause_panel.visible = v


func show_end(state: String) -> void:
	var w = main.world
	end_panel.visible = true
	genesis_panel.visible = false
	end_continue.visible = state == "won" and w.ending in ["", "fortress"]
	if state == "won" and w.ending != "":
		end_title.text = _ending_lore(w).get("title", "")
		end_title.add_theme_color_override("font_color", UiTheme.OK)
	elif state == "won":
		end_title.text = I18n.t("O NÚCLEO SOBREVIVEU")
		end_title.add_theme_color_override("font_color", UiTheme.OK)
	else:
		end_title.text = I18n.t("NÚCLEO DESTRUÍDO")
		end_title.add_theme_color_override("font_color", UiTheme.BAD)
	end_body.text = I18n.t("Hordas repelidas: %d\nCriaturas abatidas: %d\nEstruturas perdidas: %d\nTempo de operação: %s\nPlacas produzidas: %d   ·   Munição produzida: %d") % [
		w.stats.waves, w.stats.kills, w.stats.lost, _clock(w.time),
		int(w.stats.produced.get("iron_plate", 0)), int(w.stats.produced.get("ammo", 0))]
	if state == "won" and w.ending != "":
		end_body.text = str(_ending_lore(w).get("text", "")) + "\n\n" + end_body.text
	elif state == "won":
		end_body.text += "\n\n" + str(w.transmissions.back().text if not w.transmissions.is_empty() else "")


func _ending_lore(w) -> Dictionary:
	for e in w.data.lore:
		if e.trigger == "ending:" + w.ending:
			return e
	return {}


## Genesis is fully charged: the three protocols.
func _build_genesis() -> void:
	genesis_panel = _center_panel(640)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	genesis_panel.add_child(v)
	var t := _heading(v, I18n.t("GENESIS"), 28, Color(0.5, 1.0, 0.6))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := _label(v, I18n.t("A carga está completa. Três protocolos aguardam a sua autorização. A escolha encerra a campanha."), 15)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 620
	for e in [["restore", I18n.t("RESTAURAR — ativar Genesis e deixar que reescreva o mundo"), "right"],
			["destroy", I18n.t("DESTRUIR — sobrecarregar o núcleo e apagar a tecnologia"), "cross"],
			["fortress", I18n.t("MANTER — selar Genesis e seguir produzindo para sempre"), "wrench"]]:
		var b := _menu_button(v, e[1], main.choose_ending.bind(e[0]), e[2], Vector2(620, 48))
		b.add_theme_font_override("font", ThemeDB.fallback_font)


func show_genesis() -> void:
	genesis_panel.visible = true


func toggle_stats() -> void:
	stats_panel.visible = not stats_panel.visible


func _build_options() -> void:
	options_panel = _center_panel(520)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	options_panel.add_child(v)
	_heading(v, I18n.t("OPÇÕES"), 18)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for opt in [["volume", I18n.t("Volume geral")], ["music_volume", I18n.t("Música")], ["sfx_volume", I18n.t("Efeitos sonoros")]]:
		_label(grid, opt[1])
		var vol := HSlider.new()
		vol.min_value = 0.0
		vol.max_value = 1.0
		vol.step = 0.05
		vol.value = float(Settings.get_value(opt[0]))
		vol.custom_minimum_size.x = 260
		vol.value_changed.connect(func(x): _set_option(opt[0], x))
		grid.add_child(vol)
	_label(grid, I18n.t("Escala da interface"))
	var sc := OptionButton.new()
	var scales := [0.85, 1.0, 1.15, 1.3, 1.5]
	for s in scales:
		sc.add_item("%d%%" % int(s * 100))
	sc.selected = maxi(scales.find(float(Settings.get_value("ui_scale"))), 1) if float(Settings.get_value("ui_scale")) != 0.85 else 0
	sc.item_selected.connect(func(i): _set_option("ui_scale", scales[i]))
	grid.add_child(sc)
	for opt in [["shadows", I18n.t("Sombras"), [I18n.t("Desligadas"), I18n.t("Baixas"), I18n.t("Altas")], [0, 1, 2]],
			["msaa", I18n.t("Antisserrilhamento"), [I18n.t("Desligado"), "MSAA 2×", "MSAA 4×"], [0, 1, 2]],
			["fps_limit", I18n.t("Limite de FPS"), ["30", "60", "120", I18n.t("Sem limite")], [30, 60, 120, 0]]]:
		_label(grid, opt[1])
		var ob := OptionButton.new()
		ob.focus_mode = Control.FOCUS_NONE
		for n in opt[2]:
			ob.add_item(n)
		ob.selected = maxi(opt[3].find(int(Settings.get_value(opt[0]))), 0)
		ob.item_selected.connect(func(i): _set_option(opt[0], opt[3][i]))
		grid.add_child(ob)
	_label(grid, I18n.t("Velocidade da câmera"))
	var cs := HSlider.new()
	cs.min_value = 0.5
	cs.max_value = 2.5
	cs.step = 0.1
	cs.value = float(Settings.get_value("camera_speed"))
	cs.custom_minimum_size.x = 260
	cs.value_changed.connect(func(x): _set_option("camera_speed", x))
	grid.add_child(cs)
	for opt in [["vsync", I18n.t("Sincronização vertical (V-Sync)")], ["particles", I18n.t("Cinzas no ar")], ["fullscreen", I18n.t("Tela cheia")], ["edge_pan", I18n.t("Mover câmera pela borda da tela")], ["hints", I18n.t("Dicas contextuais")], ["minimap", I18n.t("Minimapa")]]:
		_label(grid, opt[1])
		var cb := CheckButton.new()
		cb.button_pressed = bool(Settings.get_value(opt[0]))
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on): _set_option(opt[0], on))
		grid.add_child(cb)
	var row := HBoxContainer.new()
	v.add_child(row)
	_button(row, I18n.t("Rever todas as dicas"), func():
		Settings.set_value("hints_seen", [])
		toast(I18n.t("As dicas voltarão a aparecer")))
	_button(row, I18n.t("Controles…"), toggle_controls)
	_button(row, I18n.t("Fechar"), toggle_options)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 12)
	v.add_child(lrow)
	_label(lrow, I18n.t("Idioma"))
	var lang := OptionButton.new()
	lang.focus_mode = Control.FOCUS_NONE
	lang.add_theme_font_override("font", ThemeDB.fallback_font)
	var cur := str(Settings.get_value("language"))
	for i in I18n.LANGS.size():
		lang.add_item(I18n.t(I18n.LANGS[i][1]) if i == 0 else I18n.LANGS[i][1])
		if I18n.LANGS[i][0] == cur:
			lang.select(i)
	lang.item_selected.connect(func(i):
		Settings.set_value("language", I18n.LANGS[i][0])
		main.relocalize())
	lrow.add_child(lang)
	_build_controls()


func _build_controls() -> void:
	controls_panel = _center_panel(760)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	controls_panel.add_child(v)
	_heading(v, I18n.t("CONTROLES"), 18)
	_label(v, I18n.t("Clique numa ação e pressione a nova tecla (Esc cancela). Teclas em uso são trocadas entre as ações."), 13, UiTheme.DIM)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for a in Bindings.ACTIONS:
		_label(grid, I18n.t(a[1]), 13)
		var b := _button(grid, Bindings.label(a[0]), _start_rebind.bind(a[0]))
		b.custom_minimum_size = Vector2(110, 26)
		b.add_theme_font_size_override("font_size", 12)
		_bind_buttons[a[0]] = b
	_label(v, I18n.t("Fixos: Esc (menu/cancelar) · Ctrl+C / Ctrl+V (copiar/colar) · Shift (seleção em área, girar ao contrário, câmera rápida) · setas (câmera) · mouse."), 12, UiTheme.DIM)
	var row := HBoxContainer.new()
	v.add_child(row)
	_button(row, I18n.t("Restaurar padrões"), func():
		Bindings.reset()
		_refresh_bindings())
	_button(row, I18n.t("Fechar"), toggle_controls)


func toggle_controls() -> void:
	controls_panel.visible = not controls_panel.visible
	_rebinding = ""
	_refresh_bindings()


func _start_rebind(action: String) -> void:
	_rebinding = action
	_refresh_bindings()
	_bind_buttons[action].text = I18n.t("pressione…")


func _refresh_bindings() -> void:
	for a in _bind_buttons:
		_bind_buttons[a].text = Bindings.label(a)
	var menu: Array = main.data.game.build_menu
	for i in menu.size():
		var b: Button = hot_buttons[menu[i]]
		hot_keys[menu[i]].text = Bindings.label("slot%d" % (i + 1)) if i < 12 else ""
		b.text = main.data.buildings[menu[i]].name


func _input(event: InputEvent) -> void:
	if _rebinding == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE and not (event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]):
		Bindings.rebind(_rebinding, event.keycode)
	elif event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return
	_rebinding = ""
	_refresh_bindings()
	get_viewport().set_input_as_handled()


func _set_option(k: String, v) -> void:
	Settings.set_value(k, v)
	Settings.apply(main)


func toggle_options() -> void:
	options_panel.visible = not options_panel.visible


func _build_hint() -> void:
	hint_panel = PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(0.92, Color(0.35, 0.8, 1.0, 0.7)))
	game_ui.add_child(hint_panel)
	var v := VBoxContainer.new()
	hint_panel.add_child(v)
	_heading(v, I18n.t("DICA"), 11, UiTheme.INFO)
	hint_label = _label(v, "")
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size.x = 330
	var row := HBoxContainer.new()
	v.add_child(row)
	_button(row, I18n.t("Entendi"), _dismiss_hint).add_theme_font_size_override("font_size", 12)
	_button(row, I18n.t("Desativar dicas"), func():
		_set_option("hints", false)
		_dismiss_hint()).add_theme_font_size_override("font_size", 12)
	_place(hint_panel, Control.PRESET_BOTTOM_LEFT, Vector2(12, 214))
	hint_panel.visible = false


func _dismiss_hint() -> void:
	if _hint_id != "":
		var seen: Array = Settings.get_value("hints_seen").duplicate()
		seen.append(_hint_id)
		Settings.set_value("hints_seen", seen)
	_hint_id = ""
	hint_panel.visible = false


## Contextual tutorial: the first applicable hint the player has not dismissed.
func _hint_candidates(w) -> Array:
	var h := []
	var t: float = w.time
	if t > 15 and w.list("miner").is_empty():
		h.append(["miner", I18n.t("Selecione a Mineradora (2) e posicione-a sobre as pedras alaranjadas (minério de ferro). O lado com a faixa amarela é a saída: arraste Esteiras (1) a partir dele até o Núcleo — desenhe em L para fazer curvas.")])
	for b in w.buildings.values():
		if b.power_net == -1 and float(b.def.get("power", 0)) > 0:
			h.append(["power_net", I18n.t("%s está fora da rede elétrica. Construa Postes de Energia (6): a área quadrada mostra o alcance. Postes próximos se conectam sozinhos.") % b.def.name])
			break
	if float(w.power.totals.get("sat", 1.0)) < 0.9 and float(w.power.totals.get("demand", 0)) > 0:
		h.append(["power_low", I18n.t("A demanda de energia passou da geração. Construa um Gerador a Carvão (5) e passe uma esteira de carvão encostada nele. As defesas recebem energia antes da produção.")])
	for b in w.list("turret_gun"):
		if b.status == "sem munição":
			h.append(["ammo", I18n.t("Torres de munição puxam pentes de qualquer esteira encostada nelas. Leve a saída da Montadora (receita: Pente de Munição) para passar ao lado das torres.")])
			break
	if not w.ghosts.is_empty():
		h.append(["ghosts", I18n.t("Estruturas destruídas viram ruínas vermelhas. Clique numa ruína ou pressione G para reconstruir tudo com os recursos do Núcleo.")])
	if w.waves.has_more(w) and not w.waves.active and w.waves.timer < 75 and w.list("turret_gun").is_empty() and w.list("turret_tesla").is_empty():
		h.append(["no_defense", I18n.t("Uma horda está chegando e não há torres! A Torre Elétrica (8) só precisa de energia; a Balística (7) precisa de munição por esteira.")])
	if not w.list("lab").is_empty() and w.research.current == "" and w.research.done.is_empty():
		h.append(["research", I18n.t("Pressione T para escolher uma pesquisa. O Laboratório consome Pacotes de Pesquisa (Montadora: placa + componente) recebidos por esteira.")])
	var congested := 0
	for b in w.list("belt"):
		if b.status == "saída bloqueada":
			congested += 1
	if congested >= 6:
		h.append(["congestion", I18n.t("Várias esteiras estão congestionadas. Abra as estatísticas (Tab) para ver gargalos e use V para rastrear de onde vêm e para onde vão os itens.")])
	if w.stats.waves >= 1 and w.list("repair").is_empty():
		h.append(["repair", I18n.t("Uma Estação de Reparo (0) conserta estruturas próximas consumindo placas de ferro que ela puxa de esteiras encostadas.")])
	if w.list("belt").size() > 40 and w.stats.waves >= 2:
		h.append(["blueprint", I18n.t("Shift+arrastar seleciona uma área. Ctrl+C copia como planta, R gira e o clique cola — ótimo para replicar linhas de produção.")])
	return h


func _update_hints(w, delta: float) -> void:
	_hint_timer -= delta
	if _hint_timer > 0.0:
		return
	_hint_timer = 1.0
	if not bool(Settings.get_value("hints")):
		hint_panel.visible = false
		return
	if _hint_id != "":
		return
	var seen: Array = Settings.get_value("hints_seen")
	for c in _hint_candidates(w):
		if not (c[0] in seen):
			_hint_id = c[0]
			hint_label.text = c[1]
			hint_panel.visible = true
			return


func _build_minimap() -> void:
	var p := _panel(game_ui)
	minimap = TextureRect.new()
	minimap.custom_minimum_size = Vector2(180, 180)
	minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap.stretch_mode = TextureRect.STRETCH_SCALE
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	minimap.mouse_default_cursor_shape = Control.CURSOR_CROSS
	minimap.gui_input.connect(_on_minimap_input)
	minimap.tooltip_text = I18n.t("Minimapa — clique para mover a câmera")
	p.add_child(minimap)
	_place(p, Control.PRESET_BOTTOM_LEFT, Vector2(12, 10))


## Builds the static terrain layer of the minimap for a new world.
func bind_world(w) -> void:
	_mini_base = Image.create(w.width, w.height, false, Image.FORMAT_RGBA8)
	for y in w.height:
		for x in w.width:
			var t: int = w.terrain[y * w.width + x]
			var c := Color(0.13, 0.12, 0.11)
			match t:
				Defs.T_ROCK:
					c = Color(0.3, 0.29, 0.27)
				Defs.T_IRON:
					c = Color(0.5, 0.25, 0.12)
				Defs.T_COAL:
					c = Color(0.04, 0.04, 0.04)
			_mini_base.set_pixel(x, y, c)
	for sp in w.spawn_points:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q: Vector2i = sp + Vector2i(dx, dy)
				if w.in_bounds(q):
					_mini_base.set_pixel(q.x, q.y, Color(0.8, 0.1, 0.05))
	_mini_img = _mini_base.duplicate()
	_mini_tex = ImageTexture.create_from_image(_mini_img)
	minimap.texture = _mini_tex
	_mini_timer = 0.0


func _update_minimap(w, delta: float) -> void:
	minimap.get_parent().visible = bool(Settings.get_value("minimap"))
	_mini_timer -= delta
	if _mini_timer > 0.0 or _mini_base == null or not minimap.get_parent().visible:
		return
	_mini_timer = 0.4
	_mini_img.copy_from(_mini_base)
	var cols := [Color(0.75, 0.72, 0.65), Color(1.0, 0.75, 0.25), Color(1.0, 0.3, 0.2)]
	for b in w.buildings.values():
		var c: Color = Color(1.0, 0.6, 0.2) if b.kind == "core" else (Color(0.55, 0.55, 0.55) if b.kind == "wall" else cols[b.status_level()])
		if b.kind == "belt":
			c = Color(0.42, 0.4, 0.36)
		for y in b.size.y:
			for x in b.size.x:
				_mini_img.set_pixel(b.pos.x + x, b.pos.y + y, c)
	for key in w.ghosts:
		var g: Dictionary = w.ghosts[key]
		_mini_img.set_pixel(int(g.x), int(g.y), Color(0.6, 0.1, 0.1))
	for key in w.terminals:
		_mini_img.set_pixel(key % w.width, key / w.width, Color(0.3, 0.6, 0.7) if w.terminals[key].read else Color(0.4, 0.95, 1.0))
	for e in w.enemies.values():
		var q := Vector2i(floori(e.pos.x), floori(e.pos.y))
		if w.in_bounds(q):
			_mini_img.set_pixel(q.x, q.y, Color(1.0, 0.1, 0.1) if not e.def.get("flying", false) else Color(1.0, 0.4, 0.9))
	# Camera focus marker.
	var cp := Vector2i(floori(main.camera.position.x), floori(main.camera.position.z))
	for d in range(-2, 3):
		for q in [cp + Vector2i(d, 0), cp + Vector2i(0, d)]:
			if w.in_bounds(q):
				_mini_img.set_pixel(q.x, q.y, Color(0.4, 0.9, 1.0))
	_mini_tex.update(_mini_img)


func _on_minimap_input(ev: InputEvent) -> void:
	var w = main.world
	if w == null:
		return
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var r := Vector2(ev.position) / minimap.size
		main.camera.focus(Vector3(r.x * w.width, 0, r.y * w.height))
		_mini_timer = 0.0


func toggle_research() -> void:
	research_panel.visible = not research_panel.visible
	_research_key = ""


func close_overlays() -> bool:
	var any := credits_panel.visible or help_panel.visible or stats_panel.visible or research_panel.visible or options_panel.visible or controls_panel.visible or achievements_panel.visible
	if _rebinding != "":
		return true
	controls_panel.visible = false
	credits_panel.visible = false
	options_panel.visible = false
	achievements_panel.visible = false
	help_panel.visible = false
	stats_panel.visible = false
	research_panel.visible = false
	return any


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible


func achievement(d: Dictionary) -> void:
	toast(I18n.t("★ Conquista desbloqueada: %s") % d.name)
	_toast_t = 4.0
	if not main.audio.play("achievement"):
		main.audio.click()


func _build_achievements() -> void:
	achievements_panel = _center_panel(620)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	achievements_panel.add_child(v)
	_heading(v, I18n.t("CONQUISTAS"), 18)
	achievements_list = _rich(v)
	achievements_list.custom_minimum_size.x = 600
	_button(v, I18n.t("Fechar"), toggle_achievements)


func toggle_achievements() -> void:
	achievements_panel.visible = not achievements_panel.visible
	if not achievements_panel.visible:
		return
	var a = main.achievements
	var t := ""
	var n := 0
	for d in a.defs:
		var got: bool = a.unlocked.has(d.id)
		if got:
			n += 1
		t += "[color=#%s]%s %s[/color]  [color=#8f877c]%s[/color]\n" % ["73f27f" if got else "8f877c", "★" if got else "☆", d.name, d.desc]
	var st: String = main.steam.status
	achievements_list.text = I18n.t("[b]%d de %d[/b]   [color=#8f877c]Steam: %s[/color]\n\n") % [n, a.defs.size(), I18n.t(st)] + t


func toast(text: String) -> void:
	toast_label.text = text
	_toast_t = 2.5


func on_events(events: Array) -> void:
	for ev in events:
		if ev.e == "objective":
			toast(I18n.t("Objetivo concluído!"))


static func _clock(t: float) -> String:
	var s := maxi(int(t), 0)
	return "%02d:%02d" % [s / 60, s % 60]


# --- per frame --------------------------------------------------------------------

func _process(delta: float) -> void:
	_toast_t -= delta
	toast_label.modulate.a = clampf(_toast_t, 0.0, 1.0)
	var w = main.world
	if w == null or not game_ui.visible:
		return
	_update_tooltip()
	_update_transmission(w, delta)
	_update_minimap(w, delta)
	_update_hints(w, delta)
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.12
	_update_top(w)
	_update_objective(w)
	_update_alerts(w)
	_update_hotbar(w)
	_update_info(w)
	if stats_panel.visible:
		_update_stats(w)
	_update_research(w)


## Painted item icon as BBCode (assets/icons/items), or a coloured square.
func _item_icon(w, item: String, size: int) -> String:
	var path := UiTheme.ICON % ("items/" + item)
	if ResourceLoader.exists(path):
		return "[img=%dx%d]%s[/img]" % [size, size, path]
	return "[color=#%s]■[/color]" % _hex(w.data.item_color(item).lightened(0.2))


func _hex(c: Color) -> String:
	return c.to_html(false)


func _update_top(w) -> void:
	var parts := []
	for item in ["iron_ore", "coal", "iron_plate", "gear", "ammo"]:
		var r: int = w.stats.rate(item)
		parts.append("%s %s [b]%d[/b] [color=#8f877c]+%d/min[/color]" % [
			_item_icon(w, item, 22), str(w.data.items[item].get("short", w.data.item_name(item))), Items.count(w.storage, item), r])
	var pt: Dictionary = w.power.totals
	var pcol := UiTheme.OK if float(pt.get("sat", 1.0)) > 0.98 else (UiTheme.WARN if float(pt.get("sat", 1.0)) > 0.6 else UiTheme.BAD)
	var bat := ""
	if float(pt.get("capacity", 0.0)) > 0.0:
		bat = I18n.t("  bateria %d%%") % int(100.0 * float(pt.stored) / float(pt.capacity))
	parts.append("[color=#%s]⚡ %d / %d kW%s[/color]" % [_hex(pcol), int(pt.get("used", 0.0)), int(pt.get("cap", 0.0)), bat])
	top_label.text = "   ".join(parts)
	var ws = w.waves
	var txt := ""
	if ws.active:
		txt = I18n.t("[color=#ff5a3c][b]HORDA %d EM ANDAMENTO[/b][/color] — %d inimigos") % [ws.index, w.enemies.size() + ws.queue.size()]
	elif ws.has_more(w):
		var col := "ff5a3c" if ws.timer < 30 else ("ffc04a" if ws.timer < 90 else "d8cfc2")
		txt = I18n.t("[color=#%s]Horda %d%s em [b]%s[/b][/color] [color=#8f877c]%s[/color]") % [col, ws.index + 1,
			"" if w.survival else "/%d" % ws.campaign_length(), _clock(ws.timer), ws.describe_next(w)]
	var spd: String = I18n.t("  [color=#ffc04a]⏸ PAUSA[/color]") if main.paused else ("  ×%d" % int(main.speed) if main.speed != 1.0 else "")
	wave_label.text = txt + spd


func _update_objective(w) -> void:
	var o = w.objectives.current_objective()
	if o == null:
		obj_label.text = I18n.t("Todos os objetivos concluídos. Sobreviva.") if not w.survival else I18n.t("Modo Sobrevivência: resista o máximo possível.")
		obj_bar.value = 100
		return
	var pr: Array = w.objectives.progress(w)
	obj_label.text = "%s  (%d/%d)" % [o.text, pr[0], pr[1]]
	obj_bar.max_value = pr[1]
	obj_bar.value = pr[0]


func _update_transmission(w, delta: float) -> void:
	if w.transmissions.is_empty():
		trans_title.text = ""
		trans_label.text = ""
		return
	var last: int = w.transmissions.size() - 1
	if last != _trans_shown:
		_trans_shown = last
		_trans_chars = 0.0
	var tr: Dictionary = w.transmissions[last]
	_trans_chars += delta * 45.0
	trans_title.text = "▌ " + str(tr.title)
	var full := str(tr.text)
	trans_label.text = full.left(int(_trans_chars)) + ("█" if int(_trans_chars) < full.length() and fmod(_trans_chars, 6.0) < 3.0 else "")


func _update_alerts(w) -> void:
	var n: int = w.alerts.size()
	while alerts_box.get_child_count() < n:
		# Alerts are flat buttons: clicking one moves the camera to where it happened.
		var l := Button.new()
		l.flat = true
		l.focus_mode = Control.FOCUS_NONE
		l.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_font_override("font", ThemeDB.fallback_font)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 428
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.pressed.connect(_on_alert.bind(alerts_box.get_child_count()))
		alerts_box.add_child(l)
	for i in alerts_box.get_child_count():
		var l: Button = alerts_box.get_child(i)
		if i >= n:
			l.visible = false
			continue
		var a: Dictionary = w.alerts[i]
		var age: float = w.time - float(a.time)
		l.visible = age < 25.0
		l.text = a.text + ("  ⌖" if a.pos != null else "")
		l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if a.pos != null else Control.CURSOR_ARROW
		var c: Color = {"danger": UiTheme.BAD, "warn": UiTheme.WARN, "info": UiTheme.OK}.get(a.level, UiTheme.TEXT)
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			l.add_theme_color_override(st, c if st == "font_color" else c.lightened(0.3))
		l.modulate.a = clampf(1.6 - age / 15.0, 0.25, 1.0)


func _on_alert(i: int) -> void:
	var w = main.world
	if w == null or i >= w.alerts.size() or w.alerts[i].pos == null:
		return
	var p: Vector2 = w.alerts[i].pos
	main.camera.focus(Vector3(p.x, 0, p.y))


func _update_hotbar(w) -> void:
	for type in hot_buttons:
		var b: Button = hot_buttons[type]
		b.set_pressed_no_signal(main.controller.tool == type)
		var def: Dictionary = w.data.buildings[type]
		if not w.is_unlocked(type):
			b.modulate = Color(0.45, 0.45, 0.5)
			var tech = w.research.techs.get(w.research.unlocked_by.get(type, ""), {})
			b.tooltip_text = _build_tooltip_text(def) + I18n.t("\n\nBLOQUEADO — requer pesquisa: %s") % tech.get("name", "?")
		else:
			b.modulate = Color.WHITE if w.can_afford(def.get("cost", {})) else Color(1, 0.55, 0.5)
			b.tooltip_text = _build_tooltip_text(def)


func _update_tooltip() -> void:
	var c = main.controller
	var w = main.world
	var txt := ""
	if c.tool == c.BLUEPRINT_TOOL:
		txt = I18n.t("[b]Planta[/b] (%d estruturas)  [color=#8f877c]%s[/color]") % [c.blueprint.entries.size(), _cost_text(load("res://src/sim/blueprint.gd").cost(w, c.blueprint))]
		txt += "\n" + ("[color=#ff6a50]%s[/color]" % c.last_reason if c.last_reason != "" else I18n.t("[color=#8f877c]Clique cola · R gira · Clique direito/Esc cancela[/color]"))
	elif c.tool != "":
		var def: Dictionary = w.data.buildings[c.tool]
		txt = "[b]%s[/b]  [color=#8f877c]%s[/color]" % [def.name, _cost_text(def.get("cost", {}))]
		if c.last_reason != "":
			txt += "\n[color=#ff6a50]%s[/color]" % c.last_reason
		else:
			txt += I18n.t("\n[color=#8f877c]R girar · Clique direito demolir · Esc cancelar[/color]")
	else:
		var b = c.hovered_building()
		if b != null:
			txt = "[b]%s[/b]  %d/%d\n%s" % [b.def.name, int(b.hp), int(b.max_hp), _status_bb(b)]
			txt += _flow_hint(w, b)
			if c.trace_mode:
				txt += I18n.t("\n[color=#ffa040]■ %d fontes[/color]  [color=#50d8ff]■ %d destinos[/color]") % [c.trace_up.size(), c.trace_down.size()]
		else:
			var g: int = w.ghost_at(c.hover)
			var term = w.terminals.get(w.idx(c.hover)) if w.in_bounds(c.hover) else null
			if term != null:
				if term.read:
					txt = I18n.t("[color=#50d8ff]Terminal de dados[/color]\nJá decodificado")
				elif Genesis.near_structure(w, c.hover):
					txt = I18n.t("[color=#50d8ff]Terminal de dados[/color]\nClique para decodificar (arquivo + sucata)")
				else:
					txt = I18n.t("[color=#50d8ff]Terminal de dados[/color]\n[color=#ff6a50]Construa algo a até 7 tiles para decodificar[/color]")
			elif g != -1:
				var gd: Dictionary = w.ghosts[g]
				var def: Dictionary = w.data.buildings[gd.type]
				txt = I18n.t("[color=#ff8060]Ruína: %s[/color]\nClique para reconstruir (%s)") % [def.name, _cost_text(def.get("cost", {}))]
			elif w.in_bounds(c.hover):
				var i: int = w.idx(c.hover)
				var t: int = w.terrain[i]
				if Defs.ORE_ITEM.has(t) and w.ore[i] > 0:
					txt = I18n.t("%s — %d restantes") % [w.data.item_name(Defs.ORE_ITEM[t]), w.ore[i]]
				elif t == Defs.T_ROCK:
					txt = I18n.t("[color=#8f877c]Ruínas intransponíveis[/color]")
	tooltip.visible = txt != ""
	if tooltip.visible:
		tooltip_label.text = txt
		var mp := root.get_viewport().get_mouse_position()
		tooltip.position = mp + Vector2(18, 18)
		tooltip.reset_size()


## One-line explanation of where a structure's items go (shown on hover).
func _flow_hint(w, b) -> String:
	match b.kind:
		"belt":
			var dir: String = I18n.t(Defs.DIR_NAMES[b.rot])
			var shape: int = Logistics.belt_shape(w, b)
			var curve := "" if shape == 0 else I18n.t(" · curva")
			if Logistics.belt_dead_end(w, b):
				return I18n.t("\n[color=#ff6a50]→ %s%s · sem destino: os itens param no fim[/color]") % [dir, curve]
			var t = w.building_at(b.pos + Defs.dir_vec(b.rot))
			return I18n.t("\n[color=#8f877c]→ %s%s · entrega em: %s[/color]") % [dir, curve, t.def.name]
		"miner", "crafter", "depot":
			return I18n.t("\n[color=#ffc04a]Saída: lado com a faixa amarela (→ %s)[/color]") % I18n.t(Defs.DIR_NAMES[b.rot])
	return ""


func _status_bb(b) -> String:
	var lvl: int = b.status_level()
	var s: String = b.status if b.status != "" else "ok"
	return "[color=#%s]● %s[/color]" % [_hex(UiTheme.LEVEL_COLORS[lvl]), I18n.t(s)]


func _update_info(w) -> void:
	var sel: Array = main.controller.selection
	if sel.size() > 1:
		_update_multi_info(w, sel)
		return
	var b = w.buildings.get(main.controller.selected)
	info_panel.visible = b != null
	if b == null:
		_info_for = -1
		return
	if _info_for == -2:
		_info_for = -1
	if _info_for != b.id:
		_info_for = b.id
		for ch in info_recipes.get_children():
			ch.queue_free()
		if b.kind == "crafter":
			for r in b.def.recipes:
				if not w.is_unlocked(r):
					continue
				var btn := _button(info_recipes, w.data.recipes[r].name, _on_recipe.bind(r))
				btn.toggle_mode = true
				btn.add_theme_font_size_override("font_size", 12)
		info_demolish.visible = b.kind != "core"
		info_filters.visible = b.kind == "splitter"
		if b.kind == "splitter":
			_fill_filters(w, b)
		info_toggle.visible = b.kind not in ["core", "belt", "wall", "pole", "depot", "splitter", "solar"]
	for ch in info_recipes.get_children():
		if ch is Button:
			ch.set_pressed_no_signal(ch.text == w.data.recipes.get(b.recipe, {}).get("name", ""))
	info_hp.visible = true
	info_title.text = b.def.name
	var lvl: int = b.status_level()
	info_status.text = "● " + I18n.t(b.status if b.status != "" else "ok")
	info_status.add_theme_color_override("font_color", UiTheme.LEVEL_COLORS[lvl])
	info_hp.max_value = b.max_hp
	info_hp.value = b.hp
	info_toggle.text = I18n.t("Desligar") if b.enabled else I18n.t("Ligar")
	var lines := [I18n.t("Integridade: %d / %d") % [int(b.hp), int(b.max_hp)]]
	if b.power_net >= 0 or float(b.def.get("power", 0)) > 0:
		if b.power_net < 0:
			lines.append(I18n.t("[color=#ff6a50]Sem conexão elétrica — construa um Poste próximo[/color]"))
		else:
			var net: Dictionary = w.power.net_of(b)
			lines.append(I18n.t("Rede #%d: %d/%d kW  (atendimento %d%%)") % [b.power_net + 1, int(net.get("used", 0)), int(net.get("cap", 0)), int(float(net.get("sat", 1.0)) * 100)])
	if float(b.def.get("power", 0)) > 0:
		lines.append(I18n.t("Consumo: %d kW  ·  prioridade %s") % [int(b.def.power), I18n.t("DEFESA") if int(b.def.get("priority", 1)) == 0 else I18n.t("produção")])
	match b.kind:
		"crafter":
			lines.append(I18n.t("Saída: faixa amarela (→ %s) · entrada: esteiras apontadas para qualquer outro lado") % I18n.t(Defs.DIR_NAMES[b.rot]))
			var r: Dictionary = w.data.recipes.get(b.recipe, {})
			if not r.is_empty():
				lines.append(I18n.t("Receita: %s → %s  (%.1fs)") % [_cost_text(r.inputs), _cost_text(r.outputs), float(r.time)])
				lines.append(I18n.t("Progresso: %d%%") % int(b.progress * 100))
		"miner":
			lines.append(I18n.t("Saída: lado com a faixa amarela (→ %s). R gira.") % I18n.t(Defs.DIR_NAMES[b.rot]))
			var n := 0
			for i in b.ore_cells:
				n += w.ore[i]
			lines.append(I18n.t("Minério restante: %d  ·  %.1f/min") % [n, float(b.def.rate) * 60.0])
		"generator":
			lines.append(I18n.t("Combustível: %d%% + %d carvão  ·  carga %d%%") % [int(100.0 * b.energy / float(b.def.fuel_value)), Items.count(b.inv, "coal"), int(b.power_sat * 100)])
		"battery":
			lines.append(I18n.t("Carga: %d / %d kJ") % [int(b.energy), int(b.def.battery_capacity)])
		"turret_gun":
			lines.append(I18n.t("Munição: %d disparos + %d pentes") % [b.rounds, Items.count(b.inv, "ammo")])
			lines.append(I18n.t("Abastecimento: esteiras adjacentes ou apontadas para a torre"))
		"turret_tesla":
			lines.append(I18n.t("Carga: %d%%") % int(100.0 * b.energy / float(b.def.shot_cost)))
		"repair":
			lines.append(I18n.t("Placas: %d  ·  raio %.0f") % [Items.count(b.inv, "iron_plate"), float(b.def.radius)])
		"core":
			lines.append(I18n.t("Recebe qualquer item por esteira. Estoque usado na construção."))
		"genesis":
			lines.append(I18n.t("Carga Genesis: %d%%") % int(b.progress * 100))
			lines.append(I18n.t("Precisa de energia contínua. Durante a carga, ondas chegam de todos os ninhos."))
		"lab":
			var cur: String = w.research.current
			if cur == "":
				lines.append(I18n.t("[color=#ffc04a]Nenhuma pesquisa selecionada (T)[/color]"))
			else:
				lines.append(I18n.t("Pesquisando: %s (%d%%)") % [w.research.techs[cur].name, int(w.research.fraction(cur) * 100)])
				lines.append(I18n.t("Faltam: ") + _cost_text(w.research.remaining_of(cur)))
			lines.append(I18n.t("Pacotes: ") + (_cost_text(b.inv) if not b.inv.is_empty() else I18n.t("nenhum")))
		"solar":
			lines.append(I18n.t("Rendimento atual: %d kW (luz %d%%)") % [int(float(b.def.power_out) * w.daylight()), int(w.daylight() * 100)])
		"splitter":
			lines.append(I18n.t("Itens filtrados vão só para a saída escolhida; os demais seguem pelas saídas livres."))
		"belt":
			lines.append(I18n.t("Itens: %d · direção: %s") % [b.belt_items.size(), I18n.t(Defs.DIR_NAMES[b.rot])])
			if Logistics.belt_dead_end(w, b):
				lines.append(I18n.t("[color=#ff6a50]Sem destino: aponte o fim da esteira para uma máquina, outra esteira ou o Núcleo.[/color]"))
	if not b.inv.is_empty() and b.kind not in ["turret_gun", "generator", "repair"]:
		lines.append(I18n.t("Entrada: ") + _cost_text(b.inv))
	if not b.out.is_empty():
		lines.append(I18n.t("Saída: ") + _cost_text(b.out))
	info_body.text = "\n".join(lines)


func _update_multi_info(w, sel: Array) -> void:
	info_panel.visible = true
	if _info_for != -2:
		_info_for = -2
		for ch in info_recipes.get_children():
			ch.queue_free()
		_button(info_recipes, I18n.t("Copiar como planta (Ctrl+C)"), main.controller.copy_selection_blueprint).add_theme_font_size_override("font_size", 12)
		info_filters.visible = false
		info_toggle.visible = true
		info_demolish.visible = true
	var counts := {}
	var levels := [0, 0, 0]
	for id in sel:
		var b = w.buildings.get(id)
		if b == null:
			continue
		counts[b.def.name] = int(counts.get(b.def.name, 0)) + 1
		levels[b.status_level()] += 1
	info_title.text = I18n.t("%d estruturas selecionadas") % sel.size()
	info_status.text = I18n.t("● %d ok   ● %d atenção   ● %d falha") % levels
	info_status.add_theme_color_override("font_color", UiTheme.LEVEL_COLORS[2 if levels[2] > 0 else (1 if levels[1] > 0 else 0)])
	info_hp.visible = false
	var parts := []
	for k in counts:
		parts.append("%d× %s" % [counts[k], k])
	var bp_cost: Dictionary = load("res://src/sim/blueprint.gd").cost(w, load("res://src/sim/blueprint.gd").capture(w, sel))
	info_body.text = "\n".join(parts) + I18n.t("\n\nCusto para replicar: ") + _cost_text(bp_cost)
	info_toggle.text = I18n.t("Ligar/Desligar todas")


func _update_research(w) -> void:
	var rs = w.research
	if rs.current != "":
		research_label.text = I18n.t("PESQUISA: %s — %d%%   (T)") % [rs.techs[rs.current].name, int(rs.fraction(rs.current) * 100)]
	elif w.list("lab").is_empty():
		research_label.text = I18n.t("PESQUISA: construa um Laboratório para desbloquear tecnologias (T)")
	else:
		research_label.text = I18n.t("PESQUISA: nenhuma selecionada — pressione T")
	if not research_panel.visible:
		return
	var key := "%d|%s|%d" % [rs.done.size(), rs.current, int(rs.fraction(rs.current) * 100) if rs.current != "" else 0]
	if key == _research_key:
		return
	_research_key = key
	for c in research_list.get_children():
		c.queue_free()
	for id in rs.order:
		var t: Dictionary = rs.techs[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		research_list.add_child(row)
		var state := ""
		var col := UiTheme.DIM
		if rs.done.has(id):
			state = I18n.t("CONCLUÍDA")
			col = UiTheme.OK
		elif rs.current == id:
			state = I18n.t("EM ANDAMENTO %d%%") % int(rs.fraction(id) * 100)
			col = Color(0.55, 0.85, 1.0)
		elif rs.is_available(id):
			state = I18n.t("DISPONÍVEL")
			col = UiTheme.TEXT
		else:
			var req := []
			for r in t.get("requires", []):
				req.append(rs.techs[r].name)
			state = I18n.t("requer: ") + ", ".join(req)
		var btn := _button(row, t.name, _on_research.bind(id))
		btn.custom_minimum_size = Vector2(210, 30)
		btn.disabled = not rs.is_available(id) or rs.current == id
		var info := _rich(row)
		info.custom_minimum_size.x = 600
		info.text = "[color=#%s][b]%s[/b][/color]  [color=#8f877c]%s[/color]\n%s" % [_hex(col), state, _cost_text(t.cost), t.desc]


func _on_research(id: String) -> void:
	main.world.research.select(main.world, id)
	_research_key = ""


func _on_recipe(r: String) -> void:
	var w = main.world
	w.set_recipe(w.buildings.get(main.controller.selected), r)
	_info_for = -1


func _fill_filters(w, b) -> void:
	var items: Array = w.data.items.keys()
	for i in 3:
		var ob: OptionButton = _filter_opts[i]
		ob.clear()
		ob.add_item(I18n.t("Qualquer item"))
		ob.set_item_metadata(0, "")
		for k in items:
			ob.add_item(w.data.item_name(k))
			ob.set_item_metadata(ob.item_count - 1, k)
			if b.filter[i] == k:
				ob.select(ob.item_count - 1)
		if b.filter[i] == "":
			ob.select(0)


func _on_filter(index: int, slot: int) -> void:
	var w = main.world
	var b = w.buildings.get(main.controller.selected)
	if b != null:
		w.set_filter(b, slot, str(_filter_opts[slot].get_item_metadata(index)))


func _on_toggle() -> void:
	if main.controller.selection.size() > 1:
		main.controller.toggle_selection()
		return
	var b = main.world.buildings.get(main.controller.selected)
	if b != null:
		b.enabled = not b.enabled


func _on_demolish() -> void:
	main.controller.demolish_selection()


func _update_stats(w) -> void:
	var t := I18n.t("[table=5][cell][b]Item      [/b][/cell][cell][b]Produção/min   [/b][/cell][cell][b]Consumo/min   [/b][/cell][cell][b]Total produzido   [/b][/cell][cell][b]No Núcleo[/b][/cell]")
	for item in w.data.items:
		var p: int = w.stats.rate(item)
		var c: int = w.stats.rate(item, true)
		var col := "d8cfc2" if p >= c else "ff6a50"
		t += "[cell]%s[/cell][cell][color=#%s]%d[/color][/cell][cell]%d[/cell][cell]%d[/cell][cell]%d[/cell]" % [
			_item_icon(w, item, 18) + " " + w.data.item_name(item), col, p, c, int(w.stats.produced.get(item, 0)), Items.count(w.storage, item)]
	t += I18n.t("[/table]\n\n[b]Energia[/b]\n")
	for net in w.power.networks:
		t += I18n.t("Rede #%d: %d nós, %d estruturas — geração %d kW, demanda %d kW, atendimento %d%%%s\n") % [
			net.id + 1, net.nodes.size(), net.members.size(), int(net.get("cap", 0)), int(net.get("demand", 0)),
			int(float(net.get("sat", 1)) * 100), ("  · bateria %d kJ" % int(net.stored)) if float(net.get("capacity", 0)) > 0 else ""]
	t += I18n.t("\n[b]Diagnóstico de máquinas[/b]  [color=#8f877c](gargalos, insumos faltando, excesso de produção)[/color]\n")
	var summary := {}
	for b in w.buildings.values():
		if b.kind in ["belt", "wall", "pole", "core", "splitter", "depot"]:
			continue
		var key: String = b.def.name
		if not summary.has(key):
			summary[key] = {}
		var s: String = b.status if b.status != "" else "ok"
		summary[key][s] = int(summary[key].get(s, 0)) + 1
	for key in summary:
		var parts := []
		for s in summary[key]:
			var lvl: int = int(load("res://src/sim/building.gd").STATUS_LEVEL.get(s, 1))
			parts.append("[color=#%s]%d %s[/color]" % [_hex(UiTheme.LEVEL_COLORS[lvl]), summary[key][s], I18n.t(s)])
		t += "%s: %s\n" % [key, ", ".join(parts)]
	var blocked := 0
	for b in w.list("belt"):
		if b.status == "saída bloqueada":
			blocked += 1
	if blocked > 0:
		t += I18n.t("[color=#ffc04a]%d esteiras congestionadas (excesso de produção ou destino cheio)[/color]\n") % blocked
	t += I18n.t("\n[b]Combate[/b]: %d abates · %d disparos · %d estruturas perdidas · %d ruínas aguardando reconstrução") % [w.stats.kills, w.stats.shots, w.stats.lost, w.ghosts.size()]
	stats_body.text = t


const HELP_TEXT := """[b]Objetivo:[/b] manter o Núcleo vivo. Se ele cair, a partida termina. Sobreviva às 10 hordas da campanha.

[color=#8f877c]Teclas padrão — todas podem ser alteradas em Opções › Controles.[/color]
[b]Câmera[/b]: WASD/setas movem · roda do mouse aproxima · botão do meio arrasta · Z/C giram a câmera.
[b]Construção[/b]: teclas 1–0, -, = ou barra inferior escolhem a estrutura · clique esquerdo constrói (arraste para esteiras, muros e postes) · R gira (Shift+R inverte) · clique direito demole (arraste para várias) · Q copia o tipo sob o cursor · Ctrl+C / Ctrl+V copiam a configuração de uma máquina · G reconstrói tudo que foi destruído · Del demole a seleção.
[b]Seleção e plantas[/b]: Shift+arrastar seleciona uma área · Ctrl+C copia a seleção como planta · R gira a planta · clique cola · B reutiliza a última planta · Ctrl+V cola a configuração em todas as selecionadas.
[b]Diagnóstico[/b]: V liga o rastreamento de fluxo — passe o mouse sobre uma estrutura para ver suas [color=#ffa040]fontes[/color] e [color=#50d8ff]destinos[/color] · Tab mostra gargalos · clique num alerta para ir até ele · clique no minimapa para mover a câmera.
[b]Pesquisa[/b]: construa um Laboratório e leve Pacotes de Pesquisa (Montadora: placa + componente) por esteira. T abre a árvore. Pacotes Militares (munição + componente) liberam a linha de defesa avançada.
[b]Jogo[/b]: Espaço pausa · ponto/vírgula (ou +/− do teclado numérico) mudam a velocidade · N chama a próxima horda agora · Tab estatísticas · F3 depuração (rotas, redes, alvos) · F5 salvar · F9 carregar · Esc menu.

[b]Fluxo de itens[/b]: mineradoras e máquinas enviam produtos pelo [color=#ffc04a]lado com a faixa amarela[/color] (setas no chão) — qualquer esteira encostada nesse lado recebe os itens. As setas animadas das esteiras mostram o sentido; desenhe em L para fazer curvas (a esquina vira curva sozinha) e use R para girar. Um [color=#ff6a50]fim vermelho[/color] indica esteira sem destino; setas vermelhas indicam esteira travada. Esteiras levam o item para o que estiver à frente. O Divisor alterna entre esquerda, frente e direita; selecione-o para filtrar que item vai por cada saída. Máquinas recebem de esteiras apontadas para elas. Torres, geradores e estações de reparo também [i]puxam[/i] o que precisam de qualquer esteira encostada nelas — passe uma linha de munição ao lado das torres. O Núcleo aceita tudo e seu estoque paga as construções.
[b]Energia[/b]: o Núcleo e os Postes distribuem energia na área ao redor; postes próximos se conectam sozinhos. Grupos separados formam redes independentes. Se faltar energia, [color=#ff8060]defesas[/color] são atendidas antes da [color=#ffc04a]produção[/color]. Baterias guardam o excedente.
[b]Inimigos[/b]: Rastejantes atacam o que estiver perto da rota · Corredores procuram brechas · Aríetes atravessam muros e causam dano em área · Sabotadores caçam geradores, postes e esteiras · Planadores voam sobre muros (só Antiaérea e Torre Elétrica os atingem) · Cuspidores cospem ácido de longe, por cima dos muros. As hordas são anunciadas com direção e composição; patrulhas podem surgir sem aviso.
[b]Luzes de estado[/b]: [color=#73f27f]verde[/color] funcionando · [color=#ffc04a]amarelo[/color] esperando (insumo, saída cheia) · [color=#ff5a3c]vermelho[/color] falha (sem energia, sem munição)."""
