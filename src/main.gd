extends Node
## Application entry: owns the World and wires simulation, view, input, audio and UI.
## The simulation advances in fixed ticks independent of frame rate.

const Defs = preload("res://src/sim/defs.gd")
const GameData = preload("res://src/sim/game_data.gd")
const World = preload("res://src/sim/world.gd")
const SaveSystem = preload("res://src/sim/save_system.gd")
const WorldView = preload("res://src/view/world_view.gd")
const CameraRig = preload("res://src/view/camera_rig.gd")
const BuildController = preload("res://src/view/build_controller.gd")
const GameAudio = preload("res://src/view/audio.gd")
const Hud = preload("res://src/ui/hud.gd")
const Settings = preload("res://src/ui/settings.gd")

const MAX_STEPS_PER_FRAME := 12
const SPEEDS := [1.0, 2.0, 3.0]

var data
var world
var view
var camera
var controller
var audio
var hud
var in_game := false
var paused := false
var menu_paused := false
var speed := 1.0
var _acc := 0.0
var _end_shown := false
var _smoke := -1
var _shots_dir := ""


func _ready() -> void:
	data = GameData.new()
	view = WorldView.new()
	add_child(view)
	camera = CameraRig.new()
	add_child(camera)
	controller = BuildController.new(self)
	add_child(controller)
	audio = GameAudio.new(self)
	add_child(audio)
	Settings.load_all()
	hud = Hud.new(self)
	add_child(hud)
	Settings.apply(self)
	to_main_menu()
	for a in OS.get_cmdline_user_args():
		if a == "--smoke":
			_smoke = 0
		elif a.begins_with("--screenshots="):
			_shots_dir = a.trim_prefix("--screenshots=")


func _bind(w) -> void:
	world = w
	view.bind(w)
	hud.bind_world(w)
	camera.bounds = Rect2(0, 0, w.width, w.height)
	var c = w.core()
	var focus := Vector3(w.width * 0.5, 0, w.height * 0.5) if c == null else Vector3(c.center().x, 0, c.center().y)
	camera.focus(focus, true)
	controller.cancel()
	_acc = 0.0
	_end_shown = false


func to_main_menu() -> void:
	in_game = false
	paused = false
	menu_paused = false
	_bind(World.new(data, 1337))
	camera.orbit = true
	camera.zoom = 34.0
	hud.show_main_menu(SaveSystem.has_save())


func start_new_game() -> void:
	_bind(World.new(data, randi() % 1000000 + 1))
	_enter_game()
	hud.toast("Instalação reativada. Construa uma Mineradora sobre o minério de ferro.")


func _enter_game() -> void:
	in_game = true
	paused = false
	menu_paused = false
	speed = 1.0
	camera.orbit = false
	camera.zoom = 26.0
	hud.show_game()


func save_game() -> void:
	if world == null or not in_game:
		return
	if SaveSystem.save(world):
		hud.toast("Jogo salvo")
	else:
		hud.toast("Falha ao salvar")


func load_game() -> void:
	var w = SaveSystem.load_world(data)
	if w == null:
		hud.toast("Nenhum jogo salvo compatível")
		return
	_bind(w)
	_enter_game()
	hud.toast("Jogo carregado")
	if w.state != "playing":
		_end_shown = false


func continue_survival() -> void:
	if world != null:
		world.continue_survival()
		_end_shown = false
		hud.end_panel.visible = false
		hud.toast("Modo Sobrevivência: as hordas ficarão cada vez maiores.")


func quit_game() -> void:
	get_tree().quit()


func set_menu_paused(v: bool) -> void:
	menu_paused = v
	hud.show_pause(v)


func _unhandled_input(event: InputEvent) -> void:
	if not in_game:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _global_key(event):
			get_viewport().set_input_as_handled()
			return
	if menu_paused:
		return
	if camera.handle_input(event) or controller.handle_input(event):
		get_viewport().set_input_as_handled()


