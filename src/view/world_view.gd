extends Node3D
## Renders the simulation state. Read-only with respect to the World: it consumes
## `events` for one-shot effects and polls state for everything else.

const Defs = preload("res://src/sim/defs.gd")
const Meshes = preload("res://src/view/meshes.gd")
const GroundShader = preload("res://src/view/ground.gdshader")
const FogShader = preload("res://src/view/fog.gdshader")
const Logistics = preload("res://src/sim/systems/logistics_system.gd")
const Kit = preload("res://src/view/kit.gd")
const Fx = preload("res://src/view/fx.gd")
const RUIN_MODELS := ["city/building-a", "city/building-e", "city/building-f", "city/building-g", "city/building-l",
	"city/building-n", "city/building-p", "city/building-q", "city/building-r", "city/water-tower",
	"city/chimney-large", "city/detail-tank-large", "city/windmill-low", "factory/machine-bed", "factory/crane"]

var world
var nodes := {}           ## building id -> visual handles
var debug := false
var show_grid := false

var env: Environment
var sun: DirectionalLight3D
var ground_mat: ShaderMaterial
var fog_mat: ShaderMaterial
var _fog_img: Image
var _fog_tex: ImageTexture
var _fog_ver := -1
var terrain_root: Node3D
var buildings_root: Node3D
var ghosts_root: Node3D
var ore_mm: MultiMeshInstance3D
var items_mm: MultiMeshInstance3D
var bars_mm: MultiMeshInstance3D
var trace_mm: MultiMeshInstance3D
var enemy_mm := {}        ## type -> MultiMeshInstance3D
var fx_mesh := ImmediateMesh.new()
var wires_mesh := ImmediateMesh.new()
var debug_mesh := ImmediateMesh.new()
var fx: Array = []
var particles: Node3D       ## fx.gd: pooled one-shot particle effects
var terminal_nodes := {}    ## cell index -> {root, lamp, light}
var nest_nodes: Array = []  ## parallel to world.spawn_points
var objective_target = null ## Vector2 map position of the active objective (set by the HUD)
var _marker: Node3D
var ash: GPUParticles3D
var _ghosts_ver := -1
var _power_ver := -1
var _ore_ver := -1
var _debug_ver := -1
var _belt_ver := -1
var _t := 0.0
var _alarm := 0.0
var camera_focus := Vector3.ZERO


func _ready() -> void:
	_build_environment()
	terrain_root = Node3D.new()
	add_child(terrain_root)
	buildings_root = Node3D.new()
	add_child(buildings_root)
	ghosts_root = Node3D.new()
	add_child(ghosts_root)
	particles = Fx.new()
	add_child(particles)
	_marker = _make_marker()
	add_child(_marker)
	items_mm = _make_mm(Meshes.box_mesh(Vector3(0.22, 0.16, 0.22)), Meshes.mat("items", Color.WHITE, {"vcol": true, "rough": 0.6}))
	bars_mm = _make_mm(Meshes.box_mesh(Vector3(1, 0.05, 0.1)), Meshes.mat("bars", Color.WHITE, {"vcol": true, "unshaded": true}))
	bars_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trace_mm = _make_mm(Meshes.box_mesh(Vector3.ONE), Meshes.mat("trace", Color.WHITE, {"vcol": true, "unshaded": true, "alpha": true}))
	trace_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for m in [fx_mesh, wires_mesh, debug_mesh]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = Meshes.mat("lines", Color.WHITE, {"vcol": true, "unshaded": true, "alpha": true})
		add_child(mi)


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.045, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.40, 0.38)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.29, 0.26)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.78
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sun)
	ash = GPUParticles3D.new()
	ash.amount = 900
	ash.lifetime = 9.0
	ash.preprocess = 9.0
	ash.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 30, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(35, 1, 35)
	pm.direction = Vector3(0.3, -1, 0.15)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0.12, -0.25, 0.05)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	ash.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.75, 0.72, 0.68, 0.55)
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = am
	ash.draw_pass_1 = q
	ash.position = Vector3(0, 14, 0)
	add_child(ash)


## Bouncing arrow and ground ring over the active objective's location.
func _make_marker() -> Node3D:
	var n := Node3D.new()
	var m := Meshes.mat("marker", Color(1.0, 0.75, 0.25), {"emit": Color(1.0, 0.7, 0.2), "energy": 2.5, "unshaded": true})
	var arrow := Meshes.add(n, Meshes.cyl_mesh(0.45, 0.0, 0.8, 4), Vector3(0, 2.6, 0), m)
	arrow.name = "Arrow"
	Meshes.add(n, Meshes.cyl_mesh(0.14, 0.14, 0.7, 6), Vector3(0, 3.35, 0), m).name = "Shaft"
	var ring := Meshes.add(n, Meshes.cyl_mesh(1.1, 1.1, 0.03, 24), Vector3(0, 0.03, 0), Meshes.mat("markerring", Color(1.0, 0.75, 0.25, 0.25), {"alpha": true, "unshaded": true}))
	ring.name = "Ring"
	for c in n.get_children():
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	return n


