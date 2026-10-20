extends Node
## Translates mouse/keyboard input into construction commands on the World.
##
## LMB: place (drag to draw belts/walls) or select · RMB: demolish (drag) · R: rotate
## Q: pipette · Ctrl+C / Ctrl+V: copy / paste machine settings · G: rebuild ruins
## Del: demolish selection · Esc: cancel tool

const Defs = preload("res://src/sim/defs.gd")
const Building = preload("res://src/sim/building.gd")
const Meshes = preload("res://src/view/meshes.gd")

var main
var tool := ""
var rot := 0
var hover := Vector2i(-1, -1)
var hover_point := Vector2.ZERO
var selected := 0
var clipboard := {}
var last_reason := ""
var _drag := ""                 ## "", "place", "remove"
var _last_cell := Vector2i(-1, -1)
var _last_belt := 0
var _preview: Node3D
var _preview_key := ""
var _range_ring: MeshInstance3D
var _select_box: MeshInstance3D
var _ok_mat: Material
var _bad_mat: Material


func _init(p_main) -> void:
	main = p_main


func _ready() -> void:
	_ok_mat = Meshes.mat("preview_ok", Color(0.4, 1.0, 0.5, 0.35), {"alpha": true, "unshaded": true})
	_bad_mat = Meshes.mat("preview_bad", Color(1.0, 0.25, 0.15, 0.35), {"alpha": true, "unshaded": true})
	_range_ring = MeshInstance3D.new()
	_range_ring.material_override = Meshes.mat("range", Color(1.0, 0.7, 0.3, 0.08), {"alpha": true, "unshaded": true})
	_range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.view.add_child(_range_ring)
	_select_box = MeshInstance3D.new()
	_select_box.mesh = Meshes.box_mesh(Vector3.ONE)
	_select_box.material_override = Meshes.mat("select", Color(1.0, 0.65, 0.2, 0.18), {"alpha": true, "unshaded": true})
	_select_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.view.add_child(_select_box)


func world():
	return main.world


func set_tool(t: String) -> void:
	tool = "" if t == tool else t
	_drag = ""
	if tool != "":
		selected = 0
	_preview_key = ""
	main.view.show_grid = tool != ""


func cancel() -> bool:
	if tool != "" or selected != 0:
		tool = ""
		selected = 0
		_preview_key = ""
		main.view.show_grid = false
		return true
	return false


func hovered_building():
	return world().building_at(hover) if world() != null else null


## Origin cell for placing `tool` centred under the cursor.
func origin_for(type: String, r: int) -> Vector2i:
	var sz := Building.footprint(world().data.buildings[type], r)
	return Vector2i(floori(hover_point.x - sz.x * 0.5 + 0.5), floori(hover_point.y - sz.y * 0.5 + 0.5))


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
				if tool != "":
					_drag = "place"
					_last_cell = Vector2i(-1, -1)
					_last_belt = 0
					_drag_place()
				else:
					_click_select()
			else:
				_drag = ""
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_drag = "remove"
				_remove_at(hover)
			else:
				_drag = ""
			return true
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				rot = posmod(rot + (-1 if event.shift_pressed else 1), 4)
				_preview_key = ""
				if tool == "" and selected != 0:
					w.rotate_building(w.buildings.get(selected), rot)
				return true
			KEY_Q:
				_pipette()
				return true
			KEY_C:
				if event.ctrl_pressed:
					_copy()
					return true
			KEY_V:
				if event.ctrl_pressed:
					_paste()
					return true
			KEY_G:
				var n: int = w.rebuild_all_ghosts()
				main.hud.toast("%d estruturas reconstruídas" % n if n > 0 else "Nada para reconstruir (ou recursos insuficientes)")
				return true
			KEY_DELETE, KEY_X:
				if selected != 0:
					w.remove(selected)
					selected = 0
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
		selected = b.id
		rot = b.rot
		return
	var g: int = w.ghost_at(hover)
	if g != -1:
		if not w.rebuild_ghost(g):
			main.hud.toast("Recursos insuficientes para reconstruir")
		return
	selected = 0


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
	if tool == "belt":
		_last_belt = id
	main.audio.click()


func _rotate_belt(b, r: int) -> void:
	world().rotate_building(b, r)


func _remove_at(c: Vector2i) -> void:
	var w = world()
	var b = w.building_at(c)
	if b != null and b.kind != "core":
		if b.id == selected:
			selected = 0
		w.remove(b.id)
		main.audio.click()
		return
	var g: int = w.ghost_at(c)
	if g != -1:
		w.remove_ghost(g)


func _pipette() -> void:
	var b = hovered_building()
	if b == null or b.kind == "core":
		set_tool("")
		tool = ""
		return
	tool = b.type
	rot = b.rot
	clipboard = {"type": b.type, "recipe": b.recipe}
	_preview_key = ""
	main.view.show_grid = true


func _copy() -> void:
	var b = hovered_building()
	if b == null:
		b = world().buildings.get(selected)
	if b != null:
		clipboard = {"type": b.type, "recipe": b.recipe, "enabled": b.enabled}
		main.hud.toast("Configuração copiada: %s" % b.def.name)


func _paste() -> void:
	var b = hovered_building()
	if b == null or clipboard.is_empty():
		return
	if b.kind == "crafter" and clipboard.recipe in b.def.get("recipes", []):
		world().set_recipe(b, clipboard.recipe)
	b.enabled = bool(clipboard.get("enabled", b.enabled))
	main.hud.toast("Configuração colada em %s" % b.def.name)


func _process(_delta: float) -> void:
	var w = world()
	if w == null or not main.in_game:
		if _preview:
			_preview.visible = false
		_range_ring.visible = false
		_select_box.visible = false
		return
	_update_preview(w)
	var sb = w.buildings.get(selected)
	_select_box.visible = sb != null
	if sb != null:
		_select_box.scale = Vector3(sb.size.x + 0.15, 0.08, sb.size.y + 0.15)
		_select_box.position = Vector3(sb.center().x, 0.04, sb.center().y)
	# Range / coverage indicator for tool or selection.
	var def = null
	var center := Vector2.ZERO
	if tool != "":
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


func _update_preview(w) -> void:
	if tool == "":
		if _preview:
			_preview.visible = false
		return
	var key := "%s_%d" % [tool, rot]
	if key != _preview_key:
		if _preview:
			_preview.queue_free()
		var h := Meshes.build(tool, w.data.buildings[tool], rot)
		_preview = h.root
		main.view.add_child(_preview)
		_preview_key = key
	var o := hover if _is_line_tool() else origin_for(tool, rot)
	var reason: String = w.can_place(tool, o, rot)
	last_reason = reason
	Meshes.override_all(_preview, _ok_mat if reason == "" else _bad_mat)
	_preview.position = Vector3(o.x, 0.02, o.y)
	_preview.visible = true