func _global_key(e: InputEventKey) -> bool:
	match e.keycode:
		KEY_ESCAPE:
			if hud.close_overlays():
				pass
			elif not controller.cancel():
				set_menu_paused(not menu_paused)
			return true
		KEY_SPACE:
			paused = not paused
			return true
		KEY_TAB:
			hud.toggle_stats()
			return true
		KEY_T:
			hud.toggle_research()
			return true
		KEY_H, KEY_F1:
			hud.toggle_help()
			return true
		KEY_F3:
			view.debug = not view.debug
			return true
		KEY_F5:
			save_game()
			return true
		KEY_F9:
			load_game()
			return true
		KEY_N:
			if world.state == "playing" and world.waves.has_more(world) and not world.waves.active:
				world.waves.timer = 0.0
			return true
		KEY_EQUAL, KEY_KP_ADD, KEY_PLUS:
			if e.keycode == KEY_EQUAL and not e.shift_pressed:
				return _hotkey(11)
			speed = SPEEDS[mini(SPEEDS.find(speed) + 1, SPEEDS.size() - 1)]
			return true
		KEY_MINUS, KEY_KP_SUBTRACT:
			if e.keycode == KEY_MINUS and not e.shift_pressed:
				return _hotkey(10)
			speed = SPEEDS[maxi(SPEEDS.find(speed) - 1, 0)]
			return true
	if e.keycode >= KEY_0 and e.keycode <= KEY_9 and not e.ctrl_pressed:
		var i: int = 9 if e.keycode == KEY_0 else e.keycode - KEY_1
		return _hotkey(i)
	return false


func _hotkey(i: int) -> bool:
	var menu: Array = data.game.build_menu
	if i < menu.size():
		controller.set_tool(menu[i])
	return true


func _process(delta: float) -> void:
	if world == null:
		return
	if in_game and not paused and not menu_paused and world.state == "playing":
		_acc += delta * speed
		var steps := 0
		while _acc >= Defs.DT and steps < MAX_STEPS_PER_FRAME:
			world.step()
			_acc -= Defs.DT
			steps += 1
		if steps == MAX_STEPS_PER_FRAME:
			_acc = 0.0
	var ev: Array = world.events
	world.events = []
	view.on_events(ev)
	hud.on_events(ev)
	audio.on_events(ev)
	view.camera_focus = camera.position
	if in_game and world.state != "playing" and not _end_shown:
		_end_shown = true
		hud.show_end(world.state)
	if _smoke >= 0:
		_smoke_step()


## Automated end-to-end run (used by CI): `godot --headless -- --smoke`
func _smoke_step() -> void:
	_smoke += 1
	match _smoke:
		30:
			_shot("01_menu")
		32:
			start_new_game()
			_demo_base()
			world.waves.timer = 3.0
			speed = 3.0
		150:
			_shot("02_base")
			controller.selected = world.building_at(world.core().pos + Vector2i(-6, -1)).id if world.building_at(world.core().pos + Vector2i(-6, -1)) else 0
		260:
			_shot("03_wave")
			hud.toggle_stats()
		275:
			_shot("04_stats")
			hud.toggle_stats()
			hud.toggle_research()
		278:
			_shot("04b_research")
			hud.toggle_research()
			view.debug = true
			controller.set_tool("turret_tesla")
		290:
			_shot("05_debug")
			view.debug = false
			controller.set_tool("")
			save_game()
		300:
			load_game()
		330:
			# Phase 7 tools: area selection -> blueprint -> paste; flow tracing.
			var c: Vector2i = world.core().pos
			world.storage["iron_plate"] = 2000
			world.storage["gear"] = 1000
			controller._drag_start = c + Vector2i(-10, -1)
			controller.hover = c + Vector2i(-2, 2)
			controller._finish_area_select()
			print("smoke: selected %d" % controller.selection.size())
			controller.copy_selection_blueprint()
			controller.hover_point = Vector2(c.x - 5, c.y + 14)
		336:
			controller._paste_blueprint()
			controller.set_tool("")
			controller.trace_mode = true
			controller.hover = world.core().pos + Vector2i(-6, 0)
		345:
			_shot("07_tools")
			hud.toggle_options()
		350:
			_shot("08_options")
			hud.toggle_options()
			controller.trace_mode = false
		420:
			_shot("06_loaded")
			print("SMOKE OK tick=%d enemies=%d buildings=%d" % [world.tick, world.enemies.size(), world.buildings.size()])
			get_tree().quit(0)