func _make_mm(mesh: Mesh, m: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	add_child(mi)
	return mi


# --- binding ------------------------------------------------------------------

func bind(p_world) -> void:
	world = p_world
	objective_target = null
	for c in terrain_root.get_children():
		c.queue_free()
	for c in buildings_root.get_children():
		c.queue_free()
	for c in ghosts_root.get_children():
		c.queue_free()
	for mi in enemy_mm.values():
		mi.queue_free()
	enemy_mm.clear()
	nodes.clear()
	fx.clear()
	_ghosts_ver = -1
	_power_ver = -1
	_ore_ver = -1
	_debug_ver = -1
	_belt_ver = -1
	_build_terrain()
	for b in world.buildings.values():
		_add_building(b)
	for type in world.data.enemies:
		var def: Dictionary = world.data.enemies[type]
		var mesh: Mesh
		match type:
			"runner":
				mesh = Meshes.sphere_mesh(0.5, 0.7)
			"glider":
				mesh = Meshes.box_mesh(Vector3(0.7, 0.12, 1.6))
			"saboteur":
				mesh = Meshes.box_mesh(Vector3(0.9, 0.5, 0.6))
			"brute":
				mesh = Meshes.box_mesh(Vector3(1.0, 0.8, 0.85))
			_:
				mesh = Meshes.sphere_mesh(0.5, 0.65)
		var model := Kit.enemy_mesh(type)
		if model != null:
			enemy_mm[type] = _make_mm(model, null)
			enemy_mm[type].set_meta("model", true)
		else:
			enemy_mm[type] = _make_mm(mesh, Meshes.mat("enemy", Color.WHITE, {"vcol": true, "rough": 0.5, "metal": 0.3}))


func _build_terrain() -> void:
	var w: int = world.width
	var h: int = world.height
	var plane := PlaneMesh.new()
	plane.size = Vector2(w + 40, h + 40)
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GroundShader
	ground_mat.set_shader_parameter("map_size", Vector2(w, h))
	var g := MeshInstance3D.new()
	g.mesh = plane
	g.material_override = ground_mat
	g.position = Vector3(w * 0.5, 0, h * 0.5)
	terrain_root.add_child(g)
	# Ruins: broken concrete blocks of varying height.
	var rocks := []
	for y in h:
		for x in w:
			if world.terrain[y * w + x] == Defs.T_ROCK:
				rocks.append(Vector2i(x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = world.map_seed
	# Some ruin cells hold the shell of an old industrial building (Kenney city kit).
	var shells := {}
	var blocks := []
	for c in rocks:
		var name: String = RUIN_MODELS[rng.randi() % RUIN_MODELS.size()]
		if rng.randf() < 0.24 and Kit.has(name):
			if not shells.has(name):
				shells[name] = []
			shells[name].append(c)
		else:
			blocks.append(c)
	for name in shells:
		var smm := MultiMesh.new()
		smm.transform_format = MultiMesh.TRANSFORM_3D
		smm.mesh = Kit.merged_mesh(name)
		smm.instance_count = shells[name].size()
		for i in shells[name].size():
			var c: Vector2i = shells[name][i]
			var s := rng.randf_range(0.95, 1.15)
			var basis := Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5 + rng.randf_range(-0.08, 0.08))
			basis = Basis(Vector3(1, 0, 0), rng.randf_range(-0.05, 0.05)) * basis.scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
			smm.set_instance_transform(i, Transform3D(basis, Vector3(c.x + 0.5, -0.05, c.y + 0.5)))
		var smi := MultiMeshInstance3D.new()
		smi.multimesh = smm
		terrain_root.add_child(smi)
	rocks = blocks
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Meshes.box_mesh(Vector3.ONE)
	mm.instance_count = rocks.size()
	for i in rocks.size():
		var c: Vector2i = rocks[i]
		var ht := rng.randf_range(0.3, 2.6) if rng.randf() < 0.55 else rng.randf_range(0.2, 0.7)
		var basis := Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)).scaled(Vector3(rng.randf_range(0.85, 1.05), ht, rng.randf_range(0.85, 1.05)))
		basis = Basis(Vector3(1, 0, 0), rng.randf_range(-0.06, 0.06)) * basis
		mm.set_instance_transform(i, Transform3D(basis, Vector3(c.x + 0.5, ht * 0.5 - 0.05, c.y + 0.5)))
		var shade := rng.randf_range(0.18, 0.36)
		mm.set_instance_color(i, Color(shade, shade * 0.97, shade * 0.92) if rng.randf() > 0.12 else Color(0.35, 0.18, 0.1))
	var rmi := MultiMeshInstance3D.new()
	rmi.multimesh = mm
	rmi.material_override = Meshes.mat("ruins", Color.WHITE, {"vcol": true, "rough": 0.95})
	terrain_root.add_child(rmi)
	# Fog of war curtain (fog.gdshader), fed by world.revealed.
	var fp := PlaneMesh.new()
	fp.size = Vector2(w + 80, h + 80)
	fog_mat = ShaderMaterial.new()
	fog_mat.shader = FogShader
	fog_mat.set_shader_parameter("map_size", Vector2(w, h))
	_fog_img = Image.create(w, h, false, Image.FORMAT_L8)
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	fog_mat.set_shader_parameter("fog_tex", _fog_tex)
	var fg := MeshInstance3D.new()
	fg.mesh = fp
	fg.material_override = fog_mat
	fg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fg.position = Vector3(w * 0.5, 3.4, h * 0.5)
	terrain_root.add_child(fg)
	_fog_ver = -1
	_update_fog()
	terminal_nodes.clear()
	for key in world.terminals:
		_add_terminal(key)
	ore_mm = MultiMeshInstance3D.new()
	ore_mm.material_override = Meshes.mat("ore", Color.WHITE, {"vcol": true, "rough": 0.7, "metal": 0.3})
	terrain_root.add_child(ore_mm)
	_rebuild_ore()
	# Nests
	nest_nodes.clear()
	for sp in world.spawn_points:
		var n := Node3D.new()
		nest_nodes.append(n)
		n.position = Vector3(sp.x + 0.5, 0, sp.y + 0.5)
		var red := Meshes.mat("nest", Color(0.25, 0.04, 0.03), {"emit": Color(0.9, 0.12, 0.05), "energy": 1.6})
		Meshes.cyl(n, 1.9, 0.08, Vector3(0, 0.04, 0), red, 2.1, 16)
		var dark := Meshes.mat("nestdark", Color(0.06, 0.04, 0.04))
		for i in 7:
			var a := TAU * i / 7.0
			var spike := Meshes.cyl(n, 0.02, 1.4, Vector3(cos(a) * 1.9, 0.5, sin(a) * 1.9), dark, 0.22, 5)
			spike.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.2, 0.1)
		l.light_energy = 1.5
		l.omni_range = 7.0
		l.position = Vector3(0, 1.2, 0)
		n.add_child(l)
		terrain_root.add_child(n)


