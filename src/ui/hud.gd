extends CanvasLayer
## In-game interface: resources, energy, waves, objectives, transmissions, alerts,
## build bar, building inspector, statistics/diagnostics, help, pause and end screens.

const UiTheme = preload("res://src/ui/ui_theme.gd")
const Items = preload("res://src/sim/items.gd")
const Defs = preload("res://src/sim/defs.gd")

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
var info_panel: PanelContainer
var info_title: Label
var info_status: Label
var info_hp: ProgressBar
var info_body: RichTextLabel
var info_recipes: HBoxContainer
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
	_build_menu()
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


func _rich(parent: Control, fit: bool = true) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = fit
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
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
	var title := _label(hb, "LAST INDUSTRY", 15, UiTheme.ACCENT)
	title.add_theme_constant_override("outline_size", 0)
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
	_label(vb, "OBJETIVO", 12, UiTheme.ACCENT)
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
		var b := _button(hotbar, "%s\n%s" % [keys[i] if i < keys.size() else "", def.name], main.controller.set_tool.bind(type))
		b.custom_minimum_size = Vector2(104, 42)
		b.add_theme_font_size_override("font_size", 12)
		b.tooltip_text = _build_tooltip_text(def)
		b.toggle_mode = true
		hot_buttons[type] = b


func _build_tooltip_text(def: Dictionary) -> String:
	var lines := [def.name, def.get("desc", ""), "", "Custo: " + _cost_text(def.get("cost", {}))]
	if float(def.get("power", 0)) > 0:
		lines.append("Energia: %d kW (%s)" % [int(def.power), "defesa" if int(def.get("priority", 1)) == 0 else "produção"])
	if def.has("power_out"):
		lines.append("Gera: %d kW" % int(def.power_out))
	if def.has("range"):
		lines.append("Alcance: %.1f  Dano: %d" % [float(def.range), int(def.damage)])
	lines.append("Integridade: %d" % int(def.hp))
	return "\n".join(lines)


func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s" % [int(cost[k]), main.data.item_name(k)])
	return ", ".join(parts) if not parts.is_empty() else "—"


func _build_info() -> void:
	info_panel = _panel(game_ui)
	_place(info_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(12, 128))
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 320
	info_panel.add_child(vb)
	info_title = _label(vb, "", 18, UiTheme.ACCENT)
	info_status = _label(vb, "")
	info_hp = ProgressBar.new()
	info_hp.custom_minimum_size = Vector2(300, 12)
	info_hp.show_percentage = false
	vb.add_child(info_hp)
	info_body = _rich(vb)
	info_body.custom_minimum_size.x = 300
	info_recipes = HBoxContainer.new()
	vb.add_child(info_recipes)
	var actions := HBoxContainer.new()
	vb.add_child(actions)
	info_toggle = _button(actions, "Desligar", _on_toggle)
	info_demolish = _button(actions, "Demolir (Del)", _on_demolish)
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
	_label(sv, "ESTATÍSTICAS E DIAGNÓSTICO  (Tab)", 16, UiTheme.ACCENT)
	stats_body = _rich(sv)
	stats_body.custom_minimum_size = Vector2(740, 0)

	research_panel = _center_panel(860)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	research_panel.add_child(rv)
	_label(rv, "ÁRVORE DE PESQUISA  (T)", 16, UiTheme.ACCENT)
	_label(rv, "Laboratórios consomem pacotes recebidos por esteira. Fabrique-os na Montadora.", 13, UiTheme.DIM)
	research_list = VBoxContainer.new()
	research_list.add_theme_constant_override("separation", 4)
	rv.add_child(research_list)

	help_panel = _center_panel(820)
	var hv := VBoxContainer.new()
	help_panel.add_child(hv)
	_label(hv, "COMO OPERAR A INSTALAÇÃO  (H)", 16, UiTheme.ACCENT)
	var help := _rich(hv)
	help.custom_minimum_size.x = 800
	help.text = HELP_TEXT

	pause_panel = _center_panel(320)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	pause_panel.add_child(pv)
	_label(pv, "PAUSADO", 22, UiTheme.ACCENT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(pv, "Continuar", func(): main.set_menu_paused(false))
	_button(pv, "Salvar (F5)", main.save_game)
	_button(pv, "Carregar (F9)", main.load_game)
	_button(pv, "Ajuda (H)", func(): help_panel.visible = not help_panel.visible)
	_button(pv, "Menu principal", main.to_main_menu)
	_button(pv, "Sair do jogo", main.quit_game)

	end_panel = _center_panel(520)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 10)
	end_panel.add_child(ev)
	end_title = _label(ev, "", 30, UiTheme.ACCENT)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body = _label(ev, "")
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_body.custom_minimum_size.x = 500
	end_continue = _button(ev, "Continuar no modo Sobrevivência", main.continue_survival)
	_button(ev, "Nova partida", main.start_new_game)
	_button(ev, "Menu principal", main.to_main_menu)


