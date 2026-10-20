extends RefCounted
## Models for every structure. Bodies come from the Kenney kits when available
## (see _kit_body and kit.gd); primitives are the fallback and are still used for
## belts, walls, poles and splitters, which must stay cheap and tile cleanly.
## Models are authored facing +X in local space and rotated by the view.

const CONCRETE := Color(0.34, 0.33, 0.31)
const CONCRETE_DARK := Color(0.22, 0.215, 0.205)
const METAL := Color(0.38, 0.39, 0.40)
const METAL_DARK := Color(0.16, 0.16, 0.17)
const RUST := Color(0.42, 0.21, 0.11)
const BRICK := Color(0.33, 0.19, 0.14)
const HAZARD := Color(0.72, 0.55, 0.14)
const WARM := Color(1.0, 0.52, 0.16)
const CYAN := Color(0.35, 0.85, 1.0)
const GREEN := Color(0.35, 1.0, 0.45)
const RED := Color(1.0, 0.16, 0.10)

const STATUS_COLORS := [Color(0.35, 1.0, 0.4), Color(1.0, 0.72, 0.15), Color(1.0, 0.15, 0.1)]

const BeltShader = preload("res://src/view/belt.gdshader")
const Kit = preload("res://src/view/kit.gd")
const BELT_HW := 0.4        ## half width of the moving surface

static var _mats := {}
static var _meshes := {}