## Data terminal: an old console on a slab with a beacon that goes dark once read.
func _add_terminal(key: int) -> void:
	var c := Vector2i(key % world.width, key / world.width)
	var n := Node3D.new()
	n.position = Vector3(c.x + 0.5, 0, c.y + 0.5)
	terrain_root.add_child(n)
	Meshes.box(n, Vector3(0.95, 0.08, 0.95), Vector3(0, 0.04, 0), Meshes.mat("cdark", Meshes.CONCRETE_DARK))
	Kit.place(n, "factory/scanner-high", Vector3(0, 0.08, 0), Vector3(0.9, 1.1, 0.9))
	var lamp := Meshes.add(n, Meshes.sphere_mesh(0.12), Vector3(0, 1.35, 0), Meshes.mat("cyan", Meshes.CYAN, {"emit": Meshes.CYAN, "energy": 3.0}))
	var l := OmniLight3D.new()
	l.light_color = Meshes.CYAN
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = Vector3(0, 1.4, 0)
	n.add_child(l)
	terminal_nodes[key] = {"root": n, "lamp": lamp, "light": l}
	_update_terminal(key)


func _update_terminal(key: int) -> void:
	var t = world.terminals.get(key)
	var h = terminal_nodes.get(key)
	if t == null or h == null:
		return
	h.root.visible = world.revealed[key] != 0
	h.light.visible = not t.read
	h.lamp.material_override = Meshes.status_mat(0) if t.read else Meshes.mat("cyan", Meshes.CYAN, {"emit": Meshes.CYAN, "energy": 3.0})


func _update_fog() -> void:
	if world.fog_version == _fog_ver:
		return
	_fog_ver = world.fog_version
	var bytes := PackedByteArray()
	bytes.resize(world.revealed.size())
	for i in bytes.size():
		bytes[i] = 255 if world.revealed[i] != 0 else 0
	_fog_img.set_data(world.width, world.height, false, Image.FORMAT_L8, bytes)
	_fog_tex.update(_fog_img)
	for key in terminal_nodes:
		_update_terminal(key)


