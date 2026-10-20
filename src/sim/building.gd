extends RefCounted
## State of one placed structure. A single class with kind-specific fields keeps
## systems simple (they iterate buildings by kind) and serialisation trivial.

const Defs = preload("res://src/sim/defs.gd")
const Items = preload("res://src/sim/items.gd")

## Status label -> severity (0 ok, 1 attention, 2 failure). Shown in UI and as status lights.
const STATUS_LEVEL := {
	"": 0, "ok": 0, "trabalhando": 0, "minerando": 0, "gerando": 0, "atacando": 0, "vigiando": 0,
	"reparando": 0, "pronta": 0, "armazenando": 0, "ociosa": 1, "ocioso": 1,
	"sem insumos": 1, "saída bloqueada": 1, "carregando": 1, "sem combustível": 2,
	"sem materiais": 1, "sem energia": 2, "sem munição": 2, "esgotado": 2, "desligado": 2,
	"energia baixa": 1, "sem conexão": 2, "pesquisando": 0, "sem pesquisa": 1,
}

var id := 0
var type := ""
var kind := ""
var def: Dictionary
var pos := Vector2i.ZERO
var rot := 0
var size := Vector2i.ONE
var hp := 1.0
var max_hp := 1.0
var enabled := true
var status := ""

var inv := {}          ## input / storage buffer
var out := {}          ## output buffer
var recipe := ""
var filter := ["", "", ""]   ## splitter: item routed to left/front/right ("" = any)
var progress := 0.0
var crafting := false

var power_net := -1
var power_req := 0.0
var power_sat := 0.0
var energy := 0.0       ## battery / tesla charge (kJ), generator fuel (kJ), repair heal budget (HP)

var cooldown := 0.0
var rounds := 0
var target := 0
var scan := 0.0           ## target / repair scan timer
var pull_cd := 0.0        ## adjacent-belt pull timer
var rr := 0
var belt_items: Array = []   ## [[item_id, progress 0..1], ...] front-most first
var last_damaged := -100.0

# Caches rebuilt by systems (not saved)
var ore_cells: Array = []
var adj_belts: Array = []
var aim := 0.0


func setup(p_id: int, p_type: String, p_def: Dictionary, p_pos: Vector2i, p_rot: int) -> void:
	id = p_id
	type = p_type
	def = p_def
	kind = str(def.get("kind", type))
	pos = p_pos
	rot = posmod(p_rot, 4)
	size = footprint(def, rot)
	max_hp = float(def.get("hp", 100))
	hp = max_hp
	if def.has("recipes"):
		recipe = str(def.recipes[0])


static func footprint(p_def: Dictionary, p_rot: int) -> Vector2i:
	var s: Array = p_def.get("size", [1, 1])
	var v := Vector2i(int(s[0]), int(s[1]))
	if posmod(p_rot, 2) == 1:
		v = Vector2i(v.y, v.x)
	return v


func cells() -> Array:
	var r := []
	for y in size.y:
		for x in size.x:
			r.append(pos + Vector2i(x, y))
	return r


func contains(c: Vector2i) -> bool:
	return c.x >= pos.x and c.y >= pos.y and c.x < pos.x + size.x and c.y < pos.y + size.y


func center() -> Vector2:
	return Vector2(pos.x + size.x * 0.5, pos.y + size.y * 0.5)


func output_cell() -> Vector2i:
	return output_cell_for(pos, size, rot)


## Every tile just outside the front edge. Machines deliver to any of them, so the
## rule for players is simply "items leave through the yellow front side".
func output_cells() -> Array:
	return output_cells_for(pos, size, rot)


static func output_cells_for(p: Vector2i, s: Vector2i, r: int) -> Array:
	var out := []
	match posmod(r, 4):
		0:
			for y in s.y:
				out.append(Vector2i(p.x + s.x, p.y + y))
		1:
			for x in s.x:
				out.append(Vector2i(p.x + x, p.y + s.y))
		2:
			for y in s.y:
				out.append(Vector2i(p.x - 1, p.y + y))
		_:
			for x in s.x:
				out.append(Vector2i(p.x + x, p.y - 1))
	return out


## The output tile sits on the front edge. For even sizes it is the tile that
## rotates with the building (the "upper" tile when facing east), so rotating a
## layout keeps every output aligned with its belt.
static func output_cell_for(p: Vector2i, s: Vector2i, r: int) -> Vector2i:
	match posmod(r, 4):
		0:
			return Vector2i(p.x + s.x, p.y + (s.y - 1) / 2)
		1:
			return Vector2i(p.x + s.x / 2, p.y + s.y)
		2:
			return Vector2i(p.x - 1, p.y + s.y / 2)
		_:
			return Vector2i(p.x + (s.x - 1) / 2, p.y - 1)


## Distance from a point to this building's footprint rectangle.
func dist_to(p: Vector2) -> float:
	var dx := maxf(maxf(pos.x - p.x, 0.0), p.x - (pos.x + size.x))
	var dy := maxf(maxf(pos.y - p.y, 0.0), p.y - (pos.y + size.y))
	return sqrt(dx * dx + dy * dy)


func closest_point(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, pos.x, pos.x + size.x), clampf(p.y, pos.y, pos.y + size.y))


func status_level() -> int:
	return int(STATUS_LEVEL.get(status, 1))


func to_dict() -> Dictionary:
	var d := {
		"id": id, "type": type, "x": pos.x, "y": pos.y, "rot": rot, "hp": hp, "en": enabled,
		"inv": inv, "out": out, "recipe": recipe, "prog": progress, "craft": crafting,
		"energy": energy, "cd": cooldown, "rounds": rounds, "target": target, "scan": scan, "pull": pull_cd, "rr": rr,
		"status": status, "dmg": last_damaged,
	}
	if kind == "belt":
		d["belt"] = belt_items
	if kind == "splitter":
		d["filter"] = filter.duplicate()
	return d


func load_dict(d: Dictionary) -> void:
	hp = float(d.get("hp", max_hp))
	enabled = bool(d.get("en", true))
	inv = Items.from_json(d.get("inv", {}))
	out = Items.from_json(d.get("out", {}))
	recipe = str(d.get("recipe", recipe))
	progress = float(d.get("prog", 0.0))
	crafting = bool(d.get("craft", false))
	energy = float(d.get("energy", 0.0))
	cooldown = float(d.get("cd", 0.0))
	rounds = int(d.get("rounds", 0))
	target = int(d.get("target", 0))
	scan = float(d.get("scan", 0.0))
	pull_cd = float(d.get("pull", 0.0))
	rr = int(d.get("rr", 0))
	status = str(d.get("status", ""))
	last_damaged = float(d.get("dmg", -100.0))
	var f: Array = d.get("filter", ["", "", ""])
	filter = [str(f[0]), str(f[1]), str(f[2])]
	belt_items = []
	for it in d.get("belt", []):
		belt_items.append([str(it[0]), float(it[1])])