func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(shade)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	vb.position = Vector2(110, -220)
	vb.add_theme_constant_override("separation", 10)
	menu_root.add_child(vb)
	var title := _label(vb, "LAST INDUSTRY", 76, Color(0.93, 0.88, 0.8))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_label(vb, "“Quando o mundo acabou, as máquinas continuaram trabalhando.”", 19, UiTheme.ACCENT)
	_label(vb, "Extrair. Produzir. Defender. Sobreviver.", 15, UiTheme.DIM)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 30
	vb.add_child(spacer)
	for b in [_button(vb, "Nova partida", main.start_new_game)]:
		b.custom_minimum_size = Vector2(300, 46)
	menu_continue = _button(vb, "Continuar", main.load_game)
	menu_continue.custom_minimum_size = Vector2(300, 46)
	_button(vb, "Como jogar", func(): help_panel.visible = not help_panel.visible).custom_minimum_size = Vector2(300, 46)
	_button(vb, "Sair", main.quit_game).custom_minimum_size = Vector2(300, 46)
	var ver := _label(menu_root, "v%s — protótipo (MVP)  ·  Windows / Linux" % ProjectSettings.get_setting("application/config/version", "0.1.0"), 12, UiTheme.DIM)
	_place(ver, Control.PRESET_BOTTOM_LEFT, Vector2(16, 12))


# --- state switches -------------------------------------------------------------

func show_main_menu(has_save: bool) -> void:
	menu_root.visible = true
	game_ui.visible = false
	pause_panel.visible = false
	end_panel.visible = false
	stats_panel.visible = false
	menu_continue.disabled = not has_save


func show_game() -> void:
	menu_root.visible = false
	game_ui.visible = true
	pause_panel.visible = false
	end_panel.visible = false
	help_panel.visible = false
	_trans_shown = -1
	_info_for = -1


func show_pause(v: bool) -> void:
	pause_panel.visible = v


func show_end(state: String) -> void:
	var w = main.world
	end_panel.visible = true
	end_continue.visible = state == "won"
	if state == "won":
		end_title.text = "O NÚCLEO SOBREVIVEU"
		end_title.add_theme_color_override("font_color", UiTheme.OK)
	else:
		end_title.text = "NÚCLEO DESTRUÍDO"
		end_title.add_theme_color_override("font_color", UiTheme.BAD)
	end_body.text = "Hordas repelidas: %d\nCriaturas abatidas: %d\nEstruturas perdidas: %d\nTempo de operação: %s\nPlacas produzidas: %d   ·   Munição produzida: %d" % [
		w.stats.waves, w.stats.kills, w.stats.lost, _clock(w.time),
		int(w.stats.produced.get("iron_plate", 0)), int(w.stats.produced.get("ammo", 0))]
	if state == "won":
		end_body.text += "\n\n" + str(w.transmissions.back().text if not w.transmissions.is_empty() else "")


func toggle_stats() -> void:
	stats_panel.visible = not stats_panel.visible


func toggle_research() -> void:
	research_panel.visible = not research_panel.visible
	_research_key = ""


func close_overlays() -> bool:
	var any := help_panel.visible or stats_panel.visible or research_panel.visible
	help_panel.visible = false
	stats_panel.visible = false
	research_panel.visible = false
	return any


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible


