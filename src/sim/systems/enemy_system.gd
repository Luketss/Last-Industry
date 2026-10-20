extends RefCounted
## Enemy behaviour: follow the flow field, attack whatever blocks the route,
## opportunistically bite nearby structures (aggro) and deal splash damage.

const Defs = preload("res://src/sim/defs.gd")


func step(w, dt: float) -> void:
	for e in w.enemies.values():
		if e.dead:
			continue
		e.cooldown = maxf(e.cooldown - dt, 0.0)
		if e.think > 0.0:
			e.think -= dt
		var def: Dictionary = e.def
		var tb = w.buildings.get(e.target) if e.target != 0 else null
		if tb == null:
			e.target = 0
		var aggro := float(def.get("aggro", 0.0))
		if tb == null and aggro > 0.0 and e.think <= 0.0:
			e.think = 0.5
			tb = _nearest_building(w, e.pos, aggro)
			if tb != null:
				e.target = tb.id
		if tb != null:
			if tb.dist_to(e.pos) <= float(def.reach) * e.size_mult:
				_attack(w, e, tb)
			else:
				_move_toward(e, tb.closest_point(e.pos), _speed(e) * dt)
			continue
		var cell := Vector2i(floori(e.pos.x), floori(e.pos.y))
		var here = w.building_at(cell)
		if here != null:
			e.target = here.id
			continue
		var nxt: Vector2i = w.pathing.next_cell(e.profile, cell)
		if nxt.x < 0:
			var c = w.core()
			if c != null:
				e.target = c.id
			continue
		var nb = w.building_at(nxt)
		if nb != null:
			e.target = nb.id
			continue
		_move_toward(e, Vector2(nxt) + Vector2(0.5, 0.5) + e.offset, _speed(e) * dt)


static func _speed(e) -> float:
	return float(e.def.speed) / sqrt(e.size_mult)


static func _move_toward(e, p: Vector2, step_len: float) -> void:
	var d: Vector2 = p - e.pos
	var l: float = d.length()
	if l < 0.0001:
		return
	e.facing = atan2(d.y, d.x)
	e.pos += d / l * minf(step_len, l)


func _attack(w, e, tb) -> void:
	var cp = tb.closest_point(e.pos) - e.pos
	if cp.length_squared() > 0.0001:
		e.facing = atan2(cp.y, cp.x)
	if e.cooldown > 0.0:
		return
	e.cooldown = float(e.def.attack_cd)
	var dmg: float = float(e.def.damage) * e.damage_mult
	if tb.kind == "wall":
		dmg *= float(e.def.get("wall_mult", 1.0))
	var splash := float(e.def.get("splash", 0.0))
	w.events.append({"e": "bite", "pos": e.pos, "splash": splash > 0.0})
	if splash > 0.0:
		var hit := {}
		var c := Vector2i(floori(e.pos.x), floori(e.pos.y))
		var r := int(ceil(splash)) + 1
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var b = w.building_at(c + Vector2i(x, y))
				if b != null and b != tb and not hit.has(b.id) and b.dist_to(e.pos) <= splash:
					hit[b.id] = b
		for b in hit.values():
			w.damage_building(b, dmg * 0.5)
	w.damage_building(tb, dmg)


static func _nearest_building(w, p: Vector2, radius: float):
	var c := Vector2i(floori(p.x), floori(p.y))
	var r := int(ceil(radius)) + 1
	var best = null
	var bd := radius
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var b = w.building_at(c + Vector2i(x, y))
			if b == null or b.kind == "wall":
				continue
			var d: float = b.dist_to(p)
			if d <= bd:
				bd = d
				best = b
	return best