func _rebuild_ore() -> void:
	_ore_ver = world.ore_version
	var cells := []
	var w: int = world.width
	for i in world.terrain.size():
		if Defs.ORE_ITEM.has(world.terrain[i]) and world.ore[i] > 0:
			cells.append(i)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Meshes.box_mesh(Vector3(0.34, 0.22, 0.3))
	mm.instance_count = cells.size() * 3
	var rng := RandomNumberGenerator.new()
	rng.seed = world.map_seed + 17
	for k in cells.size():
		var i: int = cells[k]
		var c := Vector2(i % w, i / w)
		var iron: bool = world.terrain[i] == Defs.T_IRON
		var crystal: bool = world.terrain[i] == Defs.T_CRYSTAL
		for j in 3:
			var s := rng.randf_range(0.6, 1.4)
			var tall := Vector3(0.7, 2.2, 0.7) if crystal else Vector3.ONE
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))).scaled(tall * s)
			var p := Vector3(c.x + rng.randf_range(0.2, 0.8), 0.06 * s * tall.y, c.y + rng.randf_range(0.2, 0.8))
			mm.set_instance_transform(k * 3 + j, Transform3D(basis, p))
			var col := Color(0.55, 0.26, 0.12) if iron else Color(0.07, 0.065, 0.06)
			if crystal:
				col = Color(0.5, 1.6, 1.4)   # > 1: glows through the HDR glow pass
			mm.set_instance_color(k * 3 + j, col * rng.randf_range(0.75, 1.15))
	ore_mm.multimesh = mm


func _add_building(b) -> void:
	var h := Meshes.build(b.type, b.def, b.rot)
	h.root.position = Vector3(b.pos.x, 0, b.pos.y)
	h["level"] = -1
	buildings_root.add_child(h.root)
	if h.has("smoke_at"):
		h["smoke"] = particles.make_smoke(h.body, h.smoke_at)
	nodes[b.id] = h


func _remove_building(id: int) -> void:
	var h = nodes.get(id)
	if h != null:
		h.root.queue_free()
		nodes.erase(id)


# --- per frame ----------------------------------------------------------------

func on_events(events: Array) -> void:
	for ev in events:
		match ev.e:
			"built":
				var b = world.buildings.get(ev.id)
				if b != null:
					_remove_building(ev.id)
					_add_building(b)
			"removed":
				_remove_building(ev.id)
			"destroyed":
				_remove_building(ev.id)
				_burst(ev.pos, Color(1.0, 0.5, 0.15), 14, 1.6, 0.6)
				particles.play("fire", _v3(ev.pos, 0.4), 1.4)
				particles.play("smoke", _v3(ev.pos, 0.8), 1.5)
			"shot":
				var to := _v3(ev.to, 1.9 if ev.get("air", false) else 0.35)
				var muzzle := _v3(ev.from, 0.95)
				muzzle += (to - muzzle).normalized() * 0.75
				fx.append({"k": "line", "a": muzzle, "b": to, "c": Color(1.0, 0.85, 0.4), "t": 0.0, "life": 0.06})
				particles.play("flash", muzzle, 0.8)
				particles.play("sparks", to, 0.7)
			"shell":
				fx.append({"k": "line", "a": _v3(ev.from, 1.0), "b": _v3(ev.to, 0.3), "c": Color(1.0, 0.6, 0.25), "t": 0.0, "life": 0.12})
				_burst(ev.to, Color(1.0, 0.55, 0.2), 18, float(ev.r), 0.35)
				particles.play("flash", _v3(ev.from, 1.0), 1.4)
				particles.play("fire", _v3(ev.to, 0.3), clampf(float(ev.r), 0.6, 1.6))
				particles.play("dust", _v3(ev.to, 0.1), clampf(float(ev.r), 0.8, 2.0))
			"arc":
				fx.append({"k": "arc", "pts": ev.points, "c": Color(0.5, 0.9, 1.0), "t": 0.0, "life": 0.18, "seed": randi()})
				for i in range(1, ev.points.size()):
					particles.play("sparks", _v3(ev.points[i], 0.4), 0.6)
			"drone":
				fx.append({"k": "drone", "a": _v3(ev.from, 1.0), "b": _v3(ev.to, 0.8), "c": Color(1.0, 0.7, 0.25) if ev.get("supply", false) else Color(0.4, 1.0, 0.5), "t": 0.0, "life": 0.9})
			"repair":
				fx.append({"k": "line", "a": _v3(ev.from, 1.0), "b": _v3(ev.to, 0.6), "c": Color(0.3, 1.0, 0.45), "t": 0.0, "life": 0.35})
			"enemy_died":
				_burst(ev.pos, Color(0.85, 0.2, 0.1) if not ev.elite else Color(1, 0.4, 0.1), 8 if not ev.elite else 24, 0.7 if not ev.elite else 2.5, 0.3)
				particles.play("gore", _v3(ev.pos, 0.3), 1.0 if not ev.elite else 1.8)
				if ev.elite:
					particles.play("fire", _v3(ev.pos, 0.3), 1.2)
			"terminal":
				_update_terminal(ev.key)
			"nest_destroyed":
				for i in nest_nodes.size():
					var nn: Node3D = nest_nodes[i]
					if Vector2(nn.position.x, nn.position.z).distance_to(ev.pos) < 0.1:
						nn.queue_free()
						nest_nodes.remove_at(i)
						break
				for k in 3:
					particles.play("fire", _v3(ev.pos, 0.4 + k * 0.5), 2.0)
				particles.play("smoke", _v3(ev.pos, 1.5), 2.5)
				particles.play("gore", _v3(ev.pos, 0.5), 2.5)
			"genesis_ready":
				var gb = world.buildings.get(ev.id)
				if gb != null:
					particles.play("flash", _v3(gb.center(), 3.4), 4.0)
			"spit":
				fx.append({"k": "line", "a": _v3(ev.from, 0.5), "b": _v3(ev.to, 0.4), "c": Color(0.6, 1.0, 0.2), "t": 0.0, "life": 0.25})
				particles.play("acid", _v3(ev.to, 0.3), clampf(float(ev.r), 0.8, 1.6))
			"bite":
				if ev.splash:
					_burst(ev.pos, Color(0.8, 0.6, 0.3), 10, 1.2, 0.25)
					particles.play("dust", _v3(ev.pos, 0.1), 1.4)
			"wave_start":
				_alarm = 4.0


