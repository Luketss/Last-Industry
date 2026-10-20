extends Node
## Gamepad / Steam Deck support. The pad drives the game through the same paths
## as keyboard and mouse: the right stick moves a virtual mouse cursor, face and
## shoulder buttons are turned into the (remappable) key and mouse events the
## rest of the game already handles, and the left stick pans the camera.
##
##   Left stick  pan camera          Right stick  move cursor
##   A           click / build       B            demolish (right click)
##   X           rotate              Y            eyedropper
##   LB / RB     previous / next structure in the build bar
##   LT / RT     zoom out / in       D-pad        speed − / +, research, rebuild
##   Start       pause menu          Back         statistics

const Bindings = preload("res://src/ui/bindings.gd")
const DEADZONE := 0.18
const CURSOR_SPEED := 1100.0   ## pixels per second at full tilt

var main
var _zoom_cd := 0.0
var active := false              ## a pad has been used since the last mouse move


func _init(p_main) -> void:
	main = p_main


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		active = true
		_button(event.button_index, event.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		active = true
	elif event is InputEventMouseMotion and not _synthetic(event):
		active = false


func _synthetic(event: InputEvent) -> bool:
	return event.has_meta("pad")


func _process(delta: float) -> void:
	if Input.get_connected_joypads().is_empty():
		return
	var pad: int = Input.get_connected_joypads()[0]
	var left := _stick(pad, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var right := _stick(pad, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	main.camera.pad_move = left
	if right != Vector2.ZERO:
		var vp := get_viewport()
		var mp := vp.get_mouse_position() + right * CURSOR_SPEED * delta
		var size := vp.get_visible_rect().size
		mp = Vector2(clampf(mp.x, 0, size.x - 1), clampf(mp.y, 0, size.y - 1))
		vp.warp_mouse(mp)
		var mm := InputEventMouseMotion.new()
		mm.position = mp
		mm.global_position = mp
		mm.relative = right * CURSOR_SPEED * delta
		mm.set_meta("pad", true)
		Input.parse_input_event(mm)
	_zoom_cd -= delta
	var lt := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT)
	var rt := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT)
	if _zoom_cd <= 0.0 and maxf(lt, rt) > 0.5:
		_zoom_cd = 0.08
		_mouse_button(MOUSE_BUTTON_WHEEL_UP if rt > lt else MOUSE_BUTTON_WHEEL_DOWN, true)


static func _stick(pad: int, ax: int, ay: int) -> Vector2:
	var v := Vector2(Input.get_joy_axis(pad, ax), Input.get_joy_axis(pad, ay))
	if v.length() < DEADZONE:
		return Vector2.ZERO
	return v.normalized() * inverse_lerp(DEADZONE, 1.0, minf(v.length(), 1.0))


func _button(b: int, pressed: bool) -> void:
	match b:
		JOY_BUTTON_A:
			_mouse_button(MOUSE_BUTTON_LEFT, pressed)
		JOY_BUTTON_B:
			_mouse_button(MOUSE_BUTTON_RIGHT, pressed)
		JOY_BUTTON_X:
			_key(Bindings.key("rotate"), pressed)
		JOY_BUTTON_Y:
			_key(Bindings.key("pipette"), pressed)
		JOY_BUTTON_START:
			_key(KEY_ESCAPE, pressed)
		JOY_BUTTON_BACK:
			_key(Bindings.key("stats"), pressed)
		JOY_BUTTON_DPAD_LEFT:
			_key(Bindings.key("speed_down"), pressed)
		JOY_BUTTON_DPAD_RIGHT:
			_key(Bindings.key("speed_up"), pressed)
		JOY_BUTTON_DPAD_UP:
			_key(Bindings.key("research"), pressed)
		JOY_BUTTON_DPAD_DOWN:
			_key(Bindings.key("rebuild"), pressed)
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
			if pressed and main.in_game:
				cycle_tool(1 if b == JOY_BUTTON_RIGHT_SHOULDER else -1)


## Steps through the unlocked structures of the build bar.
func cycle_tool(step: int) -> void:
	var menu: Array = main.data.game.build_menu
	var w = main.world
	var i: int = menu.find(main.controller.tool)
	for n in menu.size():
		i = posmod(i + step, menu.size())
		if w == null or w.is_unlocked(menu[i]):
			main.controller.set_tool(menu[i])
			return


func _mouse_button(button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = get_viewport().get_mouse_position()
	e.global_position = e.position
	e.set_meta("pad", true)
	Input.parse_input_event(e)
	if button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and pressed:
		var up := e.duplicate()
		up.pressed = false
		Input.parse_input_event(up)


func _key(keycode: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = pressed
	e.set_meta("pad", true)
	Input.parse_input_event(e)