func _shot(name: String) -> void:
	if _shots_dir == "":
		return
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/%s.png" % [_shots_dir, name])


## A compact working base around the core (ore is injected so it works on any map).
func _demo_base() -> void:
	var c: Vector2i = world.core().pos
	var W = world
	for y in 2:
		for x in 2:
			W.set_terrain(c + Vector2i(-9 + x, y), Defs.T_IRON, 400)
			W.set_terrain(c + Vector2i(-9 + x, 5 + y), Defs.T_COAL, 400)
	W.ore_version += 1
	W.storage["iron_plate"] = 600
	W.storage["gear"] = 200
	W.place("pole", c + Vector2i(-5, 4), 0)
	W.place("pole", c + Vector2i(-10, 3), 0)
	W.place("miner", c + Vector2i(-9, 0), 0)
	W.place("belt", c + Vector2i(-7, 0), 0)
	W.place("smelter", c + Vector2i(-6, 0), 0)
	for x in range(-4, -2):
		W.place("belt", c + Vector2i(x, 0), 0)
	W.place("belt", c + Vector2i(-3, 0), 0)
	W.place("belt", c + Vector2i(-2, 0), 0)
	W.place("belt", c + Vector2i(-1, 0), 0)
	W.place("miner", c + Vector2i(-9, 5), 0)
	W.place("generator", c + Vector2i(-6, 6), 0)
	for x in range(-7, -1):
		W.place("belt", c + Vector2i(x, 5), 0)
	W.place("belt", c + Vector2i(-1, 5), 3)
	W.place("belt", c + Vector2i(-1, 4), 3)
	W.place("belt", c + Vector2i(-1, 3), 0)
	W.place("assembler", c + Vector2i(5, -4), 1)
	W.place("turret_gun", c + Vector2i(5, 1), 0)
	W.place("turret_gun", c + Vector2i(5, 4), 0)
	W.buildings[W.building_at(c + Vector2i(5, 1)).id].inv = {"ammo": 8}
	W.buildings[W.building_at(c + Vector2i(5, 4)).id].inv = {"ammo": 8}
	W.place("turret_tesla", c + Vector2i(-3, -5), 0)
	W.place("battery", c + Vector2i(0, -5), 0)
	W.place("repair", c + Vector2i(2, 5), 0)
	W.place("depot", c + Vector2i(7, -1), 0)
	W.place("pole", c + Vector2i(4, -1), 0)
	W.research.complete(W, "military_1")
	W.research.complete(W, "anti_air")
	W.research.complete(W, "automation_1")
	W.research.complete(W, "solar")
	W.place("lab", c + Vector2i(-6, -4), 0)
	W.place("solar", c + Vector2i(-9, -4), 0)
	W.place("turret_aa", c + Vector2i(2, -6), 0)
	W.research.complete(W, "artillery")
	W.place("turret_cannon", c + Vector2i(-3, 5), 0)
	W.research.select(W, "ballistics")
	for i in range(-6, 9):
		W.place("wall", c + Vector2i(9, i), 0)
		W.place("wall", c + Vector2i(-12, i), 0)
	for i in range(-11, 9):
		W.place("wall", c + Vector2i(i, -8), 0)
		W.place("wall", c + Vector2i(i, 9), 0)