func toast(text: String) -> void:
	toast_label.text = text
	_toast_t = 2.5


func on_events(events: Array) -> void:
	for ev in events:
		if ev.e == "objective":
			toast("Objetivo concluído!")


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


func _hex(c: Color) -> String:
	return c.to_html(false)


func _update_top(w) -> void:
	var parts := []
	for item in ["iron_ore", "coal", "iron_plate", "gear", "ammo"]:
		var r: int = w.stats.rate(item)
		parts.append("[color=#%s]■[/color] %s [b]%d[/b] [color=#8f877c]+%d/min[/color]" % [
			_hex(w.data.item_color(item).lightened(0.2)), str(w.data.items[item].get("short", w.data.item_name(item))), Items.count(w.storage, item), r])
	var pt: Dictionary = w.power.totals
	var pcol := UiTheme.OK if float(pt.get("sat", 1.0)) > 0.98 else (UiTheme.WARN if float(pt.get("sat", 1.0)) > 0.6 else UiTheme.BAD)
	var bat := ""
	if float(pt.get("capacity", 0.0)) > 0.0:
		bat = "  bateria %d%%" % int(100.0 * float(pt.stored) / float(pt.capacity))
	parts.append("[color=#%s]⚡ %d / %d kW%s[/color]" % [_hex(pcol), int(pt.get("used", 0.0)), int(pt.get("cap", 0.0)), bat])
	top_label.text = "   ".join(parts)
	var ws = w.waves
	var txt := ""
	if ws.active:
		txt = "[color=#ff5a3c][b]HORDA %d EM ANDAMENTO[/b][/color] — %d inimigos" % [ws.index, w.enemies.size() + ws.queue.size()]
	elif ws.has_more(w):
		var col := "ff5a3c" if ws.timer < 30 else ("ffc04a" if ws.timer < 90 else "d8cfc2")
		txt = "[color=#%s]Horda %d%s em [b]%s[/b][/color] [color=#8f877c]%s[/color]" % [col, ws.index + 1,
			"" if w.survival else "/%d" % ws.campaign_length(), _clock(ws.timer), ws.describe_next(w)]
	var spd: String = "  [color=#ffc04a]⏸ PAUSA[/color]" if main.paused else ("  ×%d" % int(main.speed) if main.speed != 1.0 else "")
	wave_label.text = txt + spd


func _update_objective(w) -> void:
	var o = w.objectives.current_objective()
	if o == null:
		obj_label.text = "Todos os objetivos concluídos. Sobreviva." if not w.survival else "Modo Sobrevivência: resista o máximo possível."
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
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 428
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		alerts_box.add_child(l)
	for i in alerts_box.get_child_count():
		var l: Label = alerts_box.get_child(i)
		if i >= n:
			l.visible = false
			continue
		var a: Dictionary = w.alerts[i]
		var age: float = w.time - float(a.time)
		l.visible = age < 25.0
		l.text = a.text
		var c: Color = {"danger": UiTheme.BAD, "warn": UiTheme.WARN, "info": UiTheme.OK}.get(a.level, UiTheme.TEXT)
		l.add_theme_color_override("font_color", c)
		l.modulate.a = clampf(1.6 - age / 15.0, 0.25, 1.0)


func _update_hotbar(w) -> void:
	for type in hot_buttons:
		var b: Button = hot_buttons[type]
		b.set_pressed_no_signal(main.controller.tool == type)
		var def: Dictionary = w.data.buildings[type]
		if not w.is_unlocked(type):
			b.modulate = Color(0.45, 0.45, 0.5)
			var tech = w.research.techs.get(w.research.unlocked_by.get(type, ""), {})
			b.tooltip_text = _build_tooltip_text(def) + "\n\nBLOQUEADO — requer pesquisa: %s" % tech.get("name", "?")
		else:
			b.modulate = Color.WHITE if w.can_afford(def.get("cost", {})) else Color(1, 0.55, 0.5)
			b.tooltip_text = _build_tooltip_text(def)