## Highlights the item flow around `target`: sources in amber, destinations in cyan.
func set_trace(target, up: Array, down: Array) -> void:
	var entries := []
	if target != null:
		entries.append([target, Color(1, 1, 1, 0.35)])
	for id in up:
		var b = world.buildings.get(id)
		if b != null:
			entries.append([b, Color(1.0, 0.6, 0.15, 0.4)])
	for id in down:
		var b = world.buildings.get(id)
		if b != null:
			entries.append([b, Color(0.3, 0.85, 1.0, 0.4)])
	var mm := _ensure(trace_mm, entries.size())
	for i in entries.size():
		var b = entries[i][0]
		var basis := Basis().scaled(Vector3(b.size.x * 0.96, 0.12, b.size.y * 0.96))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(b.center().x, 0.08, b.center().y)))
		mm.set_instance_color(i, entries[i][1])


func _burst(p: Vector2, c: Color, n: int, r: float, life: float) -> void:
	fx.append({"k": "burst", "p": _v3(p, 0.3), "c": c, "n": n, "r": r, "t": 0.0, "life": life, "seed": randi()})


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


func _process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	_update_lighting(delta)
	if world.ghosts_version != _ghosts_ver:
		_rebuild_ghosts()
	if world.power.version != _power_ver:
		_rebuild_wires()
	if world.ore_version != _ore_ver:
		_rebuild_ore()
	if world.structures_version != _belt_ver:
		_update_belt_shapes()
	_update_fog()
	_update_buildings(delta)
	_update_items()
	_update_enemies()
	_update_bars()
	_update_fx(delta)
	_update_debug()
	ground_mat.set_shader_parameter("grid_alpha", 1.0 if show_grid else 0.0)
	ash.position = Vector3(camera_focus.x, 14, camera_focus.z)
	_marker.visible = objective_target != null
	if _marker.visible:
		_marker.position = Vector3(objective_target.x, 0.0, objective_target.y)
		var bob := absf(sin(_t * 3.0)) * 0.5
		for part in ["Arrow", "Shaft"]:
			_marker.get_node(part).position.y = (2.6 if part == "Arrow" else 3.35) + bob
		_marker.get_node("Ring").scale = Vector3.ONE * (0.8 + 0.25 * sin(_t * 3.0))


func _update_lighting(delta: float) -> void:
	var night: float = world.waves.night
	_alarm = maxf(_alarm - delta, 0.0)
	sun.light_energy = lerpf(1.0, 0.38, night)
	sun.light_color = Color(1.0, 0.86, 0.7).lerp(Color(0.55, 0.6, 0.85), night)
	env.ambient_light_energy = lerpf(0.5, 0.32, night)
	env.fog_light_color = Color(0.32, 0.29, 0.26).lerp(Color(0.1, 0.08, 0.1), night)
	env.background_color = Color(0.05, 0.045, 0.04).lerp(Color(0.02, 0.015, 0.02), night)
	var core_h = nodes.get(world.core_id)
	if core_h != null and core_h.has("omni"):
		var pulse := 0.5 + 0.5 * sin(_t * 9.0)
		core_h.omni.light_color = Meshes.WARM.lerp(Color(1, 0.1, 0.05), clampf(_alarm, 0, 1) * pulse + night * 0.3)
		core_h.omni.light_energy = lerpf(2.2, 3.2, night)


