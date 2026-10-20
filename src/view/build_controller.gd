extends Node
## Translates mouse/keyboard input into construction commands on the World.
##
## LMB: place (drag to draw belts/walls) or select · Shift+LMB drag: select an area
## RMB: demolish (drag) · R: rotate · Q: pipette · Ctrl+C: copy settings, or the
## selection as a blueprint · Ctrl+V: paste settings · B: last blueprint
## V: trace item flow · G: rebuild ruins · Del: demolish selection · Esc: cancel

const Defs = preload("res://src/sim/defs.gd")
const Building = preload("res://src/sim/building.gd")
const Blueprint = preload("res://src/sim/blueprint.gd")
const Meshes = preload("res://src/view/meshes.gd")
const Bindings = preload("res://src/ui/bindings.gd")
const Logistics = preload("res://src/sim/systems/logistics_system.gd")
const I18n = preload("res://src/ui/i18n.gd")

const BLUEPRINT_TOOL := "@blueprint"

var main
var tool := ""
var rot := 0
var hover := Vector2i(-1, -1)
var hover_point := Vector2.ZERO
var selected := 0                ## primary selection (inspector)
var selection: Array = []        ## every selected id (area selection)
var clipboard := {}              ## copied machine settings
var blueprint := {}              ## copied group of structures
var trace_mode := false
var last_reason := ""
var _drag := ""                  ## "", "place", "remove", "select"
var _drag_start := Vector2i.ZERO
var _last_cell := Vector2i(-1, -1)
var _last_belt := 0
var _preview: Node3D
var _preview_key := ""
var _preview_h := {}
var _range_ring: MeshInstance3D
var _area_box: MeshInstance3D
var _select_mm: MultiMeshInstance3D
var _ok_mat: Material
var _bad_mat: Material
var _trace_key := ""
var trace_up: Array = []
var trace_down: Array = []


func _init(p_main) -> void:
	main = p_main


func _ready() -> void:
	_ok_mat = Meshes.mat("preview_ok", Color(0.4, 1.0, 0.5, 0.35), {"alpha": true, "unshaded": true})
	_bad_mat = Meshes.mat("preview_bad", Color(1.0, 0.25, 0.15, 0.35), {"alpha": true, "unshaded": true})
	_range_ring = MeshInstance3D.new()
	_range_ring.material_override = Meshes.mat("range", Color(1.0, 0.7, 0.3, 0.08), {"alpha": true, "unshaded": true})
	_range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.view.add_child(_range_ring)
	_area_box = MeshInstance3D.new()
	_area_box.mesh = Meshes.box_mesh(Vector3.ONE)
	_area_box.material_override = Meshes.mat("area", Color(0.4, 0.8, 1.0, 0.12), {"alpha": true, "unshaded": true})
	_area_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.view.add_child(_area_box)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Meshes.box_mesh(Vector3.ONE)
	mm.instance_count = 0
	_select_mm = MultiMeshInstance3D.new()
	_select_mm.multimesh = mm
	_select_mm.material_override = Meshes.mat("select", Color(1.0, 0.65, 0.2, 0.18), {"alpha": true, "unshaded": true})
	_select_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.view.add_child(_select_mm)


func world():
	return main.world


func set_tool(t: String) -> void:
	tool = "" if t == tool else t
	_drag = ""
	if tool != "":
		_select([])
	_preview_key = ""
	main.view.show_grid = tool != ""


func cancel() -> bool:
	if tool != "" or selected != 0 or not selection.is_empty():
		tool = ""
		_select([])
		_preview_key = ""
		main.view.show_grid = false
		return true
	return false


func _select(ids: Array) -> void:
	selection = ids
	selected = ids[0] if ids.size() == 1 else 0


func hovered_building():
	return world().building_at(hover) if world() != null else null


## Origin cell for placing `tool` centred under the cursor.
func origin_for(type: String, r: int) -> Vector2i:
	var sz := Building.footprint(world().data.buildings[type], r)
	return Vector2i(floori(hover_point.x - sz.x * 0.5 + 0.5), floori(hover_point.y - sz.y * 0.5 + 0.5))


func blueprint_origin() -> Vector2i:
	return Vector2i(floori(hover_point.x - int(blueprint.w) * 0.5 + 0.5), floori(hover_point.y - int(blueprint.h) * 0.5 + 0.5))