func _update_tooltip() -> void:
	var c = main.controller
	var w = main.world
	var txt := ""
	if c.tool != "":
		var def: Dictionary = w.data.buildings[c.tool]
		txt = "[b]%s[/b]  [color=#8f877c]%s[/color]" % [def.name, _cost_text(def.get("cost", {}))]
		if c.last_reason != "":
			txt += "\n[color=#ff6a50]%s[/color]" % c.last_reason
		else:
			txt += "\n[color=#8f877c]R girar · Clique direito demolir · Esc cancelar[/color]"
	else:
		var b = c.hovered_building()
		if b != null:
			txt = "[b]%s[/b]  %d/%d\n%s" % [b.def.name, int(b.hp), int(b.max_hp), _status_bb(b)]
		else:
			var g: int = w.ghost_at(c.hover)
			if g != -1:
				var gd: Dictionary = w.ghosts[g]
				var def: Dictionary = w.data.buildings[gd.type]
				txt = "[color=#ff8060]Ruína: %s[/color]\nClique para reconstruir (%s)" % [def.name, _cost_text(def.get("cost", {}))]
			elif w.in_bounds(c.hover):
				var i: int = w.idx(c.hover)
				var t: int = w.terrain[i]
				if Defs.ORE_ITEM.has(t) and w.ore[i] > 0:
					txt = "%s — %d restantes" % [w.data.item_name(Defs.ORE_ITEM[t]), w.ore[i]]
				elif t == Defs.T_ROCK:
					txt = "[color=#8f877c]Ruínas intransponíveis[/color]"
	tooltip.visible = txt != ""
	if tooltip.visible:
		tooltip_label.text = txt
		var mp := root.get_viewport().get_mouse_position()
		tooltip.position = mp + Vector2(18, 18)
		tooltip.reset_size()


func _status_bb(b) -> String:
	var lvl: int = b.status_level()
	var s: String = b.status if b.status != "" else "ok"
	return "[color=#%s]● %s[/color]" % [_hex(UiTheme.LEVEL_COLORS[lvl]), s]


