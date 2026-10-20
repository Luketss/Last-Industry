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
var dist: Array = []             ## per profile PackedFloat32Array
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


func _dijkstra(en: PackedFloat32Array, goals: Array, n: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(n)
	d.fill(Defs.INF)
	var hk := PackedFloat32Array()   # heap keys
	var hv := PackedInt32Array()     # heap values
	for g in goals:
		d[g] = 0.0
		_push(hk, hv, 0.0, g)
	while hv.size() > 0:
		var du := hk[0]
		var u := hv[0]
		_pop(hk, hv)
		if du > d[u]:
			continue
		var nd := du + en[u]
		var ux := u % _w
		var uy := u / _w
		for k in 4:
			var vx := ux + (1 if k == 0 else (-1 if k == 1 else 0))
			var vy := uy + (1 if k == 2 else (-1 if k == 3 else 0))
			if vx < 0 or vy < 0 or vx >= _w or vy >= _h:
				continue
			var v := vy * _w + vx
			if en[v] >= Defs.INF or en[v] == 0.0:
				continue
			if nd < d[v]:
				d[v] = nd
				_push(hk, hv, nd, v)
	return d


static func _push(hk: PackedFloat32Array, hv: PackedInt32Array, k: float, v: int) -> void:
	hk.append(k)
	hv.append(v)
	var i := hk.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if hk[p] <= hk[i]:
			break
		var tk := hk[p]
		hk[p] = hk[i]
		hk[i] = tk
		var tv := hv[p]
		hv[p] = hv[i]
		hv[i] = tv
		i = p


static func _pop(hk: PackedFloat32Array, hv: PackedInt32Array) -> void:
	var last := hk.size() - 1
	hk[0] = hk[last]
	hv[0] = hv[last]
	hk.resize(last)
	hv.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < last and hk[l] < hk[m]:
			m = l
		if r < last and hk[r] < hk[m]:
			m = r
		if m == i:
			break
		var tk := hk[m]
		hk[m] = hk[i]
		hk[i] = tk
		var tv := hv[m]
		hv[m] = hv[i]
		hv[i] = tv
		i = m


## Next cell an enemy of `profile` standing on `c` should step into.
## Returns Vector2i(-1, -1) when no route exists.
func next_cell(profile: int, c: Vector2i) -> Vector2i:
	if dist.is_empty() or c.x < 0 or c.y < 0 or c.x >= _w or c.y >= _h:
		return Vector2i(-1, -1)
	var d: PackedFloat32Array = dist[profile]
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
