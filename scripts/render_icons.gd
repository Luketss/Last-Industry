extends SceneTree
## Renders the build-bar icons (assets/icons/buildings/<type>.png) from the same
## models the game uses, so icons always match the structures. Needs a GPU or a
## virtual display; run after changing models:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://scripts/render_icons.gd

const GameData = preload("res://src/sim/game_data.gd")
const Meshes = preload("res://src/view/meshes.gd")
const SIZE := 128
const OUT := "res://assets/icons/buildings/"

var _vp: SubViewport
var _stage: Node3D
var _queue: Array = []
var _current := ""
var _wait := 0


func _init() -> void:
	var data = GameData.new()
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.53, 0.5)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.rotation_degrees = Vector3(-50, -35, 0)
	_vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-35, 45, 0)
	_vp.add_child(cam)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for type in data.game.build_menu:
		_queue.append([type, data.buildings[type]])


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var img := _vp.get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path(OUT + _current + ".png"))
			print("icon ", _current)
		return false
	if _queue.is_empty():
		return true
	for c in _stage.get_children():
		c.free()
	var next: Array = _queue.pop_front()
	_current = next[0]
	var def: Dictionary = next[1]
	var h := Meshes.build(_current, def, 0)
	_stage.add_child(h.root)
	if h.light != null:
		h.light.visible = false
	var s: Array = def.get("size", [1, 1])
	var centre := Vector3(float(s[0]) * 0.5, float(h.h) * 0.4, float(s[1]) * 0.5)
	var cam: Camera3D = _vp.get_child(2)
	cam.size = maxf(float(maxi(s[0], s[1])) * 1.55, float(h.h) * 1.25)
	cam.position = centre + cam.global_transform.basis.z * 20.0
	_wait = 4
	return false
