extends "res://tests/test_base.gd"


func test_wave_spawns_and_victory() -> void:
	var w = empty_world({"waves": {"first_delay": 2.0, "interval": 5.0, "spawn_gap": 0.1,
		"waves": [{"groups": [{"type": "crawler", "count": 3}]}]}})
	var t: int = w.place("turret_gun", Vector2i(10, 15), 0)
	w.buildings[t].inv = {"ammo": 8}
	run_seconds(w, 3.0)
	eq(w.waves.index, 1, "onda iniciada")
	check(not w.enemies.is_empty(), "inimigos surgiram")
	run_seconds(w, 30.0)
	eq(w.state, "won", "vitória após a última onda")
	eq(w.stats.waves, 1, "onda contada")


func test_survival_waves_scale() -> void:
	var w = empty_world()
	var a: int = 0
	var b: int = 0
	for g in w.waves.wave_def(12).groups:
		a += int(g.count)
	for g in w.waves.wave_def(20).groups:
		b += int(g.count)
	check(b > a, "sobrevivência cresce")


func test_determinism_same_seed() -> void:
	var w1 = World.new(data(), 42)
	var w2 = World.new(data(), 42)
	eq(w1.terrain, w2.terrain, "mapa idêntico")
	w1.waves.timer = 1.0
	w2.waves.timer = 1.0
	run_seconds(w1, 20.0)
	run_seconds(w2, 20.0)
	eq(JSON.stringify(w1.to_dict()), JSON.stringify(w2.to_dict()), "simulação idêntica")


func test_objectives_progress() -> void:
	var w = empty_world()
	eq(w.objectives.current, 0, "primeiro objetivo")
	w.stats.delivered["iron_ore"] = 10
	run_seconds(w, 1.0)
	eq(w.objectives.current, 1, "objetivo avançou")
	check(w.transmissions.size() >= 2, "transmissão narrativa")


func test_generated_map_nests_reach_core() -> void:
	for s in [1, 2, 3, 99]:
		var w = World.new(data(), s)
		w.pathing.rebuild(w)
		for sp in w.spawn_points:
			for p in w.pathing.weights.size():
				check(w.pathing.distance(p, sp) < Defs.INF, "seed %d: ninho %s alcança o núcleo" % [s, str(sp)])
