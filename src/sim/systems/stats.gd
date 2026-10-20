extends RefCounted
## Production / consumption statistics with a rolling one-minute window.

const WINDOW := 60

var produced := {}
var consumed := {}
var delivered := {}
var built := {}
var kills := 0
var shots := 0
var lost := 0
var burned := 0
var loaded := 0
var waves := 0
var _ring_p := {}     ## item -> Array[int] (one slot per second)
var _ring_c := {}
var _slot := 0


func on_produced(item: String, n: int) -> void:
	produced[item] = int(produced.get(item, 0)) + n
	_ring_add(_ring_p, item, n)


func on_consumed(item: String, n: int) -> void:
	consumed[item] = int(consumed.get(item, 0)) + n
	_ring_add(_ring_c, item, n)


func on_delivered(item: String) -> void:
	delivered[item] = int(delivered.get(item, 0)) + 1


func on_built(type: String) -> void:
	built[type] = int(built.get(type, 0)) + 1


func _ring_add(ring: Dictionary, item: String, n: int) -> void:
	if not ring.has(item):
		var a := []
		a.resize(WINDOW)
		a.fill(0)
		ring[item] = a
	ring[item][_slot] += n


func step(w, _dt: float) -> void:
	var s := int(w.time) % WINDOW
	if s != _slot:
		_slot = s
		for ring in [_ring_p, _ring_c]:
			for item in ring:
				ring[item][_slot] = 0


## Items per minute over the last 60 s.
func rate(item: String, consumption: bool = false) -> int:
	var ring: Dictionary = _ring_c if consumption else _ring_p
	if not ring.has(item):
		return 0
	var t := 0
	for v in ring[item]:
		t += v
	return t


## Generic accessor used by objectives: "produced:iron_plate", "waves", "kills"...
func value(key: String) -> int:
	var parts := key.split(":")
	match parts[0]:
		"produced":
			return int(produced.get(parts[1], 0))
		"consumed":
			return int(consumed.get(parts[1], 0))
		"delivered":
			return int(delivered.get(parts[1], 0))
		"built":
			return int(built.get(parts[1], 0))
		"kills":
			return kills
		"burned":
			return burned
		"loaded":
			return loaded
		"waves":
			return waves
	return 0


func to_dict() -> Dictionary:
	return {"p": produced, "c": consumed, "d": delivered, "b": built, "kills": kills, "shots": shots,
		"lost": lost, "burned": burned, "loaded": loaded, "waves": waves, "rp": _ring_p, "rc": _ring_c, "slot": _slot}


func load_dict(d: Dictionary) -> void:
	var Items = preload("res://src/sim/items.gd")
	produced = Items.from_json(d.p)
	consumed = Items.from_json(d.c)
	delivered = Items.from_json(d.d)
	built = Items.from_json(d.b)
	kills = int(d.kills)
	shots = int(d.shots)
	lost = int(d.lost)
	burned = int(d.burned)
	loaded = int(d.loaded)
	waves = int(d.waves)
	_slot = int(d.slot)
	_ring_p = _ring_from(d.rp)
	_ring_c = _ring_from(d.rc)


static func _ring_from(d: Dictionary) -> Dictionary:
	var r := {}
	for k in d:
		var a := []
		for v in d[k]:
			a.append(int(v))
		r[str(k)] = a
	return r