## Curves and dead-end caps depend on neighbours, so they are refreshed whenever
## the layout changes.
func _update_belt_shapes() -> void:
	_belt_ver = world.structures_version
	for b in world.list("belt"):
		var h = nodes.get(b.id)
		if h == null or not h.has("belt_mi"):
			continue
		var shape: int = Logistics.belt_shape(world, b)
		if shape != h.shape:
			h.shape = shape
			h.belt_mi.mesh = Meshes.belt_mesh(shape)
		h.endcap.visible = Logistics.belt_dead_end(world, b)


func _update_buildings(delta: float) -> void:
	for id in nodes:
		var h: Dictionary = nodes[id]
		var b = world.buildings.get(id)
		if b == null:
			continue
		if b.kind == "belt":
			var st := 2 if b.status == "saída bloqueada" else (1 if not b.belt_items.is_empty() else 0)
			if st != h.bstate:
				h.bstate = st
				h.belt_mi.set_surface_override_material(1, Meshes.belt_material([0.35, 1.0, 0.0][st], st == 2))
			continue
		var lvl: int = b.status_level()
		if h.light != null and lvl != h.level:
			h.level = lvl
			h.light.material_override = Meshes.status_mat(lvl)
		var working: bool = lvl == 0 and b.status != "" and b.status != "vigiando" and b.status != "pronta"
		if h.glow != null:
			match b.kind:
				"battery":
					h.glow.visible = b.energy > float(b.def.battery_capacity) * 0.05
				"lab":
					h.glow.visible = b.status == "pesquisando" or fmod(_t, 1.2) < 0.2
				"turret_tesla":
					h.glow.visible = b.energy >= float(b.def.shot_cost) * 0.99 or fmod(_t, 0.3) < 0.15 * b.energy / float(b.def.shot_cost)
				"core", "genesis":
					h.glow.visible = true
				_:
					h.glow.visible = working
		if h.has("smoke"):
			h.smoke.emitting = working
		if h.spin != null and working:
			h.spin.rotation.y += delta * (6.0 if b.kind == "miner" else (1.0 + 6.0 * b.progress if b.kind == "genesis" else 2.5))
		if h.head != null:
			h.head.rotation.y = lerp_angle(h.head.rotation.y, -b.aim, minf(delta * 12.0, 1.0))
		# Damage flicker
		if world.time - b.last_damaged < 0.12:
			h.root.position.y = 0.04 * sin(_t * 80.0)
		elif h.root.position.y != 0.0:
			h.root.position.y = 0.0


func _ensure(mi: MultiMeshInstance3D, n: int) -> MultiMesh:
	var mm := mi.multimesh
	if mm.instance_count < n:
		mm.instance_count = maxi(n, mm.instance_count * 2)
	mm.visible_instance_count = n
	return mm


func _update_items() -> void:
	var belts: Array = world.list("belt")
	var n := 0
	for b in belts:
		n += b.belt_items.size()
	var mm := _ensure(items_mm, n)
	var k := 0
	for b in belts:
		var fwd := Vector2(Defs.dir_vec(b.rot))
		var right := Vector2(Defs.dir_vec(b.rot + 1))
		var h = nodes.get(b.id)
		var shape: int = h.shape if h != null and h.has("shape") else 0
		for it in b.belt_items:
			var lp: Vector2 = Meshes.belt_point(shape, float(it[1]))
			var wp := Vector2(b.pos.x + 0.5, b.pos.y + 0.5) + fwd * lp.x + right * lp.y
			var p := Vector3(wp.x, 0.17, wp.y)
			mm.set_instance_transform(k, Transform3D(Basis(), p))
			mm.set_instance_color(k, world.data.item_color(it[0]))
			k += 1


