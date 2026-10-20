extends RefCounted
## Third-party 3D models (Kenney kits from OpenGameArt, see assets/CREDITS.md).
## Models are addressed as "kit/name" (assets/models/kit/name.glb). Every helper
## degrades to null when a model is missing, so callers can fall back to the
## procedural primitives in meshes.gd.

const ROOT := "res://assets/models/%s.glb"

static var _scenes := {}
static var _aabbs := {}
static var _merged := {}


static func has(name: String) -> bool:
	return _scene(name) != null


static func _scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		var path := ROOT % name
		_scenes[name] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[name]


## Bounding box of the model in its own space (all meshes, all nodes).
static func aabb(name: String) -> AABB:
	if not _aabbs.has(name):
		var n := _scene(name).instantiate()
		_aabbs[name] = _node_aabb(n, Transform3D.IDENTITY)
		n.free()
	return _aabbs[name]


static func _node_aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t: Transform3D = xf * (n.transform if n is Node3D else Transform3D.IDENTITY)
	if n is MeshInstance3D and n.mesh != null:
		out = t * n.mesh.get_aabb()
		first = false
	for c in n.get_children():
		var a := _node_aabb(c, t)
		if a.size == Vector3.ZERO:
			continue
		out = a if first else out.merge(a)
		first = false
	return out


## Instances a model under `parent`. The model is scaled uniformly so its
## footprint fits `fit.x` × `fit.z` (and its height `fit.y` when > 0), centred on
## `at` horizontally with its base on `at.y`. `ry` turns it around Y (radians).
static func place(parent: Node3D, name: String, at: Vector3, fit: Vector3, ry: float = 0.0) -> Node3D:
	if not has(name):
		return null
	var box := aabb(name)
	var sx := box.size.x if absf(sin(ry)) < 0.7 else box.size.z
	var sz := box.size.z if absf(sin(ry)) < 0.7 else box.size.x
	var s := minf(fit.x / maxf(sx, 0.001), fit.z / maxf(sz, 0.001))
	if fit.y > 0.0:
		s = minf(s, fit.y / maxf(box.size.y, 0.001))
	var pivot := Node3D.new()
	pivot.position = at
	pivot.rotation.y = ry
	pivot.scale = Vector3.ONE * s
	parent.add_child(pivot)
	var inst: Node3D = _scene(name).instantiate()
	inst.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	pivot.add_child(inst)
	return pivot


## All meshes of a model baked into one Mesh (for MultiMesh scatter), with the
## base centred on the origin and the footprint normalised to 1×1.
static func merged_mesh(name: String) -> Mesh:
	if _merged.has(name):
		return _merged[name]
	if not has(name):
		return null
	var box := aabb(name)
	var s := 1.0 / maxf(box.size.x, box.size.z)
	var origin := Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -Vector3(box.get_center().x, box.position.y, box.get_center().z))
	var st := SurfaceTool.new()
	var n := _scene(name).instantiate()
	var mat: Material = null
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	mat = _append(st, n, origin, mat)
	n.free()
	st.set_material(mat)
	var m := st.commit()
	_merged[name] = m
	return m


static func _append(st: SurfaceTool, n: Node, xf: Transform3D, mat: Material) -> Material:
	var t: Transform3D = xf * (n.transform if n is Node3D else Transform3D.IDENTITY)
	if n is MeshInstance3D and n.mesh != null:
		for i in n.mesh.get_surface_count():
			st.append_from(n.mesh, i, t)
			if mat == null:
				mat = n.get_active_material(i)
	for c in n.get_children():
		mat = _append(st, c, t, mat)
	return mat


## Enemy creature (assets/models/enemies/<type>.obj + palette .png from the 50+
## Monsters Pack) baked for MultiMesh: base on the origin, longest side 1, facing
## +X. The material multiplies the palette by the instance colour so the view can
## tint per type, elite and hit flash. Null when the model is missing.
static func enemy_mesh(type: String) -> Mesh:
	var key := "enemy/" + type
	if _merged.has(key):
		return _merged[key]
	var path := "res://assets/models/enemies/%s.obj" % type
	if not ResourceLoader.exists(path):
		return null
	var src: Mesh = load(path)
	var box := src.get_aabb()
	var s := 1.0 / maxf(maxf(box.size.x, box.size.z), 0.001)
	# The pack's creatures face +Z; turn them to the game's +X.
	var xf := Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * s), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -Vector3(box.get_center().x, box.position.y, box.get_center().z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in src.get_surface_count():
		st.append_from(src, i, xf)
	var m := StandardMaterial3D.new()
	var tex_path := "res://assets/models/enemies/%s.png" % type
	if ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.75
	st.set_material(m)
	var mesh := st.commit()
	_merged[key] = mesh
	return mesh
