extends Node3D
## Particle effects for combat and machinery: muzzle flashes, impact sparks,
## explosions (fire + smoke), creature death puffs and chimney smoke. One-shot
## effects come from small pools of GPUParticles3D that are moved and restarted,
## so a busy fight never allocates nodes.

const POOL := 16

var _pools := {}          ## kind -> {nodes: Array, next: int}
var _soft: Texture2D


func _ready() -> void:
	_soft = _soft_dot()
	_pool("flash", 6, 0.1, _fire_mat(), {"speed": [0.3, 1.0], "scale": [0.35, 0.6], "spread": 40.0,
		"ramp": [Color(1.0, 0.85, 0.5, 1.0), Color(1.0, 0.45, 0.1, 0.0)]})
	_pool("sparks", 10, 0.35, _fire_mat(), {"speed": [2.0, 4.5], "scale": [0.06, 0.12], "spread": 70.0, "gravity": -9.0,
		"ramp": [Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.5, 0.1, 0.0)]})
	_pool("fire", 26, 0.7, _fire_mat(), {"speed": [1.0, 3.2], "scale": [0.5, 1.1], "spread": 180.0, "gravity": 1.0,
		"ramp": [Color(1.0, 0.8, 0.4, 1.0), Color(0.9, 0.3, 0.05, 0.8), Color(0.2, 0.1, 0.05, 0.0)]})
	_pool("smoke", 18, 2.2, _smoke_mat(), {"speed": [0.4, 1.2], "scale": [0.8, 1.6], "spread": 60.0, "gravity": 0.6,
		"ramp": [Color(0.25, 0.22, 0.2, 0.0), Color(0.22, 0.2, 0.18, 0.7), Color(0.3, 0.28, 0.26, 0.0)]})
	_pool("gore", 12, 0.45, _smoke_mat(), {"speed": [1.0, 2.5], "scale": [0.15, 0.3], "spread": 80.0, "gravity": -7.0,
		"ramp": [Color(0.6, 0.12, 0.06, 1.0), Color(0.3, 0.05, 0.03, 0.0)]})
	_pool("dust", 10, 0.6, _smoke_mat(), {"speed": [0.6, 1.4], "scale": [0.3, 0.6], "spread": 90.0, "gravity": -1.0,
		"ramp": [Color(0.5, 0.42, 0.32, 0.6), Color(0.45, 0.4, 0.34, 0.0)]})


## Plays a one-shot effect at a world position. `size` scales the burst.
func play(kind: String, at: Vector3, size: float = 1.0) -> void:
	var p: Dictionary = _pools.get(kind, {})
	if p.is_empty():
		return
	var node: GPUParticles3D = p.nodes[p.next]
	p.next = (p.next + 1) % p.nodes.size()
	node.position = at
	node.scale = Vector3.ONE * size
	node.restart()


## Continuous chimney smoke attached to a building; toggled with `emitting`.
func make_smoke(parent: Node3D, at: Vector3) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.amount = 14
	g.lifetime = 3.2
	g.preprocess = 0.0
	g.local_coords = false
	g.position = at
	g.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := _process_mat({"speed": [0.4, 0.8], "scale": [0.35, 0.9], "spread": 12.0, "gravity": 0.5,
		"ramp": [Color(0.3, 0.28, 0.26, 0.0), Color(0.28, 0.26, 0.24, 0.55), Color(0.4, 0.38, 0.36, 0.0)]})
	pm.direction = Vector3(0.25, 1, 0.1)
	pm.scale_curve = _grow_curve()
	g.process_material = pm
	g.draw_pass_1 = _quad(_smoke_mat())
	g.emitting = false
	parent.add_child(g)
	return g


func _pool(kind: String, amount: int, life: float, mat: Material, o: Dictionary) -> void:
	var nodes := []
	var pm := _process_mat(o)
	var quad := _quad(mat)
	for i in POOL:
		var g := GPUParticles3D.new()
		g.amount = amount
		g.lifetime = life
		g.one_shot = true
		g.explosiveness = 0.95
		g.emitting = false
		g.local_coords = false
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 8, 8))
		g.process_material = pm
		g.draw_pass_1 = quad
		add_child(g)
		nodes.append(g)
	_pools[kind] = {"nodes": nodes, "next": 0}


func _process_mat(o: Dictionary) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = float(o.get("spread", 45.0))
	pm.initial_velocity_min = o.speed[0]
	pm.initial_velocity_max = o.speed[1]
	pm.gravity = Vector3(0, float(o.get("gravity", 0.0)), 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = o.scale[0]
	pm.scale_max = o.scale[1]
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15
	var g := Gradient.new()
	var ramp: Array = o.ramp
	var offs := PackedFloat32Array()
	for i in ramp.size():
		offs.append(float(i) / (ramp.size() - 1))
	g.offsets = offs
	g.colors = PackedColorArray(ramp)
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	return pm


func _grow_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.6))
	c.max_value = 2.0
	var ct := CurveTexture.new()
	ct.curve = c
	return ct


func _quad(mat: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	q.material = mat
	return q


func _fire_mat() -> StandardMaterial3D:
	var m := _base_mat()
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _smoke_mat() -> StandardMaterial3D:
	return _base_mat()


func _base_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft
	m.disable_receive_shadows = true
	return m


## Round, soft-edged sprite for every particle.
static func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t
