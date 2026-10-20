extends RefCounted
## Player preferences persisted in user://settings.cfg (independent of save games).

const PATH := "user://settings.cfg"
static var path := PATH     ## overridable by tests
const DEFAULTS := {
	"language": "", "volume": 0.8, "music_volume": 0.6, "sfx_volume": 0.9, "fullscreen": false, "ui_scale": 1.0, "hints": true,
	"edge_pan": false, "camera_speed": 1.0, "minimap": true, "hints_seen": [], "bindings": {},
}

static var values := DEFAULTS.duplicate(true)


static func load_all() -> void:
	values = DEFAULTS.duplicate(true)
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	for k in DEFAULTS:
		values[k] = cf.get_value("game", k, DEFAULTS[k])


static func save_all() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("game", k, values[k])
	cf.save(path)


static func get_value(k: String):
	return values.get(k, DEFAULTS.get(k))


static func set_value(k: String, v) -> void:
	values[k] = v
	save_all()


static func apply(main) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(values.volume), 0.0001)))
	for bus in [["Music", "music_volume"], ["SFX", "sfx_volume"]]:
		var i := AudioServer.get_bus_index(bus[0])
		if i != -1:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(values[bus[1]]), 0.0001)))
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
	main.get_tree().root.content_scale_factor = float(values.ui_scale)
	main.camera.edge_pan = bool(values.edge_pan)
	main.camera.speed = float(values.camera_speed)