func _update_enemies() -> void:
	var by_type := {}
	for t in enemy_mm:
		by_type[t] = []
	for e in world.enemies.values():
		if by_type.has(e.type):
			by_type[e.type].append(e)
	for t in by_type:
		var list: Array = by_type[t]
		var mm := _ensure(enemy_mm[t], list.size())
		var def: Dictionary = world.data.enemies[t]
		var model: bool = enemy_mm[t].has_meta("model")
		# Creature models carry their own colours; the type colour only tints them.
		var base := Color.WHITE.lerp(Color.html(def.color), 0.3) if model else Color.html(def.color)
		for i in list.size():
			var e = list[i]
			var s: float = float(def.size) * e.size_mult
			var bob := absf(sin(_t * float(def.speed) * 5.0 + e.id)) * 0.08 * s
			var basis := Basis(Vector3.UP, -e.facing).scaled(Vector3(s * 1.15, s, s))
			var y := s * 0.4 + bob
			if model:
				# Waddle: a little roll from side to side in step with the bob.
				basis = Basis(Vector3.UP, -e.facing) * Basis(Vector3(1, 0, 0), sin(_t * float(def.speed) * 5.0 + e.id) * 0.12)
				basis = basis.scaled(Vector3.ONE * (s * 1.5 + 0.25))
				y = bob
			if def.get("flying", false):
				y = 1.9 + sin(_t * 2.0 + e.id) * 0.15
				basis = basis * Basis(Vector3(1, 0, 0), sin(_t * 6.0 + e.id) * 0.25)
			mm.set_instance_transform(i, Transform3D(basis, Vector3(e.pos.x, y, e.pos.y)))
			var col := base
			if e.elite:
				col = base.lerp(Color(0.9, 0.15, 0.05), 0.5 + 0.2 * sin(_t * 6.0))
			if world.time - e.hit_time < 0.08:
				col = Color(1.6, 1.4, 1.2)
			mm.set_instance_color(i, col)


func _update_bars() -> void:
	var entries := []
	for b in world.buildings.values():
		if b.hp < b.max_hp:
			entries.append([b.center(), b.hp / b.max_hp, float(nodes.get(b.id, {"h": 1.0}).h) + 0.35, float(b.size.x) * 0.8])
	for i in world.spawn_points.size():
		if i < world.nests.hp.size() and world.nests.hp[i] < world.nests.max_hp:
			entries.append([Vector2(world.spawn_points[i]) + Vector2(0.5, 0.5), world.nests.hp[i] / world.nests.max_hp, 2.2, 3.0])
	for e in world.enemies.values():
		if e.hp < e.max_hp:
			var s: float = float(e.def.size) * e.size_mult
			var hy := 2.4 if e.def.get("flying", false) else s * 1.2 + 0.3
			entries.append([e.pos, e.hp / e.max_hp, hy, maxf(s * 1.4, 0.5)])
	var mm := _ensure(bars_mm, entries.size())
	for i in entries.size():
		var en: Array = entries[i]
		var r: float = clampf(en[1], 0.0, 1.0)
		var wdt: float = en[3]
		var basis := Basis().scaled(Vector3(maxf(wdt * r, 0.02), 1, 1))
		var p := Vector3(en[0].x - wdt * (1.0 - r) * 0.5, en[2], en[0].y)
		mm.set_instance_transform(i, Transform3D(basis, p))
		mm.set_instance_color(i, Color(1.0, 0.2, 0.1).lerp(Color(0.4, 1.0, 0.3), r))


func _update_fx(delta: float) -> void:
	fx_mesh.clear_surfaces()
	var alive := []
	for f in fx:
		f.t += delta
		if f.t < f.life:
			alive.append(f)
	fx = alive
	if fx.is_empty():
		return
	fx_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for f in fx:
		var a: float = 1.0 - f.t / f.life
		var c: Color = f.c * (1.0 + a)
		c.a = a
		match f.k:
			"line":
				fx_mesh.surface_set_color(c)
				fx_mesh.surface_add_vertex(f.a)
				fx_mesh.surface_add_vertex(f.b)
			"arc":
				var rng := RandomNumberGenerator.new()
				rng.seed = f.seed + int(f.t * 40.0)
				var pts: Array = f.pts
				for i in pts.size() - 1:
					var p0 := _v3(pts[i], 2.1 if i == 0 else 0.4)
					var p1 := _v3(pts[i + 1], 0.4)
					var prev := p0
					for s in range(1, 7):
						var q := p0.lerp(p1, s / 6.0)
						if s < 6:
							q += Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.25, 0.25))
						fx_mesh.surface_set_color(c)
						fx_mesh.surface_add_vertex(prev)
						fx_mesh.surface_add_vertex(q)
						prev = q
			"drone":
				# A small drone flies an arc from the hub to the repair target.
				var s: float = f.t / f.life
				var p: Vector3 = f.a.lerp(f.b, s) + Vector3(0, sin(s * PI) * 2.2, 0)
				var q: Vector3 = f.a.lerp(f.b, maxf(s - 0.12, 0.0)) + Vector3(0, sin(maxf(s - 0.12, 0.0) * PI) * 2.2, 0)
				var dc: Color = f.c * 1.6
				fx_mesh.surface_set_color(Color(dc, 0.5))
				fx_mesh.surface_add_vertex(q)
				fx_mesh.surface_add_vertex(p)
				fx_mesh.surface_set_color(dc)
				for d in [Vector3(0.2, 0, 0.2), Vector3(0.2, 0, -0.2)]:
					fx_mesh.surface_add_vertex(p - d)
					fx_mesh.surface_add_vertex(p + d)
			"burst":
				var rng := RandomNumberGenerator.new()
				rng.seed = f.seed
				var grow: float = f.t / f.life
				for i in int(f.n):
					var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.2), rng.randf_range(-1, 1)).normalized()
					var r0: float = f.r * grow * 0.4
					var r1: float = f.r * grow
					fx_mesh.surface_set_color(c)
					fx_mesh.surface_add_vertex(f.p + dir * r0)
					fx_mesh.surface_add_vertex(f.p + dir * r1)
	fx_mesh.surface_end()