func _update_info(w) -> void:
	var b = w.buildings.get(main.controller.selected)
	info_panel.visible = b != null
	if b == null:
		_info_for = -1
		return
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
		info_toggle.visible = b.kind not in ["core", "belt", "wall", "pole", "depot", "splitter", "solar"]
	for ch in info_recipes.get_children():
		if ch is Button:
			ch.set_pressed_no_signal(ch.text == w.data.recipes.get(b.recipe, {}).get("name", ""))
	info_title.text = b.def.name
	var lvl: int = b.status_level()
	info_status.text = "● " + (b.status if b.status != "" else "ok")
	info_status.add_theme_color_override("font_color", UiTheme.LEVEL_COLORS[lvl])
	info_hp.max_value = b.max_hp
	info_hp.value = b.hp
	info_toggle.text = "Desligar" if b.enabled else "Ligar"
	var lines := ["Integridade: %d / %d" % [int(b.hp), int(b.max_hp)]]
	if b.power_net >= 0 or float(b.def.get("power", 0)) > 0:
		if b.power_net < 0:
			lines.append("[color=#ff6a50]Sem conexão elétrica — construa um Poste próximo[/color]")
		else:
			var net: Dictionary = w.power.net_of(b)
			lines.append("Rede #%d: %d/%d kW  (atendimento %d%%)" % [b.power_net + 1, int(net.get("used", 0)), int(net.get("cap", 0)), int(float(net.get("sat", 1.0)) * 100)])
	if float(b.def.get("power", 0)) > 0:
		lines.append("Consumo: %d kW  ·  prioridade %s" % [int(b.def.power), "DEFESA" if int(b.def.get("priority", 1)) == 0 else "produção"])
	match b.kind:
		"crafter":
			var r: Dictionary = w.data.recipes.get(b.recipe, {})
			if not r.is_empty():
				lines.append("Receita: %s → %s  (%.1fs)" % [_cost_text(r.inputs), _cost_text(r.outputs), float(r.time)])
				lines.append("Progresso: %d%%" % int(b.progress * 100))
		"miner":
			var n := 0
			for i in b.ore_cells:
				n += w.ore[i]
			lines.append("Minério restante: %d  ·  %.1f/min" % [n, float(b.def.rate) * 60.0])
		"generator":
			lines.append("Combustível: %d%% + %d carvão  ·  carga %d%%" % [int(100.0 * b.energy / float(b.def.fuel_value)), Items.count(b.inv, "coal"), int(b.power_sat * 100)])
		"battery":
			lines.append("Carga: %d / %d kJ" % [int(b.energy), int(b.def.battery_capacity)])
		"turret_gun":
			lines.append("Munição: %d disparos + %d pentes" % [b.rounds, Items.count(b.inv, "ammo")])
			lines.append("Abastecimento: esteiras adjacentes ou apontadas para a torre")
		"turret_tesla":
			lines.append("Carga: %d%%" % int(100.0 * b.energy / float(b.def.shot_cost)))
		"repair":
			lines.append("Placas: %d  ·  raio %.0f" % [Items.count(b.inv, "iron_plate"), float(b.def.radius)])
		"core":
			lines.append("Recebe qualquer item por esteira. Estoque usado na construção.")
		"lab":
			var cur: String = w.research.current
			if cur == "":
				lines.append("[color=#ffc04a]Nenhuma pesquisa selecionada (T)[/color]")
			else:
				lines.append("Pesquisando: %s (%d%%)" % [w.research.techs[cur].name, int(w.research.fraction(cur) * 100)])
				lines.append("Faltam: " + _cost_text(w.research.remaining_of(cur)))
			lines.append("Pacotes: " + (_cost_text(b.inv) if not b.inv.is_empty() else "nenhum"))
		"solar":
			lines.append("Rendimento atual: %d kW (luz %d%%)" % [int(float(b.def.power_out) * w.daylight()), int(w.daylight() * 100)])
		"belt":
			lines.append("Itens: %d" % b.belt_items.size())
	if not b.inv.is_empty() and b.kind not in ["turret_gun", "generator", "repair"]:
		lines.append("Entrada: " + _cost_text(b.inv))
	if not b.out.is_empty():
		lines.append("Saída: " + _cost_text(b.out))
	info_body.text = "\n".join(lines)


func _update_research(w) -> void:
	var rs = w.research
	if rs.current != "":
		research_label.text = "PESQUISA: %s — %d%%   (T)" % [rs.techs[rs.current].name, int(rs.fraction(rs.current) * 100)]
	elif w.list("lab").is_empty():
		research_label.text = "PESQUISA: construa um Laboratório para desbloquear tecnologias (T)"
	else:
		research_label.text = "PESQUISA: nenhuma selecionada — pressione T"
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
			state = "CONCLUÍDA"
			col = UiTheme.OK
		elif rs.current == id:
			state = "EM ANDAMENTO %d%%" % int(rs.fraction(id) * 100)
			col = Color(0.55, 0.85, 1.0)
		elif rs.is_available(id):
			state = "DISPONÍVEL"
			col = UiTheme.TEXT
		else:
			var req := []
			for r in t.get("requires", []):
				req.append(rs.techs[r].name)
			state = "requer: " + ", ".join(req)
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


func _on_toggle() -> void:
	var b = main.world.buildings.get(main.controller.selected)
	if b != null:
		b.enabled = not b.enabled


func _on_demolish() -> void:
	var w = main.world
	w.remove(main.controller.selected)
	main.controller.selected = 0