func handle_input(event: InputEvent) -> bool:
	var w = world()
	if w == null or not main.in_game:
		return false
	if event is InputEventMouseMotion:
		_update_hover(event.position)
		if _drag == "place":
			_drag_place()
		elif _drag == "remove":
			_remove_at(hover)
		return false
	if event is InputEventMouseButton:
		_update_hover(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if tool == BLUEPRINT_TOOL:
					_paste_blueprint()
				elif tool != "":
					_drag = "place"
					_last_cell = Vector2i(-1, -1)
					_last_belt = 0
					_drag_place()
				elif event.shift_pressed:
					_drag = "select"
					_drag_start = hover
				else:
					_click_select()
			else:
				if _drag == "select":
					_finish_area_select()
				_drag = ""
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if tool == BLUEPRINT_TOOL:
					set_tool("")
				else:
					_drag = "remove"
					_remove_at(hover)
			else:
				_drag = ""
			return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed:
			if event.keycode == KEY_C:
				_copy()
				return true
			if event.keycode == KEY_V:
				_paste()
				return true
			return false
		match Bindings.action_for(event):
			"rotate":
				var dirn := -1 if event.shift_pressed else 1
				if tool == BLUEPRINT_TOOL:
					for i in posmod(dirn, 4):
						blueprint = Blueprint.rotated(w, blueprint)
				else:
					rot = posmod(rot + dirn, 4)
					if tool == "" and selected != 0:
						w.rotate_building(w.buildings.get(selected), rot)
				_preview_key = ""
				return true
			"pipette":
				_pipette()
				return true
			"trace":
				trace_mode = not trace_mode
				main.hud.toast(I18n.t("Rastreamento de fluxo: %s") % (I18n.t("ligado — passe o mouse sobre uma estrutura") if trace_mode else I18n.t("desligado")))
				return true
			"blueprint":
				if not blueprint.is_empty():
					tool = BLUEPRINT_TOOL
					_preview_key = ""
					main.view.show_grid = true
				else:
					main.hud.toast(I18n.t("Nenhuma planta copiada. Selecione uma área (Shift+arrastar) e pressione Ctrl+C"))
				return true
			"rebuild":
				var n: int = w.rebuild_all_ghosts()
				main.hud.toast(I18n.t("%d estruturas reconstruídas") % n if n > 0 else I18n.t("Nada para reconstruir (ou recursos insuficientes)"))
				return true
			"demolish":
				if not selection.is_empty():
					demolish_selection()
					return true
	return false


func _update_hover(screen: Vector2) -> void:
	var p = main.camera.ground_at(screen)
	if p == null:
		return
	hover_point = Vector2(p.x, p.z)
	hover = Vector2i(floori(p.x), floori(p.z))


func _click_select() -> void:
	var w = world()
	var b = w.building_at(hover)
	if b != null:
		_select([b.id])
		rot = b.rot
		return
	var g: int = w.ghost_at(hover)
	if g != -1:
		if not w.rebuild_ghost(g):
			main.hud.toast(I18n.t("Recursos insuficientes para reconstruir"))
		return
	if w.in_bounds(hover) and w.terminals.has(w.idx(hover)):
		var why: String = w.read_terminal(hover)
		if why != "":
			main.hud.toast(why)
		return
	_select([])


func area_rect() -> Rect2i:
	var a := Vector2i(mini(_drag_start.x, hover.x), mini(_drag_start.y, hover.y))
	var b := Vector2i(maxi(_drag_start.x, hover.x), maxi(_drag_start.y, hover.y))
	return Rect2i(a, b - a + Vector2i.ONE)


func _finish_area_select() -> void:
	var w = world()
	var r := area_rect()
	var ids := []
	var seen := {}
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var b = w.building_at(Vector2i(x, y))
			if b != null and b.kind != "core" and not seen.has(b.id):
				seen[b.id] = true
				ids.append(b.id)
	_select(ids)
	if ids.size() > 1:
		main.hud.toast(I18n.t("%d estruturas selecionadas — Ctrl+C copia como planta, Del demole") % ids.size())


func demolish_selection() -> void:
	var w = world()
	for id in selection:
		w.remove(id)
	_select([])
	main.audio.click()


func toggle_selection() -> void:
	var w = world()
	var any_on := false
	for id in selection:
		var b = w.buildings.get(id)
		if b != null and b.enabled:
			any_on = true
	for id in selection:
		var b = w.buildings.get(id)
		if b != null:
			b.enabled = not any_on


func copy_selection_blueprint() -> void:
	var bp: Dictionary = Blueprint.capture(world(), selection)
	if bp.is_empty():
		return
	blueprint = bp
	tool = BLUEPRINT_TOOL
	_preview_key = ""
	main.view.show_grid = true
	main.hud.toast(I18n.t("Planta copiada (%d estruturas). Clique para colar · R gira · B reutiliza") % bp.entries.size())


func _paste_blueprint() -> void:
	var w = world()
	var r: Array = Blueprint.paste(w, blueprint, blueprint_origin())
	if r[0] > 0:
		main.audio.click()
	if r[1] > 0:
		main.hud.toast(I18n.t("%d estruturas colocadas, %d puladas (espaço ocupado ou recursos)") % [r[0], r[1]])


func _drag_place() -> void:
	var w = world()
	var cell := hover if _is_line_tool() else origin_for(tool, rot)
	if cell == _last_cell:
		return
	if _is_line_tool() and _last_cell.x >= 0:
		# Fill every cell between the previous and current cell (4-connected).
		var c := _last_cell
		while c != cell:
			var d := cell - c
			var step := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
			if tool == "belt":
				var r := Defs.DIRS.find(step)
				var prev = w.buildings.get(_last_belt)
				if prev != null:
					_rotate_belt(prev, r)
				rot = r
			c += step
			_place_at(c)
	else:
		_place_at(cell)
	_last_cell = cell


func _is_line_tool() -> bool:
	return tool == "belt" or tool == "wall" or tool == "pole"


func _place_at(c: Vector2i) -> void:
	var w = world()
	var reason: String = w.can_place(tool, c, rot)
	if reason != "":
		last_reason = reason
		# Dragging a belt over an existing belt re-orients it.
		var b = w.building_at(c)
		if tool == "belt" and b != null and b.kind == "belt":
			_rotate_belt(b, rot)
			_last_belt = b.id
		return
	var id: int = w.place(tool, c, rot, false, str(clipboard.get("recipe", "")) if clipboard.get("type", "") == tool else "")
	if id != 0 and tool == "splitter" and clipboard.get("type", "") == tool:
		w.set_filters(w.buildings[id], clipboard.get("filter", ["", "", ""]))
	if tool == "belt":
		_last_belt = id
	main.audio.click()


func _rotate_belt(b, r: int) -> void:
	world().rotate_building(b, r)


func _remove_at(c: Vector2i) -> void:
	var w = world()
	var b = w.building_at(c)
	if b != null and b.kind != "core":
		if b.id in selection:
			selection.erase(b.id)
			_select(selection)
		w.remove(b.id)
		main.audio.click()
		return
	var g: int = w.ghost_at(c)
	if g != -1:
		w.remove_ghost(g)


func _pipette() -> void:
	var b = hovered_building()
	if b == null or b.kind == "core":
		tool = ""
		_preview_key = ""
		main.view.show_grid = false
		return
	tool = b.type
	rot = b.rot
	clipboard = {"type": b.type, "recipe": b.recipe, "enabled": b.enabled, "filter": b.filter.duplicate()}
	_preview_key = ""
	main.view.show_grid = true


func _copy() -> void:
	if selection.size() > 1:
		copy_selection_blueprint()
		return
	var b = hovered_building()
	if b == null:
		b = world().buildings.get(selected)
	if b != null:
		clipboard = {"type": b.type, "recipe": b.recipe, "enabled": b.enabled, "filter": b.filter.duplicate()}
		main.hud.toast(I18n.t("Configuração copiada: %s") % b.def.name)


func _paste() -> void:
	var targets := []
	var hb = hovered_building()
	if hb != null:
		targets.append(hb)
	else:
		for id in selection:
			var b = world().buildings.get(id)
			if b != null:
				targets.append(b)
	if targets.is_empty() or clipboard.is_empty():
		return
	for b in targets:
		if b.kind == "crafter" and clipboard.recipe in b.def.get("recipes", []):
			world().set_recipe(b, clipboard.recipe)
		if b.type == clipboard.type:
			b.enabled = bool(clipboard.get("enabled", b.enabled))
			if b.kind == "splitter":
				world().set_filters(b, clipboard.get("filter", ["", "", ""]))
	main.hud.toast(I18n.t("Configuração colada em %d estrutura(s)") % targets.size())


# --- per frame ------------------------------------------------------------------

func _process(_delta: float) -> void:
	var w = world()
	if w == null or not main.in_game:
		if _preview:
			_preview.visible = false
		_range_ring.visible = false
		_area_box.visible = false
		_select_mm.multimesh.visible_instance_count = 0
		return
	# Drop ids that no longer exist (destroyed while selected).
	if not selection.is_empty():
		var alive := []
		for id in selection:
			if w.buildings.has(id):
				alive.append(id)
		if alive.size() != selection.size():
			_select(alive)
	_update_preview(w)
	_update_selection_boxes(w)
	_update_trace(w)
	_area_box.visible = _drag == "select"
	if _area_box.visible:
		var r := area_rect()
		_area_box.scale = Vector3(r.size.x, 0.1, r.size.y)
		_area_box.position = Vector3(r.position.x + r.size.x * 0.5, 0.05, r.position.y + r.size.y * 0.5)
	# Range / coverage indicator for tool or selection.
	var def = null
	var center := Vector2.ZERO
	var sb = w.buildings.get(selected)
	if tool != "" and tool != BLUEPRINT_TOOL:
		def = w.data.buildings[tool]
		var sz := Building.footprint(def, rot)
		center = Vector2(origin_for(tool, rot)) + Vector2(sz) * 0.5
		if _is_line_tool():
			center = Vector2(hover) + Vector2(0.5, 0.5)
	elif sb != null:
		def = sb.def
		center = sb.center()
	_range_ring.visible = false
	if def != null:
		var r := float(def.get("range", def.get("radius", 0.0)))
		if r > 0.0:
			_range_ring.mesh = Meshes.cyl_mesh(r, r, 0.02, 48)
			_range_ring.position = Vector3(center.x, 0.03, center.y)
			_range_ring.visible = true
		elif def.has("supply_radius"):
			var s := float(def.supply_radius) * 2.0
			_range_ring.mesh = Meshes.box_mesh(Vector3(s, 0.02, s))
			_range_ring.position = Vector3(center.x, 0.03, center.y)
			_range_ring.visible = true


func _update_trace(w) -> void:
	if not trace_mode:
		if _trace_key != "":
			_trace_key = ""
			trace_up = []
			trace_down = []
			main.view.set_trace(null, [], [])
		return
	var tb = hovered_building()
	if tb == null:
		tb = w.buildings.get(selected)
	var key := "%d_%d" % [tb.id if tb != null else 0, w.structures_version]
	if key == _trace_key:
		return
	_trace_key = key
	if w.logistics.dirty:
		w.logistics.rebuild(w)
	trace_up = w.logistics.trace(w, tb.id, true) if tb != null else []
	trace_down = w.logistics.trace(w, tb.id, false) if tb != null else []
	main.view.set_trace(tb, trace_up, trace_down)


func _update_selection_boxes(w) -> void:
	var mm := _select_mm.multimesh
	if mm.instance_count < selection.size():
		mm.instance_count = maxi(selection.size(), mm.instance_count * 2)
	mm.visible_instance_count = selection.size()
	for i in selection.size():
		var b = w.buildings[selection[i]]
		var basis := Basis().scaled(Vector3(b.size.x + 0.15, 0.08, b.size.y + 0.15))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(b.center().x, 0.04, b.center().y)))


