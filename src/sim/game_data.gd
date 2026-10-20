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


func _init(base_path: String = "res://data") -> void:
	items = _load(base_path + "/items.json")
	buildings = _load(base_path + "/buildings.json")
	recipes = _load(base_path + "/recipes.json")
	enemies = _load(base_path + "/enemies.json")
	waves = _load(base_path + "/waves.json")
	game = _load(base_path + "/game.json")
	objectives = _load(base_path + "/objectives.json")
	lore = _load(base_path + "/lore.json")


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
