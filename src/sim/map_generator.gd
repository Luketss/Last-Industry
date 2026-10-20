extends RefCounted
## Procedural map: ruins (impassable), two mineral types and enemy nests at the edges.

const Defs = preload("res://src/sim/defs.gd")


static func generate(w, p_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var noise := FastNoiseLite.new()
	noise.seed = p_seed
	noise.frequency = 0.09
	var center := Vector2(w.width * 0.5, w.height * 0.5)
	for y in w.height:
		for x in w.width:
			var c := Vector2i(x, y)
			var d := Vector2(c).distance_to(center)
			if d > 9.0 and noise.get_noise_2d(x, y) > 0.38:
				w.set_terrain(c, Defs.T_ROCK)

	# Starter deposits close to the core, richer ones further away (expansion pressure).
	var base_angle := rng.randf() * TAU
	_patch(w, rng, center + Vector2.from_angle(base_angle) * 8.0, 2.6, Defs.T_IRON, 350, 600)
	_patch(w, rng, center + Vector2.from_angle(base_angle + PI * 0.75) * 8.0, 2.2, Defs.T_COAL, 300, 500)
	for i in 2:
		var a := base_angle + PI + (i - 0.5) * 1.6 + rng.randf_range(-0.3, 0.3)
		_patch(w, rng, center + Vector2.from_angle(a) * rng.randf_range(17.0, 25.0), 3.4, Defs.T_IRON, 700, 1200)
		var a2 := base_angle + (i - 0.5) * 2.4 + rng.randf_range(-0.3, 0.3)
		_patch(w, rng, center + Vector2.from_angle(a2) * rng.randf_range(16.0, 24.0), 3.0, Defs.T_COAL, 600, 1000)

	# Two rare crystal deposits near the edges, opposite each other: Genesis needs them,
	# so the factory has to reach out through the fog.
	var ca := base_angle + PI * 0.5 + rng.randf_range(-0.4, 0.4)
	for k in 2:
		var reach := minf(center.x, center.y) - rng.randf_range(6.0, 8.0)
		_patch(w, rng, center + Vector2.from_angle(ca + PI * k) * reach, 2.0, Defs.T_CRYSTAL, 250, 400)

	# Keep the starting area clear.
	for y in range(-6, 7):
		for x in range(-6, 7):
			var c := Vector2i(int(center.x) + x, int(center.y) + y)
			if w.in_bounds(c) and w.terrain_at(c) == Defs.T_ROCK:
				w.set_terrain(c, Defs.T_GROUND)

	# Four nests, one per edge.
	w.spawn_points = []
	var m := 2
	var jit := int(w.width * 0.25)
	var candidates := [
		Vector2i(w.width / 2 + rng.randi_range(-jit, jit), m),
		Vector2i(w.width - 1 - m, w.height / 2 + rng.randi_range(-jit, jit)),
		Vector2i(w.width / 2 + rng.randi_range(-jit, jit), w.height - 1 - m),
		Vector2i(m, w.height / 2 + rng.randi_range(-jit, jit)),
	]
	for sp in candidates:
		for y in range(-3, 4):
			for x in range(-3, 4):
				var c: Vector2i = sp + Vector2i(x, y)
				if w.in_bounds(c):
					w.set_terrain(c, Defs.T_GROUND)
		_ensure_corridor(w, sp, Vector2i(center))
		w.spawn_points.append(sp)


static func _patch(w, rng: RandomNumberGenerator, at: Vector2, radius: float, t: int, lo: int, hi: int) -> void:
	var r := int(ceil(radius)) + 1
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var c := Vector2i(int(at.x) + x, int(at.y) + y)
			if not w.in_bounds(c):
				continue
			var d := Vector2(x, y).length() + rng.randf_range(-0.6, 0.6)
			if d <= radius:
				w.set_terrain(c, t, rng.randi_range(lo, hi))


## Guarantees every nest can reach the core by carving a path through ruins.
static func _ensure_corridor(w, from: Vector2i, to: Vector2i) -> void:
	var c := from
	while c != to:
		var d := to - c
		if absi(d.x) >= absi(d.y):
			c.x += signi(d.x)
		else:
			c.y += signi(d.y)
		if w.terrain_at(c) == Defs.T_ROCK:
			w.set_terrain(c, Defs.T_GROUND)


## Four data terminals on open ground next to ruins, one per quadrant, away from
## the core and the nests.
static func place_terminals(w, p_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed + 911
	var center := Vector2(w.width * 0.5, w.height * 0.5)
	var n := 1
	for q in 4:
		var best := Vector2i(-1, -1)
		for attempt in 200:
			var a := (q + rng.randf()) * PI * 0.5
			var c := Vector2i(center + Vector2.from_angle(a) * rng.randf_range(13.0, minf(center.x, center.y) - 6.0))
			if not w.in_bounds(c) or w.terrain_at(c) != Defs.T_GROUND:
				continue
			var near_rock := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if w.in_bounds(c + d) and w.terrain_at(c + d) == Defs.T_ROCK:
					near_rock = true
			var far_from_nests := true
			for sp in w.spawn_points:
				if Vector2(sp).distance_to(Vector2(c)) < 8.0:
					far_from_nests = false
			if far_from_nests and (near_rock or attempt > 150):
				best = c
				break
		if best.x >= 0:
			w.terminals[w.idx(best)] = {"n": n, "read": false}
			n += 1
