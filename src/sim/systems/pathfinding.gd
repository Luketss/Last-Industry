extends RefCounted
## Flow fields toward the core, one per path profile.
##
## Every enemy type has a `wall_weight`: the cost of entering a cell occupied by a
## structure is 1 + max_hp / 50 * wall_weight. Low weights (Aríete) plough through
## walls; high weights (Corredor) search for gaps. Ruins are impassable.
## Fields depend only on the structure layout, so they are fully reproducible.

const Defs = preload("res://src/sim/defs.gd")

var dirty := true
var cooldown := 0.0
var version := 0
var weights: Array = []          ## per profile
var _profile_of := {}            ## enemy type -> profile index
var dist: Array = []             ## per profile PackedFloat64Array
var enter: Array = []            ## per profile PackedFloat32Array
var _w := 0
var _h := 0


func _init(data) -> void:
	for type in data.enemies:
		var wt := float(data.enemies[type].get("wall_weight", 1.0))
		var p := weights.find(wt)
		if p == -1:
			p = weights.size()
			weights.append(wt)
		_profile_of[type] = p


func profile_of(type: String) -> int:
	return int(_profile_of.get(type, 0))


func update(w, dt: float) -> void:
	cooldown -= dt
	if dirty and cooldown <= 0.0:
		rebuild(w)
		cooldown = 0.5


func rebuild(w) -> void:
	dirty = false
	version += 1
	_w = w.width
	_h = w.height
	var n: int = _w * _h
	dist = []
	enter = []
	for p in weights.size():
		var en := PackedFloat32Array()
		en.resize(n)
		var goals := []
		for i in n:
			if w.terrain[i] == Defs.T_ROCK:
				en[i] = Defs.INF
				continue
			var id: int = w.grid[i]
			if id == 0:
				en[i] = 1.0
				continue
			var b = w.buildings[id]
			if b.kind == "core":
				en[i] = 0.0
				goals.append(i)
			else:
				en[i] = 1.0 + b.max_hp / 50.0 * float(weights[p])
		enter.append(en)
		dist.append(_dijkstra(en, goals, n))


## Dijkstra over the grid with an inline binary heap. Distances and heap keys are
## float64: with float32 storage, rounding made settled cells look improvable and
## large bases re-expanded cells in cascades (seconds per rebuild).
func _dijkstra(en: PackedFloat32Array, goals: Array, n: int) -> PackedFloat64Array:
	var d := PackedFloat64Array()
	d.resize(n)
	d.fill(Defs.INF)
	var cap := n * 4 + 16
	var hk := PackedFloat64Array()
	var hv := PackedInt32Array()
	hk.resize(cap)
	hv.resize(cap)
	var size := 0
	for g in goals:
		d[g] = 0.0
		hk[size] = 0.0
		hv[size] = g
		size += 1
	var w := _w
	var h := _h
	while size > 0:
		var du := hk[0]
		var u := hv[0]
		# pop
		size -= 1
		var lk := hk[size]
		var lv := hv[size]
		var i := 0
		while true:
			var l := i * 2 + 1
			if l >= size:
				break
			var r := l + 1
			var m := l
			if r < size and hk[r] < hk[l]:
				m = r
			if hk[m] >= lk:
				break
			hk[i] = hk[m]
			hv[i] = hv[m]
			i = m
		if size > 0:
			hk[i] = lk
			hv[i] = lv
		if du > d[u]:
			continue
		var nd := du + en[u]
		var ux := u % w
		var uy := u / w
		for k in 4:
			var vx := ux
			var vy := uy
			match k:
				0: vx += 1
				1: vx -= 1
				2: vy += 1
				_: vy -= 1
			if vx < 0 or vy < 0 or vx >= w or vy >= h:
				continue
			var v := vy * w + vx
			var ev := en[v]
			if ev >= Defs.INF or ev == 0.0 or nd >= d[v]:
				continue
			d[v] = nd
			# push
			if size >= cap:
				cap *= 2
				hk.resize(cap)
				hv.resize(cap)
			var j := size
			size += 1
			while j > 0:
				var p := (j - 1) >> 1
				if hk[p] <= nd:
					break
				hk[j] = hk[p]
				hv[j] = hv[p]
				j = p
			hk[j] = nd
			hv[j] = v
	return d


## Next cell an enemy of `profile` standing on `c` should step into.
## Returns Vector2i(-1, -1) when no route exists.
func next_cell(profile: int, c: Vector2i) -> Vector2i:
	if dist.is_empty() or c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _h:
		return Vector2i(-1, -1)
	var d: PackedFloat64Array = dist[profile]
	var en: PackedFloat32Array = enter[profile]
	var best := Defs.INF
	var bc := Vector2i(-1, -1)
	for dir in Defs.DIRS:
		var nc: Vector2i = c + dir
		if nc.x < 0 or nc.y < 0 or nc.x >= _w or nc.y >= _h:
			continue
		var i := nc.y * _w + nc.x
		if en[i] >= Defs.INF:
			continue
		var v := d[i] + en[i]
		if v < best:
			best = v
			bc = nc
	return bc


func distance(profile: int, c: Vector2i) -> float:
	if dist.is_empty():
		return Defs.INF
	return dist[profile][c.y * _w + c.x]
