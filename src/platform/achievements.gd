extends RefCounted
## Achievements evaluated from World statistics (data/achievements.json).
## Unlocks are stored locally (user://achievements.cfg) so they work offline and
## outside Steam; SteamService mirrors them to Steam when available.

static var path := "user://achievements.cfg"

var defs: Array = []
var unlocked := {}      ## id -> unix time


func _init(p_defs: Array) -> void:
	defs = p_defs
	var cf := ConfigFile.new()
	if cf.load(path) == OK:
		for id in cf.get_section_keys("unlocked") if cf.has_section("unlocked") else []:
			unlocked[id] = cf.get_value("unlocked", id)


## Returns the definitions unlocked by this call.
func check(stats) -> Array:
	var fresh := []
	for d in defs:
		if unlocked.has(d.id):
			continue
		if stats.value(str(d.stat)) >= int(d.n):
			unlocked[d.id] = int(Time.get_unix_time_from_system())
			fresh.append(d)
	if not fresh.is_empty():
		_save()
	return fresh


func progress(stats, d: Dictionary) -> Array:
	return [mini(stats.value(str(d.stat)), int(d.n)), int(d.n)]


func _save() -> void:
	var cf := ConfigFile.new()
	for id in unlocked:
		cf.set_value("unlocked", id, unlocked[id])
	cf.save(path)
