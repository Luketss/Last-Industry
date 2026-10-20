extends RefCounted
## Blueprints: copy a group of structures (with rotation and recipes), rotate the
## group in 90° steps and paste it elsewhere. Pure data, so it is testable headless.

const Building = preload("res://src/sim/building.gd")
const Items = preload("res://src/sim/items.gd")


## Captures the given building ids, relative to their bounding box. The core is skipped.
static func capture(w, ids: Array) -> Dictionary:
	var bs := []
	for id in ids:
		var b = w.buildings.get(id)
		if b != null and b.kind != "core":
			bs.append(b)
	if bs.is_empty():
		return {}
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for b in bs:
		lo = Vector2i(mini(lo.x, b.pos.x), mini(lo.y, b.pos.y))
		hi = Vector2i(maxi(hi.x, b.pos.x + b.size.x), maxi(hi.y, b.pos.y + b.size.y))
	var entries := []
	for b in bs:
		entries.append({"type": b.type, "x": b.pos.x - lo.x, "y": b.pos.y - lo.y, "rot": b.rot,
			"recipe": b.recipe, "enabled": b.enabled, "filter": b.filter.duplicate()})
	return {"w": hi.x - lo.x, "h": hi.y - lo.y, "entries": entries}


## Rotates a blueprint 90° clockwise (east becomes south).
static func rotated(w, bp: Dictionary) -> Dictionary:
	var out := []
	for e in bp.entries:
		var s := Building.footprint(w.data.buildings[e.type], int(e.rot))
		var ne: Dictionary = e.duplicate()
		ne.x = int(bp.h) - (int(e.y) + s.y)
		ne.y = int(e.x)
		ne.rot = posmod(int(e.rot) + 1, 4)
		out.append(ne)
	return {"w": bp.h, "h": bp.w, "entries": out}


static func cost(w, bp: Dictionary) -> Dictionary:
	var c := {}
	for e in bp.get("entries", []):
		var bc: Dictionary = w.data.buildings[e.type].get("cost", {})
		for k in bc:
			Items.add(c, k, int(bc[k]))
	return c


## Places every entry that fits at `origin`. Returns [placed, skipped].
static func paste(w, bp: Dictionary, origin: Vector2i) -> Array:
	var placed := 0
	var skipped := 0
	for e in bp.get("entries", []):
		var id: int = w.place(e.type, origin + Vector2i(int(e.x), int(e.y)), int(e.rot), false, str(e.recipe))
		if id == 0:
			skipped += 1
			continue
		placed += 1
		w.buildings[id].enabled = bool(e.get("enabled", true))
		if e.has("filter"):
			w.set_filters(w.buildings[id], e.filter)
	return [placed, skipped]


## Per-entry validity at `origin` (for previews): Array of [entry, reason].
static func check(w, bp: Dictionary, origin: Vector2i) -> Array:
	var r := []
	for e in bp.get("entries", []):
		r.append([e, w.can_place(e.type, origin + Vector2i(int(e.x), int(e.y)), int(e.rot), false)])
	return r
