extends RefCounted
## Loads every configurable definition from res://data. Content is data-driven:
## machines, recipes, weapons, enemies and waves are tuned in JSON, not code.

var items: Dictionary
var buildings: Dictionary
var recipes: Dictionary
var enemies: Dictionary
var waves: Dictionary
var game: Dictionary
var objectives: Array
var lore: Array
var research: Array
var achievements: Array
var _texts: Array = []      ## [dict, field, original Portuguese text] for localize()

const TEXT_FIELDS := ["name", "short", "desc", "text", "title"]


func _init(base_path: String = "res://data") -> void:
	items = _load(base_path + "/items.json")
	buildings = _load(base_path + "/buildings.json")
	recipes = _load(base_path + "/recipes.json")
	enemies = _load(base_path + "/enemies.json")
	waves = _load(base_path + "/waves.json")
	game = _load(base_path + "/game.json")
	objectives = _load(base_path + "/objectives.json")
	lore = _load(base_path + "/lore.json")
	research = _load(base_path + "/research.json")
	achievements = _load(base_path + "/achievements.json")
	for coll in [items.values(), buildings.values(), recipes.values(), enemies.values(), objectives, lore, research, achievements]:
		for d in coll:
			for f in TEXT_FIELDS:
				if d is Dictionary and d.has(f) and d[f] is String:
					_texts.append([d, f, d[f]])
	localize()


## Rewrites every name/description in place for the current locale. The dicts
## themselves are kept, so structures and research that reference them update too.
func localize() -> void:
	for e in _texts:
		e[0][e[1]] = TranslationServer.translate(e[2])


## Every source text in the data files (for the translation extractor and tests).
func source_texts() -> Array:
	var out := []
	for e in _texts:
		out.append(e[2])
	return out


func item_name(id: String) -> String:
	return str(items.get(id, {}).get("name", id))


func item_color(id: String) -> Color:
	return Color.html(str(items.get(id, {}).get("color", "#ff00ff")))


static func _load(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameData: cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("GameData: invalid JSON in %s" % path)
		return {}
	return parsed