func _rebuild_ghosts() -> void:
	_ghosts_ver = world.ghosts_version
	for c in ghosts_root.get_children():
		c.queue_free()
	var m := Meshes.mat("ghost", Color(1.0, 0.3, 0.15, 0.22), {"alpha": true, "unshaded": true})
	for key in world.ghosts:
		var g: Dictionary = world.ghosts[key]
		var def: Dictionary = world.data.buildings[g.type]
		var h := Meshes.build(g.type, def, int(g.rot))
		Meshes.override_all(h.root, m)
		h.root.position = Vector3(int(g.x), 0, int(g.y))
		ghosts_root.add_child(h.root)


func _rebuild_wires() -> void:
	_power_ver = world.power.version
	wires_mesh.clear_surfaces()
	if world.power.links.is_empty():
		return
	wires_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for l in world.power.links:
		var a = world.buildings.get(l[0])
		var b = world.buildings.get(l[1])
		if a == null or b == null:
			continue
		var pa := _v3(a.center(), 1.9 if a.kind == "pole" else 3.0)
		var pb := _v3(b.center(), 1.9 if b.kind == "pole" else 3.0)
		var prev := pa
		for s in range(1, 9):
			var t := s / 8.0
			var q := pa.lerp(pb, t) - Vector3(0, sin(t * PI) * 0.35, 0)
			wires_mesh.surface_set_color(Color(0.08, 0.08, 0.08))
			wires_mesh.surface_add_vertex(prev)
			wires_mesh.surface_add_vertex(q)
			prev = q
	wires_mesh.surface_end()


## F3 overlay: flow-field routes, power networks and enemy targets.
func _update_debug() -> void:
	if not debug:
		if _debug_ver != -1:
			debug_mesh.clear_surfaces()
			_debug_ver = -1
		return
	debug_mesh.clear_surfaces()
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var pf = world.pathing
	if not pf.dist.is_empty():
		var w: int = world.width
		for y in range(0, world.height):
			for x in range(0, w):
				var c := Vector2i(x, y)
				if world.terrain[y * w + x] == Defs.T_ROCK or world.grid[y * w + x] != 0:
					continue
				var n: Vector2i = pf.next_cell(0, c)
				if n.x < 0:
					continue
				var a := Vector3(x + 0.5, 0.05, y + 0.5)
				var b := Vector3(n.x + 0.5, 0.05, n.y + 0.5)
				debug_mesh.surface_set_color(Color(0.9, 0.3, 0.3, 0.6))
				debug_mesh.surface_add_vertex(a)
				debug_mesh.surface_add_vertex(a.lerp(b, 0.45))
	var palette := [Color(0.3, 0.8, 1), Color(1, 0.8, 0.2), Color(0.6, 1, 0.4), Color(1, 0.4, 0.9), Color(1, 1, 1)]
	for net in world.power.networks:
		var col: Color = palette[net.id % palette.size()]
		for b in net.members:
			for nd in net.nodes:
				if world.power.covers(nd, b) and nd != b:
					debug_mesh.surface_set_color(col)
					debug_mesh.surface_add_vertex(_v3(nd.center(), 0.2))
					debug_mesh.surface_add_vertex(_v3(b.center(), 0.2))
					break
	for e in world.enemies.values():
		var t = world.buildings.get(e.target)
		if t != null:
			debug_mesh.surface_set_color(Color(1, 0.1, 0.1))
			debug_mesh.surface_add_vertex(_v3(e.pos, 0.6))
			debug_mesh.surface_add_vertex(_v3(t.center(), 0.6))
	for b in world.list("turret_gun") + world.list("turret_tesla"):
		var e = world.enemies.get(b.target)
		if e != null:
			debug_mesh.surface_set_color(Color(1, 1, 0.3))
			debug_mesh.surface_add_vertex(_v3(b.center(), 1.0))
			debug_mesh.surface_add_vertex(_v3(e.pos, 0.4))
	# Always emit at least one vertex pair so the surface is valid.
	debug_mesh.surface_set_color(Color(0, 0, 0, 0))
	debug_mesh.surface_add_vertex(Vector3.ZERO)
	debug_mesh.surface_add_vertex(Vector3.ZERO)
	debug_mesh.surface_end()
	_debug_ver = 1