func _update_stats(w) -> void:
	var t := "[table=5][cell][b]Item      [/b][/cell][cell][b]Produção/min   [/b][/cell][cell][b]Consumo/min   [/b][/cell][cell][b]Total produzido   [/b][/cell][cell][b]No Núcleo[/b][/cell]"
	for item in w.data.items:
		var p: int = w.stats.rate(item)
		var c: int = w.stats.rate(item, true)
		var col := "d8cfc2" if p >= c else "ff6a50"
		t += "[cell]%s[/cell][cell][color=#%s]%d[/color][/cell][cell]%d[/cell][cell]%d[/cell][cell]%d[/cell]" % [
			w.data.item_name(item), col, p, c, int(w.stats.produced.get(item, 0)), Items.count(w.storage, item)]
	t += "[/table]\n\n[b]Energia[/b]\n"
	for net in w.power.networks:
		t += "Rede #%d: %d nós, %d estruturas — geração %d kW, demanda %d kW, atendimento %d%%%s\n" % [
			net.id + 1, net.nodes.size(), net.members.size(), int(net.get("cap", 0)), int(net.get("demand", 0)),
			int(float(net.get("sat", 1)) * 100), ("  · bateria %d kJ" % int(net.stored)) if float(net.get("capacity", 0)) > 0 else ""]
	t += "\n[b]Diagnóstico de máquinas[/b]  [color=#8f877c](gargalos, insumos faltando, excesso de produção)[/color]\n"
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
			parts.append("[color=#%s]%d %s[/color]" % [_hex(UiTheme.LEVEL_COLORS[lvl]), summary[key][s], s])
		t += "%s: %s\n" % [key, ", ".join(parts)]
	var blocked := 0
	for b in w.list("belt"):
		if b.status == "saída bloqueada":
			blocked += 1
	if blocked > 0:
		t += "[color=#ffc04a]%d esteiras congestionadas (excesso de produção ou destino cheio)[/color]\n" % blocked
	t += "\n[b]Combate[/b]: %d abates · %d disparos · %d estruturas perdidas · %d ruínas aguardando reconstrução" % [w.stats.kills, w.stats.shots, w.stats.lost, w.ghosts.size()]
	stats_body.text = t


const HELP_TEXT := """[b]Objetivo:[/b] manter o Núcleo vivo. Se ele cair, a partida termina. Sobreviva às 10 hordas da campanha.

[b]Câmera[/b]: WASD/setas movem · roda do mouse aproxima · botão do meio arrasta · Z/C giram a câmera.
[b]Construção[/b]: teclas 1–0, -, = ou barra inferior escolhem a estrutura · clique esquerdo constrói (arraste para esteiras, muros e postes) · R gira (Shift+R inverte) · clique direito demole (arraste para várias) · Q copia o tipo sob o cursor · Ctrl+C / Ctrl+V copiam a configuração de uma máquina · G reconstrói tudo que foi destruído · Del demole a seleção.
[b]Pesquisa[/b]: construa um Laboratório e leve Pacotes de Pesquisa (Montadora: placa + componente) por esteira. T abre a árvore. Pacotes Militares (munição + componente) liberam a linha de defesa avançada.
[b]Jogo[/b]: Espaço pausa · +/− velocidade · N chama a próxima horda agora · Tab estatísticas · F3 depuração (rotas, redes, alvos) · F5 salvar · F9 carregar · Esc menu.

[b]Fluxo de itens[/b]: mineradoras e máquinas enviam produtos pela saída (seta amarela). Esteiras levam o item para o que estiver à frente. Máquinas recebem de esteiras apontadas para elas. Torres, geradores e estações de reparo também [i]puxam[/i] o que precisam de qualquer esteira encostada nelas — passe uma linha de munição ao lado das torres. O Núcleo aceita tudo e seu estoque paga as construções.
[b]Energia[/b]: o Núcleo e os Postes distribuem energia na área ao redor; postes próximos se conectam sozinhos. Grupos separados formam redes independentes. Se faltar energia, [color=#ff8060]defesas[/color] são atendidas antes da [color=#ffc04a]produção[/color]. Baterias guardam o excedente.
[b]Inimigos[/b]: Rastejantes atacam o que estiver perto da rota · Corredores procuram brechas · Aríetes atravessam muros e causam dano em área · Sabotadores caçam geradores, postes e esteiras · Planadores voam sobre muros (só Antiaérea e Torre Elétrica os atingem). As hordas são anunciadas com direção e composição; patrulhas podem surgir sem aviso.
[b]Luzes de estado[/b]: [color=#73f27f]verde[/color] funcionando · [color=#ffc04a]amarelo[/color] esperando (insumo, saída cheia) · [color=#ff5a3c]vermelho[/color] falha (sem energia, sem munição)."""
