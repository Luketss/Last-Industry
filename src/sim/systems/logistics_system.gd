extends RefCounted
## Item flow: belts, machine outputs, splitters and adjacent pulling.
##
## Distribution rules:
## - A belt delivers its front item to whatever is in front of it (belt or building).
## - Machines push finished items out of their output side (arrow).
## - Turrets, generators and repair stations also PULL the items they need from any
##   belt touching them, so a single supply line can run past a row of defenses.

const Defs = preload("res://src/sim/defs.gd")
const Items = preload("res://src/sim/items.gd")

var dirty := true


func rebuild(w) -> void:
	dirty = false
	for b in w.list("pullers"):
		b.adj_belts = []
		for c in _ring(b):
			var n = w.building_at(c)
			if n != null and n.kind == "belt" and not (n.id in b.adj_belts):
				b.adj_belts.append(n.id)


static func _ring(b) -> Array:
	var r := []
	for x in b.size.x:
		r.append(Vector2i(b.pos.x + x, b.pos.y - 1))
		r.append(Vector2i(b.pos.x + x, b.pos.y + b.size.y))
	for y in b.size.y:
		r.append(Vector2i(b.pos.x - 1, b.pos.y + y))
		r.append(Vector2i(b.pos.x + b.size.x, b.pos.y + y))
	return r


func step(w, dt: float) -> void:
	_push_outputs(w)
	_move_belts(w, dt)
	_pull(w, dt)


func _push_outputs(w) -> void:
	for b in w.list("outputters"):
		var src: Dictionary = b.inv if b.kind == "depot" else b.out
		if src.is_empty():
			continue
		var targets: Array
		if b.kind == "splitter":
			targets = [b.pos + Defs.dir_vec(b.rot - 1), b.pos + Defs.dir_vec(b.rot), b.pos + Defs.dir_vec(b.rot + 1)]
		else:
			targets = [b.output_cell()]
		var keys := src.keys()
		var item: String = keys[w.tick % keys.size()]
		for attempt in targets.size():
			var ti: int = (b.rr + attempt) % targets.size()
			if deliver(w, b, targets[ti], item):
				Items.take(src, item, 1)
				b.rr = ti + 1
				break


## Deliver one item from `src` (a building) into the cell `c`.
func deliver(w, src, c: Vector2i, item: String) -> bool:
	var t = w.building_at(c)
	if t == null or t == src:
		return false
	if t.kind == "belt":
		if src.contains(t.pos + Defs.dir_vec(t.rot)):
			return false
		return belt_accept(t, item)
	if t.kind == "miner":
		return false
	return w.try_insert(t, item)


static func belt_accept(belt, item: String) -> bool:
	var items: Array = belt.belt_items
	if items.is_empty() or float(items[items.size() - 1][1]) >= Defs.BELT_SPACING:
		items.append([item, 0.0])
		return true
	return false


func _move_belts(w, dt: float) -> void:
	for b in w.list("belt"):
		var items: Array = b.belt_items
		if items.is_empty():
			b.status = ""
			continue
		var adv := float(b.def.get("speed", 2.0)) * dt
		var limit := 1.0
		var k := 0
		var blocked := false
		while k < items.size():
			var it: Array = items[k]
			var np := minf(float(it[1]) + adv, limit)
			if k == 0 and np >= 1.0:
				if _transfer(w, b, it[0]):
					items.remove_at(0)
					continue
				np = 1.0
				blocked = true
			if np > float(it[1]):
				it[1] = np
			limit = float(it[1]) - Defs.BELT_SPACING
			k += 1
		b.status = "saída bloqueada" if blocked and items.size() >= 4 else ""


func _transfer(w, belt, item: String) -> bool:
	var c: Vector2i = belt.pos + Defs.dir_vec(belt.rot)
	var t = w.building_at(c)
	if t == null:
		return false
	if t.kind == "belt":
		if t.pos + Defs.dir_vec(t.rot) == belt.pos:
			return false
		return belt_accept(t, item)
	if t.kind == "miner":
		return false
	return w.try_insert(t, item)


func _pull(w, dt: float) -> void:
	for b in w.list("pullers"):
		if b.adj_belts.is_empty() or not b.enabled:
			continue
		b.scan -= dt
		if b.scan > 0.0:
			continue
		b.scan = 0.25
		var acc: Dictionary = b.def.get("accepts", {})
		for item in acc:
			if Items.count(b.inv, item) >= int(acc[item]):
				continue
			if _pull_one(w, b, item):
				break


func _pull_one(w, b, item: String) -> bool:
	for bid in b.adj_belts:
		var belt = w.buildings.get(bid)
		if belt == null:
			continue
		var items: Array = belt.belt_items
		for k in items.size():
			if items[k][0] == item:
				items.remove_at(k)
				Items.add(b.inv, item, 1)
				return true
	return false
