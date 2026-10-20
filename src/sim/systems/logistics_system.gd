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
			targets = b.output_cells()
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


## A belt whose front item is blocked and whose items cannot advance sleeps for
## SLEEP seconds (stored in `cooldown`) instead of retrying every tick. This keeps
## large saturated bases cheap; a freed destination is picked up within SLEEP.
const SLEEP := 0.2


func _move_belts(w, dt: float) -> void:
	var speed_mult: float = 1.0 + w.research.mod("belt_speed")
	for b in w.list("belt"):
		var items: Array = b.belt_items
		if items.is_empty():
			b.status = ""
			continue
		if b.cooldown > 0.0:
			b.cooldown -= dt
			continue
		var adv: float = float(b.def.get("speed", 2.0)) * speed_mult * dt
		var limit := 1.0
		var k := 0
		var blocked := false
		var moved := false
		while k < items.size():
			var it: Array = items[k]
			var np := minf(float(it[1]) + adv, limit)
			if k == 0 and np >= 1.0:
				if _transfer(w, b, it[0]):
					items.remove_at(0)
					moved = true
					continue
				np = 1.0
				blocked = true
			if np > float(it[1]):
				it[1] = np
				moved = true
			limit = float(it[1]) - Defs.BELT_SPACING
			k += 1
		if blocked and not moved:
			b.cooldown = SLEEP
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


# --- tracing (diagnostics) ---------------------------------------------------

## Item flow graph: building id -> ids it delivers to. Used to trace where a
## structure's inputs come from and where its outputs go.
func flow_graph(w) -> Dictionary:
	var g := {}
	for b in w.buildings.values():
		var dst := []
		if b.kind == "belt":
			var t = w.building_at(b.pos + Defs.dir_vec(b.rot))
			if t != null and t.kind != "miner" and not (t.kind == "belt" and t.pos + Defs.dir_vec(t.rot) == b.pos):
				dst.append(t.id)
		elif b.kind in ["miner", "crafter", "depot", "splitter"]:
			var cells: Array = b.output_cells()
			if b.kind == "splitter":
				cells = [b.pos + Defs.dir_vec(b.rot - 1), b.pos + Defs.dir_vec(b.rot), b.pos + Defs.dir_vec(b.rot + 1)]
			for c in cells:
				var t = w.building_at(c)
				if t != null and t != b and t.kind != "miner" and not (t.kind == "belt" and b.contains(t.pos + Defs.dir_vec(t.rot))):
					dst.append(t.id)
		g[b.id] = dst
	for p in w.list("pullers"):
		for bid in p.adj_belts:
			if g.has(bid) and not (p.id in g[bid]):
				g[bid].append(p.id)
	return g


## Ids reachable from `id` following the flow (downstream) or against it (upstream).
func trace(w, id: int, upstream: bool, limit: int = 600) -> Array:
	var g := flow_graph(w)
	if upstream:
		var rev := {}
		for src in g:
			for dst in g[src]:
				if not rev.has(dst):
					rev[dst] = []
				rev[dst].append(src)
		g = rev
	var seen := {id: true}
	var queue := [id]
	var out := []
	while not queue.is_empty() and out.size() < limit:
		var cur: int = queue.pop_front()
		for nxt in g.get(cur, []):
			if not seen.has(nxt):
				seen[nxt] = true
				out.append(nxt)
				# The core is a sink: do not trace through it.
				var nb = w.buildings.get(nxt)
				if nb != null and nb.kind != "core":
					queue.append(nxt)
	return out


## Visual/diagnostic shape of a belt: 0 straight, -1 curve fed from its left,
## +1 curve fed from its right. A belt is a curve when nothing feeds it from behind
## and exactly one side feeds it (a belt, or a machine whose front faces it).
static func belt_shape(w, b) -> int:
	return shape_at(w, b.pos, b.rot)


## Shape a belt at `p` facing `rot` has (or would have, for placement previews).
static func shape_at(w, p: Vector2i, rot: int) -> int:
	var back: Vector2i = p - Defs.dir_vec(rot)
	if _feeds(w, back, p):
		return 0
	var left: bool = _feeds(w, p + Defs.dir_vec(rot - 1), p)
	var right: bool = _feeds(w, p + Defs.dir_vec(rot + 1), p)
	if left and not right:
		return -1
	if right and not left:
		return 1
	return 0


## Whether whatever stands at `from` sends items into the tile `to`.
static func _feeds(w, from: Vector2i, to: Vector2i) -> bool:
	var s = w.building_at(from)
	if s == null:
		return false
	if s.kind == "belt":
		return s.pos + Defs.dir_vec(s.rot) == to
	if s.kind in ["miner", "crafter", "depot"]:
		return to in s.output_cells()
	if s.kind == "splitter":
		for r in [s.rot - 1, s.rot, s.rot + 1]:
			if s.pos + Defs.dir_vec(r) == to:
				return true
	return false


## True when a belt's front tile cannot take its items (nothing there, a miner,
## or a belt pointing back at it). Shown as a red end marker.
static func belt_dead_end(w, b) -> bool:
	var t = w.building_at(b.pos + Defs.dir_vec(b.rot))
	if t == null or t.kind == "miner":
		return true
	if t.kind == "belt":
		return t.pos + Defs.dir_vec(t.rot) == b.pos
	return false


func _pull(w, dt: float) -> void:
	for b in w.list("pullers"):
		if b.adj_belts.is_empty() or not b.enabled:
			continue
		b.pull_cd -= dt
		if b.pull_cd > 0.0:
			continue
		b.pull_cd = 0.25
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