static func mat(key: String, color: Color, opts: Dictionary = {}) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = float(opts.get("rough", 0.85))
	m.metallic = float(opts.get("metal", 0.15))
	if opts.has("emit"):
		m.emission_enabled = true
		m.emission = opts.emit
		m.emission_energy_multiplier = float(opts.get("energy", 2.5))
	if opts.get("alpha", false):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if opts.get("unshaded", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if opts.get("vcol", false):
		m.vertex_color_use_as_albedo = true
	if opts.get("noshadow", false):
		m.disable_receive_shadows = true
	_mats[key] = m
	return m


static func status_mat(level: int) -> StandardMaterial3D:
	var c: Color = STATUS_COLORS[clampi(level, 0, 2)]
	return mat("status%d" % level, c, {"emit": c, "energy": 3.0, "unshaded": true})


static func _mesh(key: String, maker: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = maker.call()
	return _meshes[key]


static func box_mesh(s: Vector3) -> Mesh:
	return _mesh("box%s" % s, func():
		var m := BoxMesh.new()
		m.size = s
		return m)


static func cyl_mesh(r_top: float, r_bot: float, h: float, sides: int = 12) -> Mesh:
	return _mesh("cyl%s_%s_%s_%d" % [r_top, r_bot, h, sides], func():
		var m := CylinderMesh.new()
		m.top_radius = r_top
		m.bottom_radius = r_bot
		m.height = h
		m.radial_segments = sides
		m.rings = 1
		return m)


static func sphere_mesh(r: float, h: float = -1.0) -> Mesh:
	return _mesh("sph%s_%s" % [r, h], func():
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0 if h < 0.0 else h
		m.radial_segments = 12
		m.rings = 6
		return m)


static func add(parent: Node3D, mesh: Mesh, p: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = p
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, s: Vector3, p: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return add(parent, box_mesh(s), p, m, rot)


static func cyl(parent: Node3D, r: float, h: float, p: Vector3, m: Material, r_bot: float = -1.0, sides: int = 12) -> MeshInstance3D:
	return add(parent, cyl_mesh(r, r if r_bot < 0.0 else r_bot, h, sides), p, m)


## Builds the visual for a building type. Returns handles used for animation:
## {root, body, head, glow, spin, light, h}
static func build(type: String, def: Dictionary, rot: int) -> Dictionary:
	var root := Node3D.new()
	var s: Array = def.get("size", [1, 1])
	var w := float(s[0])
	var d := float(s[1])
	var fp := Vector2(w, d) if rot % 2 == 0 else Vector2(d, w)
	var body := Node3D.new()
	body.position = Vector3(fp.x * 0.5, 0, fp.y * 0.5)
	body.rotation.y = -rot * PI * 0.5
	root.add_child(body)
	var h := {"root": root, "body": body, "head": null, "glow": null, "spin": null, "h": 1.0}
	var concrete := mat("concrete", CONCRETE)
	var cdark := mat("cdark", CONCRETE_DARK)
	var metal := mat("metal", METAL, {"metal": 0.6, "rough": 0.55})
	var mdark := mat("mdark", METAL_DARK, {"metal": 0.5, "rough": 0.6})
	var rust := mat("rust", RUST, {"rough": 0.95})
	var hazard := mat("hazard", HAZARD)
	var warm := mat("warm", WARM, {"emit": WARM, "energy": 3.0})
	var cyan := mat("cyan", CYAN, {"emit": CYAN, "energy": 3.0})
	var shape: String = type if type in ["turret_cannon", "turret_aa"] else str(def.get("kind", type))
	if not _kit_body(shape, type, root, body, h):
		match shape:
			"core":
				box(body, Vector3(2.9, 0.5, 2.9), Vector3(0, 0.25, 0), cdark)
				box(body, Vector3(2.3, 0.8, 2.3), Vector3(0, 0.9, 0), concrete)
				for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
					box(body, Vector3(0.35, 1.5, 0.35), Vector3(c.x * 1.2, 0.75, c.y * 1.2), rust)
				cyl(body, 0.5, 1.6, Vector3(0, 2.0, 0), metal, 0.65)
				h.glow = cyl(body, 0.58, 0.14, Vector3(0, 2.4, 0), warm)
				cyl(body, 0.25, 0.6, Vector3(0, 3.1, 0), mdark)
				var light := OmniLight3D.new()
				light.light_color = WARM
				light.light_energy = 2.2
				light.omni_range = 10.0
				light.position = Vector3(0, 3.2, 0)
				body.add_child(light)
				h["omni"] = light
				h.h = 3.4
			"belt":
				var mi := MeshInstance3D.new()
				mi.mesh = belt_mesh(0)
				body.add_child(mi)
				h["belt_mi"] = mi
				h["shape"] = 0
				h["bstate"] = -1
				# Red end cap shown when the belt leads nowhere.
				var cap := box(body, Vector3(0.07, 0.2, 0.86), Vector3(0.46, 0.12, 0), mat("deadend", RED, {"emit": RED, "energy": 2.0}))
				cap.visible = false
				h["endcap"] = cap
				h.h = 0.3
			"miner":
				box(body, Vector3(1.9, 0.45, 1.9), Vector3(0, 0.225, 0), rust)
				box(body, Vector3(1.2, 0.7, 1.2), Vector3(-0.15, 0.8, 0), mdark)
				var spin := Node3D.new()
				spin.position = Vector3(-0.15, 0.6, 0)
				body.add_child(spin)
				cyl(spin, 0.18, 1.5, Vector3(0, 0.4, 0), metal, 0.05)
				box(spin, Vector3(0.7, 0.12, 0.12), Vector3(0, 1.0, 0), hazard)
				h.spin = spin
				box(body, Vector3(0.45, 0.3, 0.5), Vector3(0.8, 0.35, 0), hazard)
				h.glow = box(body, Vector3(0.06, 0.12, 0.5), Vector3(0.47, 0.95, 0), warm)
				h.h = 1.9
			"crafter":
				if type == "smelter":
					box(body, Vector3(1.9, 0.95, 1.9), Vector3(0, 0.475, 0), mat("brick", BRICK))
					cyl(body, 0.22, 1.7, Vector3(-0.5, 1.6, -0.5), mdark, 0.3)
					box(body, Vector3(1.4, 0.15, 1.4), Vector3(0, 1.02, 0), cdark)
					h.glow = box(body, Vector3(0.06, 0.35, 0.9), Vector3(0.96, 0.45, 0), warm)
					h.h = 2.4
				else:
					box(body, Vector3(1.9, 0.6, 1.9), Vector3(0, 0.3, 0), metal)
					box(body, Vector3(1.3, 0.45, 1.3), Vector3(-0.15, 0.82, 0), mdark)
					var spin := Node3D.new()
					spin.position = Vector3(0.35, 1.05, 0.35)
					body.add_child(spin)
					box(spin, Vector3(0.8, 0.1, 0.12), Vector3(0.3, 0.1, 0), hazard)
					h.spin = spin
					h.glow = box(body, Vector3(1.32, 0.05, 0.1), Vector3(-0.15, 0.62, 0.66), cyan)
					h.h = 1.4
				box(body, Vector3(0.12, 0.2, 0.4), Vector3(0.98, 0.15, 0), hazard)
			"generator":
				box(body, Vector3(1.9, 0.45, 1.9), Vector3(0, 0.225, 0), cdark)
				for z in [-0.45, 0.45]:
					var t := cyl(body, 0.38, 1.4, Vector3(-0.2, 0.75, z), rust)
					t.rotation.z = PI * 0.5
				cyl(body, 0.12, 1.4, Vector3(0.6, 1.1, -0.6), mdark, 0.16)
				h.glow = box(body, Vector3(0.5, 0.25, 0.06), Vector3(0.55, 0.5, 0.96), warm)
				h.h = 1.6
			"pole":
				cyl(body, 0.06, 2.0, Vector3(0, 1.0, 0), mat("wood", Color(0.22, 0.17, 0.12)), 0.09, 6)
				box(body, Vector3(0.7, 0.07, 0.07), Vector3(0, 1.85, 0), mdark)
				for x in [-0.3, 0.3]:
					add(body, sphere_mesh(0.06), Vector3(x, 1.93, 0), cyan)
				h.h = 2.1
			"battery":
				box(body, Vector3(1.8, 0.8, 1.8), Vector3(0, 0.4, 0), mdark)
				for z in [-0.5, 0.0, 0.5]:
					box(body, Vector3(1.4, 0.06, 0.18), Vector3(0, 0.83, z), metal)
				h.glow = box(body, Vector3(1.82, 0.08, 0.3), Vector3(0, 0.55, 0), cyan)
				h.h = 1.1
			"turret_gun":
				cyl(body, 0.85, 0.45, Vector3(0, 0.225, 0), concrete, 0.95, 8)
				box(body, Vector3(1.9, 0.1, 0.25), Vector3(0, 0.05, 0.8), hazard)
				var head := Node3D.new()
				head.position = body.position + Vector3(0, 0.45, 0)
				root.add_child(head)
				cyl(head, 0.3, 0.2, Vector3(0, 0.1, 0), mdark)
				box(head, Vector3(0.75, 0.42, 0.65), Vector3(0, 0.4, 0), metal)
				var barrel := cyl(head, 0.07, 1.0, Vector3(0.75, 0.45, 0.13), mdark)
				barrel.rotation.z = PI * 0.5
				var barrel2 := cyl(head, 0.07, 1.0, Vector3(0.75, 0.45, -0.13), mdark)
				barrel2.rotation.z = PI * 0.5
				box(head, Vector3(0.2, 0.18, 0.66), Vector3(-0.42, 0.4, 0), hazard)
				h.head = head
				h.h = 1.3
			"turret_cannon":
				cyl(body, 0.95, 0.5, Vector3(0, 0.25, 0), concrete, 1.0, 8)
				box(body, Vector3(1.9, 0.1, 0.25), Vector3(0, 0.05, -0.8), hazard)
				var head := Node3D.new()
				head.position = body.position + Vector3(0, 0.5, 0)
				root.add_child(head)
				box(head, Vector3(1.0, 0.55, 0.85), Vector3(-0.1, 0.35, 0), rust)
				var barrel := cyl(head, 0.16, 1.3, Vector3(0.9, 0.45, 0), mdark, 0.2)
				barrel.rotation.z = PI * 0.5
				box(head, Vector3(0.3, 0.3, 0.9), Vector3(-0.6, 0.35, 0), mdark)
				h.head = head
				h.h = 1.4
			"turret_aa":
				cyl(body, 0.8, 0.35, Vector3(0, 0.175, 0), concrete, 0.9, 8)
				var head := Node3D.new()
				head.position = body.position + Vector3(0, 0.35, 0)
				root.add_child(head)
				cyl(head, 0.35, 0.4, Vector3(0, 0.2, 0), mdark)
				for z in [-0.18, 0.18]:
					var b2 := cyl(head, 0.05, 1.4, Vector3(0.45, 0.85, z), metal)
					b2.rotation.z = deg_to_rad(-55)
				box(head, Vector3(0.5, 0.35, 0.6), Vector3(-0.1, 0.55, 0), mat("aared", Color(0.45, 0.16, 0.12)))
				h.head = head
				h.h = 1.6
			"lab":
				box(body, Vector3(1.9, 0.5, 1.9), Vector3(0, 0.25, 0), cdark)
				add(body, sphere_mesh(0.75, 0.9), Vector3(0, 0.55, 0), metal)
				cyl(body, 0.04, 1.2, Vector3(0.6, 1.0, 0.6), mdark, -1.0, 5)
				h.glow = add(body, sphere_mesh(0.18), Vector3(0, 1.05, 0), cyan)
				var spin := Node3D.new()
				spin.position = Vector3(0.6, 1.6, 0.6)
				body.add_child(spin)
				box(spin, Vector3(0.5, 0.04, 0.04), Vector3.ZERO, cyan)
				h.spin = spin
				h.h = 1.8
			"solar":
				box(body, Vector3(1.6, 0.3, 0.2), Vector3(0, 0.15, 0), mdark)
				var panel := box(body, Vector3(1.85, 0.05, 1.7), Vector3(0, 0.55, 0), mat("solar", Color(0.08, 0.12, 0.22), {"metal": 0.7, "rough": 0.25}))
				panel.rotation.x = deg_to_rad(18)
				for x in [-0.45, 0.0, 0.45]:
					box(body, Vector3(0.02, 0.06, 1.7), Vector3(x, 0.58, 0), metal, Vector3(deg_to_rad(18), 0, 0))
				h.h = 1.0
			"turret_tesla":
				cyl(body, 0.8, 0.4, Vector3(0, 0.2, 0), concrete, 0.9, 8)
				cyl(body, 0.32, 0.5, Vector3(0, 0.65, 0), mdark, 0.4)
				for i in 4:
					cyl(body, 0.26 - i * 0.03, 0.08, Vector3(0, 1.0 + i * 0.28, 0), metal)
				cyl(body, 0.09, 1.2, Vector3(0, 1.4, 0), mdark)
				h.glow = add(body, sphere_mesh(0.28), Vector3(0, 2.15, 0), cyan)
				h.h = 2.5
			"wall":
				box(body, Vector3(1.0, 1.1, 1.0), Vector3(0, 0.55, 0), concrete)
				box(body, Vector3(1.02, 0.12, 1.02), Vector3(0, 0.2, 0), cdark)
				for x in [-0.3, 0.1, 0.35]:
					box(body, Vector3(0.04, 0.3, 0.04), Vector3(x, 1.25, x * 0.5), rust)
				h.h = 1.4
			"repair":
				box(body, Vector3(1.9, 0.45, 1.9), Vector3(0, 0.225, 0), cdark)
				box(body, Vector3(1.0, 0.5, 1.0), Vector3(0, 0.7, 0), metal)
				var gm := mat("greenl", GREEN, {"emit": GREEN, "energy": 2.5})
				h.glow = box(body, Vector3(0.7, 0.06, 0.2), Vector3(0, 0.98, 0), gm)
				box(body, Vector3(0.2, 0.06, 0.7), Vector3(0, 0.98, 0), gm)
				var spin := Node3D.new()
				spin.position = Vector3(0, 1.0, 0)
				body.add_child(spin)
				box(spin, Vector3(1.4, 0.07, 0.07), Vector3(0, 0.15, 0), hazard)
				h.spin = spin
				h.h = 1.4
			"depot":
				box(body, Vector3(1.9, 0.25, 1.9), Vector3(0, 0.125, 0), cdark)
				var crate := mat("crate", Color(0.4, 0.3, 0.16))
				box(body, Vector3(0.8, 0.6, 0.8), Vector3(-0.45, 0.55, -0.45), crate)
				box(body, Vector3(0.8, 0.5, 0.8), Vector3(0.45, 0.5, -0.4), rust)
				box(body, Vector3(0.8, 0.7, 0.8), Vector3(-0.4, 0.6, 0.45), crate)
				box(body, Vector3(0.12, 0.2, 0.4), Vector3(0.98, 0.15, 0), hazard)
				h.h = 1.2
			"splitter":
				box(body, Vector3(0.9, 0.3, 0.9), Vector3(0, 0.15, 0), hazard)
				for a in [-PI * 0.5, 0.0, PI * 0.5]:
					box(body, Vector3(0.35, 0.04, 0.08), Vector3(cos(a) * 0.22, 0.32, -sin(a) * 0.22), mdark, Vector3(0, a, 0))
				h.h = 0.5
			_:
				box(body, Vector3(w * 0.9, 0.6, d * 0.9), Vector3(0, 0.3, 0), metal)
	if def.get("kind", type) in ["miner", "crafter", "depot"]:
		# Output side: a glowing yellow strip along the whole front face plus an arrow
		# on the ground in front of every front tile (items may leave through any).
		var am := mat("outarrow", HAZARD, {"emit": HAZARD, "energy": 2.2})
		box(body, Vector3(0.08, 0.16, d * 0.92), Vector3(w * 0.5 + 0.02, 0.3, 0), am)
		box(body, Vector3(0.05, 0.05, d * 0.92), Vector3(w * 0.5 + 0.03, 0.04, 0), am)
		for i in int(d):
			var arrow := Node3D.new()
			arrow.position = Vector3(w * 0.5 + 0.28, 0.02, -d * 0.5 + 0.5 + i)
			body.add_child(arrow)
			box(arrow, Vector3(0.26, 0.025, 0.07), Vector3(0.0, 0, -0.07), am, Vector3(0, deg_to_rad(-38), 0))
			box(arrow, Vector3(0.26, 0.025, 0.07), Vector3(0.0, 0, 0.07), am, Vector3(0, deg_to_rad(38), 0))
	if def.get("kind", type) not in ["belt", "wall", "pole"]:
		# Status lamp on a short post at the footprint corner.
		cyl(root, 0.025, 0.7, Vector3(0.14, 0.35, 0.14), mdark, -1.0, 5)
		h.light = add(root, sphere_mesh(0.085), Vector3(0.14, 0.74, 0.14), status_mat(0))
	else:
		h.light = null
	_shadows(root)
	return h


## Structure bodies assembled from the Kenney kits (assets/models). Gameplay
## affordances stay procedural on top: glow strips, status lamp, output arrows,
## spinning parts and the turret head pivot. Returns false when the kits are not
## available (or the shape has no kit version) so build() uses primitives.
static func _kit_body(shape: String, type: String, root: Node3D, body: Node3D, h: Dictionary) -> bool:
	if not Kit.has("factory/machine"):
		return false
	const Q := PI * 0.5          # Kenney models face +Z; ours face +X
	var cdark := mat("cdark", CONCRETE_DARK)
	var mdark := mat("mdark", METAL_DARK, {"metal": 0.5, "rough": 0.6})
	var hazard := mat("hazard", HAZARD)
	var warm := mat("warm", WARM, {"emit": WARM, "energy": 3.0})
	var cyan := mat("cyan", CYAN, {"emit": CYAN, "energy": 3.0})
	match shape:
		"core":
			box(body, Vector3(2.9, 0.3, 2.9), Vector3(0, 0.15, 0), cdark)
			Kit.place(body, "city/building-c", Vector3(0, 0.3, 0), Vector3(2.7, 1.5, 2.7), Q)
			Kit.place(body, "city/chimney-small", Vector3(-1.15, 0.3, -1.15), Vector3(0.35, 0, 0.35))
			Kit.place(body, "city/chimney-small", Vector3(-1.15, 0.3, 1.15), Vector3(0.35, 0, 0.35))
			cyl(body, 0.42, 1.2, Vector3(0, 2.1, 0), mat("metal", METAL, {"metal": 0.6, "rough": 0.55}), 0.55)
			h.glow = cyl(body, 0.5, 0.14, Vector3(0, 2.45, 0), warm)
			cyl(body, 0.22, 0.6, Vector3(0, 3.0, 0), mdark)
			var light := OmniLight3D.new()
			light.light_color = WARM
			light.light_energy = 2.2
			light.omni_range = 10.0
			light.position = Vector3(0, 3.2, 0)
			body.add_child(light)
			h["omni"] = light
			h.h = 3.4
		"miner":
			box(body, Vector3(1.9, 0.25, 1.9), Vector3(0, 0.125, 0), mat("rust", RUST, {"rough": 0.95}))
			Kit.place(body, "factory/hopper-high-square", Vector3(-0.35, 0.25, 0), Vector3(1.15, 1.5, 1.15), Q)
			var spin := Node3D.new()
			spin.position = Vector3(0.45, 0.25, -0.5)
			body.add_child(spin)
			Kit.place(spin, "factory/cog-a", Vector3(0, 0.12, 0), Vector3(0.7, 0, 0.7))
			cyl(spin, 0.08, 0.9, Vector3(0, 0.45, 0), mdark, 0.03)
			h.spin = spin
			h.glow = box(body, Vector3(0.06, 0.12, 0.5), Vector3(0.6, 0.95, 0.35), warm)
			h.h = 1.9
		"crafter":
			box(body, Vector3(1.95, 0.12, 1.95), Vector3(0, 0.06, 0), cdark)
			if type == "smelter":
				Kit.place(body, "factory/machine-fortified", Vector3(0.1, 0.12, 0.2), Vector3(1.5, 1.4, 1.5), Q)
				Kit.place(body, "city/chimney-large", Vector3(-0.55, 0.12, -0.55), Vector3(0.75, 1.9, 0.75))
				h.glow = box(body, Vector3(0.06, 0.3, 0.8), Vector3(0.9, 0.42, 0.2), warm)
				h.h = 2.1
			else:
				Kit.place(body, "factory/machine-window", Vector3(0.15, 0.12, 0.15), Vector3(1.5, 1.25, 1.5), Q)
				Kit.place(body, "factory/robot-arm-a", Vector3(-0.6, 0.12, -0.6), Vector3(0.6, 1.5, 0.6), Q)
				h.glow = box(body, Vector3(1.0, 0.05, 0.08), Vector3(0.15, 1.3, 0.9), cyan)
				h.h = 1.6
		"generator":
			box(body, Vector3(1.9, 0.2, 1.9), Vector3(0, 0.1, 0), cdark)
			Kit.place(body, "city/detail-tank-large", Vector3(-0.2, 0.2, 0.1), Vector3(1.5, 1.2, 1.6), Q)
			Kit.place(body, "city/chimney-medium", Vector3(0.6, 0.2, -0.65), Vector3(0.45, 1.7, 0.45))
			h.glow = box(body, Vector3(0.5, 0.22, 0.06), Vector3(0.45, 0.4, 0.93), warm)
			h.h = 1.9
		"battery":
			box(body, Vector3(1.9, 0.15, 1.9), Vector3(0, 0.075, 0), cdark)
			for z in [-0.45, 0.45]:
				Kit.place(body, "city/detail-tank", Vector3(0, 0.15, z), Vector3(1.7, 0.8, 0.85))
			h.glow = box(body, Vector3(1.6, 0.06, 0.12), Vector3(0, 0.95, 0), cyan)
			h.h = 1.1
		"turret_gun", "turret_cannon", "turret_aa":
			var base := {"turret_gun": "td/tower-square-bottom-a", "turret_cannon": "td/tower-square-bottom-b", "turret_aa": "td/tower-round-bottom-a"}
			var gun := {"turret_gun": "td/weapon-turret", "turret_cannon": "td/weapon-cannon", "turret_aa": "td/weapon-ballista"}
			var size := {"turret_gun": 1.05, "turret_cannon": 1.25, "turret_aa": 1.15}
			Kit.place(body, base[shape], Vector3.ZERO, Vector3(1.7, 0.5, 1.7))
			box(body, Vector3(1.9, 0.06, 0.2), Vector3(0, 0.03, 0.85), hazard)
			var head := Node3D.new()
			head.position = body.position + Vector3(0, 0.5, 0)
			root.add_child(head)
			Kit.place(head, gun[shape], Vector3.ZERO, Vector3(size[shape], 0, size[shape]), Q)
			h.head = head
			h.h = 1.4
		"turret_tesla":
			Kit.place(body, "td/tower-round-crystals", Vector3.ZERO, Vector3(1.7, 0, 1.7))
			cyl(body, 0.09, 1.1, Vector3(0, 1.3, 0), mdark)
			for i in 3:
				cyl(body, 0.22 - i * 0.04, 0.07, Vector3(0, 1.1 + i * 0.25, 0), mat("metal", METAL, {"metal": 0.6, "rough": 0.55}))
			h.glow = add(body, sphere_mesh(0.26), Vector3(0, 2.0, 0), cyan)
			h.h = 2.4
		"lab":
			box(body, Vector3(1.9, 0.15, 1.9), Vector3(0, 0.075, 0), cdark)
			Kit.place(body, "factory/hopper-round", Vector3(-0.3, 0.15, -0.25), Vector3(1.2, 1.0, 1.2))
			Kit.place(body, "factory/screen-wide", Vector3(0.6, 0.15, 0.2), Vector3(0.6, 0.9, 1.3), Q)
			h.glow = add(body, sphere_mesh(0.16), Vector3(-0.3, 1.25, -0.25), cyan)
			var spin := Node3D.new()
			spin.position = Vector3(-0.3, 1.45, -0.25)
			body.add_child(spin)
			box(spin, Vector3(0.6, 0.04, 0.04), Vector3.ZERO, cyan)
			h.spin = spin
			h.h = 1.7
		"solar":
			Kit.place(body, "city/solar-panel-landscape-group", Vector3.ZERO, Vector3(1.95, 0, 1.95), PI)
			h.h = 0.8
		"repair":
			box(body, Vector3(1.9, 0.25, 1.9), Vector3(0, 0.125, 0), cdark)
			Kit.place(body, "factory/robot-arm-b", Vector3(-0.35, 0.25, -0.35), Vector3(0.75, 1.5, 0.75), Q)
			var gm := mat("greenl", GREEN, {"emit": GREEN, "energy": 2.5})
			h.glow = box(body, Vector3(0.6, 0.06, 0.18), Vector3(0.4, 0.3, 0.4), gm)
			box(body, Vector3(0.18, 0.06, 0.6), Vector3(0.4, 0.3, 0.4), gm)
			var spin := Node3D.new()
			spin.position = Vector3(0.4, 0.4, 0.4)
			body.add_child(spin)
			box(spin, Vector3(0.9, 0.06, 0.06), Vector3.ZERO, hazard)
			h.spin = spin
			h.h = 1.6
		"depot":
			box(body, Vector3(1.9, 0.15, 1.9), Vector3(0, 0.075, 0), cdark)
			Kit.place(body, "factory/box-large", Vector3(-0.4, 0.15, -0.4), Vector3(0.95, 0.6, 0.95))
			Kit.place(body, "factory/box-wide", Vector3(0.45, 0.15, -0.4), Vector3(0.6, 0.6, 0.95))
			Kit.place(body, "city/shipping-container-a", Vector3(-0.3, 0.15, 0.45), Vector3(1.4, 0, 0.75), Q)
			Kit.place(body, "factory/box-small", Vector3(0.5, 0.15, 0.45), Vector3(0.55, 0.5, 0.5))
			h.h = 1.0
		_:
			return false
	return true


## Belt centre line in local space (exit towards +X, tile spans -0.5..0.5).
## shape 0 straight, -1 enters from the left (-Z), +1 enters from the right (+Z).
static func belt_point(shape: int, t: float) -> Vector2:
	if shape == 0:
		return Vector2(-0.5 + t, 0.0)
	var c := Vector2(0.5, 0.5 * shape)
	var a := lerpf(PI, PI * (1.0 + 0.5 * shape), t)
	return c + Vector2(cos(a), sin(a)) * 0.5


static func _belt_frame(shape: int, t: float) -> Array:
	var p := belt_point(shape, t)
	var q := belt_point(shape, clampf(t + 0.01, 0.0, 1.0))
	var tangent := (q - p).normalized() if t < 0.99 else (p - belt_point(shape, t - 0.01)).normalized()
	var normal := Vector2(-tangent.y, tangent.x)   # points to the belt's right (+Z for straight)
	return [p, normal]


## Procedural belt: base plate, moving surface (belt shader) and side rails,
## built along the straight or curved centre line. Cached per shape.
static func belt_mesh(shape: int) -> Mesh:
	return _mesh("belt%d" % shape, func():
		var segs := 1 if shape == 0 else 10
		var am := ArrayMesh.new()
		var layers := [
			[0.49, 0.035, mat("beltbase", METAL_DARK, {"metal": 0.5, "rough": 0.6})],
			[BELT_HW, 0.085, belt_material(1.0, false)],
		]
		for layer in layers:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_normal(Vector3.UP)
			for i in segs:
				var t0 := float(i) / segs
				var t1 := float(i + 1) / segs
				var f0 := _belt_frame(shape, t0)
				var f1 := _belt_frame(shape, t1)
				var hw: float = layer[0]
				var y: float = layer[1]
				var a0: Vector2 = f0[0] - f0[1] * hw
				var b0: Vector2 = f0[0] + f0[1] * hw
				var a1: Vector2 = f1[0] - f1[1] * hw
				var b1: Vector2 = f1[0] + f1[1] * hw
				# Clockwise seen from above (Godot's front-face winding).
				var verts := [[a0, 0.0, t0], [b1, 1.0, t1], [b0, 1.0, t0], [a0, 0.0, t0], [a1, 0.0, t1], [b1, 1.0, t1]]
				for v in verts:
					st.set_uv(Vector2(v[1], v[2]))
					st.add_vertex(Vector3(v[0].x, y, v[0].y))
			st.set_material(layer[2])
			st.commit(am)
		# Rails: a short wall on each side.
		var rt := SurfaceTool.new()
		rt.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0, 1.0]:
			for i in segs:
				var t0 := float(i) / segs
				var t1 := float(i + 1) / segs
				var f0 := _belt_frame(shape, t0)
				var f1 := _belt_frame(shape, t1)
				for off in [0.43, 0.48]:
					var p0: Vector2 = f0[0] + f0[1] * off * side
					var p1: Vector2 = f1[0] + f1[1] * off * side
					var n := Vector3(f0[1].x * side, 0, f0[1].y * side) * (1.0 if off > 0.45 else -1.0)
					rt.set_normal(n)
					var quad := [Vector3(p0.x, 0.0, p0.y), Vector3(p1.x, 0.0, p1.y), Vector3(p1.x, 0.15, p1.y),
						Vector3(p0.x, 0.0, p0.y), Vector3(p1.x, 0.15, p1.y), Vector3(p0.x, 0.15, p0.y)]
					for v in quad:
						rt.add_vertex(v)
				var q0: Vector2 = f0[0] + f0[1] * 0.43 * side
				var q1: Vector2 = f1[0] + f1[1] * 0.43 * side
				var r0: Vector2 = f0[0] + f0[1] * 0.48 * side
				var r1: Vector2 = f1[0] + f1[1] * 0.48 * side
				rt.set_normal(Vector3.UP)
				for v in ([q0, r1, r0, q0, q1, r1] if side > 0 else [q0, r0, r1, q0, r1, q1]):
					rt.add_vertex(Vector3(v.x, 0.15, v.y))
		var rail := mat("beltrail", METAL, {"metal": 0.6, "rough": 0.5})
		rail.cull_mode = BaseMaterial3D.CULL_DISABLED
		rt.set_material(rail)
		rt.commit(am)
		return am)


## Belt surface material: moving, idle (slow) or blocked (stopped, red tint).
static func belt_material(speed: float, blocked: bool) -> ShaderMaterial:
	var key := "beltmat_%s_%s" % [speed, blocked]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = BeltShader
		m.set_shader_parameter("speed", speed)
		if blocked:
			m.set_shader_parameter("arrow_color", Color(1.0, 0.25, 0.15))
		_mats[key] = m
	return _mats[key]


static func _shadows(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D and c.material_override != null and c.material_override.emission_enabled:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shadows(c)


## Replaces every material of a visual (for placement previews and ghosts).
static func override_all(n: Node, m: Material) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.material_override = m
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if c is Light3D:
			c.visible = false
		override_all(c, m)
