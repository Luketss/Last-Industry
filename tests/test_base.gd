extends RefCounted
## Minimal assertion helpers shared by test suites.

const GameData = preload("res://src/sim/game_data.gd")
const World = preload("res://src/sim/world.gd")
const Defs = preload("res://src/sim/defs.gd")

static var _data = null
var failures: Array = []
var _current := ""


static func data():
	if _data == null:
		_data = GameData.new()
	return _data


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [_current, msg])


func eq(a, b, msg: String) -> void:
	check(a == b, "%s (esperado %s, obtido %s)" % [msg, str(b), str(a)])


## Flat empty map with a core in the middle and no waves unless requested.
func empty_world(opts: Dictionary = {}):
	var o := {"width": 32, "height": 32, "generate": false, "spawns": [Vector2i(1, 16)],
		"storage": {"iron_plate": 1000, "gear": 1000},
		"waves": {"first_delay": 1.0e9, "interval": 1.0e9, "waves": []}}
	o.merge(opts, true)
	return World.new(data(), 7, o)


static func run_ticks(w, n: int) -> void:
	for i in n:
		w.step()


static func run_seconds(w, s: float) -> void:
	run_ticks(w, int(s * Defs.TICK_RATE))