func _update_preview(w) -> void:
	if tool == "":
		if _preview:
			_preview.visible = false
		return
	var key := "%s_%d_%d" % [tool, rot, hash(blueprint) if tool == BLUEPRINT_TOOL else 0]
	if key != _preview_key:
		if _preview:
			_preview.queue_free()
		if tool == BLUEPRINT_TOOL:
			_preview = Node3D.new()
			for e in blueprint.entries:
				var h := Meshes.build(e.type, w.data.buildings[e.type], int(e.rot))
				h.root.position = Vector3(int(e.x), 0, int(e.y))
				_preview.add_child(h.root)
		else:
			_preview_h = Meshes.build(tool, w.data.buildings[tool], rot)
			_preview = _preview_h.root
		main.view.add_child(_preview)
		_preview_key = key
	if tool == BLUEPRINT_TOOL:
		var o := blueprint_origin()
		var checks: Array = Blueprint.check(w, blueprint, o)
		var bad := 0
		for i in checks.size():
			var ok: bool = checks[i][1] == ""
			if not ok:
				bad += 1
			Meshes.override_all(_preview.get_child(i), _ok_mat if ok else _bad_mat)
		var cost: Dictionary = Blueprint.cost(w, blueprint)
		last_reason = "" if w.can_afford(cost) else I18n.t("Recursos insuficientes para a planta inteira")
		if bad > 0:
			last_reason = I18n.t("%d de %d estruturas não cabem aqui") % [bad, checks.size()]
		_preview.position = Vector3(o.x, 0.02, o.y)
		_preview.visible = true
		return
	var o := hover if _is_line_tool() else origin_for(tool, rot)
	var reason: String = w.can_place(tool, o, rot)
	last_reason = reason
	if tool == "belt" and _preview_h.has("belt_mi"):
		var shape: int = Logistics.shape_at(w, o, rot)
		if shape != _preview_h.shape:
			_preview_h.shape = shape
			_preview_h.belt_mi.mesh = Meshes.belt_mesh(shape)
	Meshes.override_all(_preview, _ok_mat if reason == "" else _bad_mat)
	_preview.position = Vector3(o.x, 0.02, o.y)
	_preview.visible = true
