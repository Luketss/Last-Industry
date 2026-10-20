extends Node3D
## Isometric orthographic camera: pan (WASD / arrows / middle mouse), zoom (wheel),
## rotate in 90° steps (Z / C). Ground picking via ray/plane intersection.
## Keys come from Bindings and can be remapped in the options.

const Bindings = preload("res://src/ui/bindings.gd")
const PITCH := -50.0
const ZOOM_MIN := 10.0
const ZOOM_MAX := 70.0

var cam: Camera3D
var target := Vector3.ZERO
var yaw := 45.0
var zoom := 28.0
var input_enabled := true
var orbit := false            ## slow automatic rotation used behind the main menu
var edge_pan := false         ## move when the mouse touches the screen border
var speed := 1.0
var pad_move := Vector2.ZERO  ## left stick of a gamepad (see gamepad.gd)
var bounds := Rect2(0, 0, 64, 64)
var _yaw := 45.0
var _zoom := 28.0
var _drag := false


func _ready() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = zoom
	cam.near = 0.1
	cam.far = 400.0
	cam.position = Vector3(0, 0, 120)
	add_child(cam)
	cam.make_current()


func focus(p: Vector3, snap: bool = false) -> void:
	target = p
	if snap:
		position = p


func _process(delta: float) -> void:
	if orbit:
		yaw += delta * 3.0
	elif input_enabled:
		var v := Vector2.ZERO
		var typing: bool = Input.is_key_pressed(KEY_CTRL)
		if not typing:
			if Bindings.held("cam_up") or Input.is_key_pressed(KEY_UP):
				v.y -= 1
			if Bindings.held("cam_down") or Input.is_key_pressed(KEY_DOWN):
				v.y += 1
			if Bindings.held("cam_left") or Input.is_key_pressed(KEY_LEFT):
				v.x -= 1
			if Bindings.held("cam_right") or Input.is_key_pressed(KEY_RIGHT):
				v.x += 1
		if edge_pan and DisplayServer.window_is_focused():
			var mp := get_viewport().get_mouse_position()
			var vs := get_viewport().get_visible_rect().size
			if mp.x < 6:
				v.x -= 1
			elif mp.x > vs.x - 6:
				v.x += 1
			if mp.y < 6:
				v.y -= 1
			elif mp.y > vs.y - 6:
				v.y += 1
		if v != Vector2.ZERO:
			var fast := 2.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
			target += _plane_dir(v.normalized()) * delta * _zoom * 0.9 * fast * speed
		if pad_move != Vector2.ZERO:
			target += _plane_dir(pad_move) * delta * _zoom * 1.1 * speed
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)
	var k := minf(delta * 10.0, 1.0)
	position = position.lerp(target, k)
	_yaw = lerpf(_yaw, yaw, k)
	_zoom = lerpf(_zoom, zoom, k)
	rotation_degrees = Vector3(PITCH, _yaw, 0)
	cam.size = _zoom


## Converts a screen-space direction into a ground-plane direction for the current yaw.
func _plane_dir(v: Vector2) -> Vector3:
	var right := global_transform.basis.x
	right.y = 0
	var fwd := -global_transform.basis.z
	fwd.y = 0
	return (right.normalized() * v.x - fwd.normalized() * v.y)


func handle_input(event: InputEvent) -> bool:
	if not input_enabled:
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = clampf(zoom * 0.88, ZOOM_MIN, ZOOM_MAX)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = clampf(zoom * 1.12, ZOOM_MIN, ZOOM_MAX)
			return true
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = event.pressed
			return true
	if event is InputEventMouseMotion and _drag:
		var px_to_world := _zoom / float(get_viewport().get_visible_rect().size.y)
		target -= _plane_dir(event.relative) * px_to_world * Vector3(1, 0, 1).length() * 1.3
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if Bindings.is_action(event, "cam_rot_left"):
			yaw -= 90.0
			return true
		if Bindings.is_action(event, "cam_rot_right"):
			yaw += 90.0
			return true
	return false


## Ground point (y = 0) under a screen position, or null.
func ground_at(screen: Vector2):
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return null
	var t := -o.y / d.y
	if t < 0:
		return null
	return o + d * t
