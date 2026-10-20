extends RefCounted
## Local save files in user://saves. Offline, no external services.
## Uses Godot's binary Variant encoding: Godot's JSON parser does not round-trip
## doubles exactly, which would break deterministic continuation after loading.

const World = preload("res://src/sim/world.gd")
const DIR := "user://saves"


static func slot_path(slot: String) -> String:
	return "%s/%s.lisave" % [DIR, slot]


static func has_save(slot: String = "slot1") -> bool:
	return FileAccess.file_exists(slot_path(slot))


static func save(w, slot: String = "slot1") -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(w.to_dict())
	return true


static func load_world(data, slot: String = "slot1"):
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return null
	var d = f.get_var()
	if not (d is Dictionary) or int(d.get("version", 0)) != World.SAVE_VERSION:
		return null
	return World.from_dict(data, d)
