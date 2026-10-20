extends "res://tests/test_base.gd"
## Destructible nests.


func test_turret_destroys_nest_and_spawns_stop() -> void:
	var w = empty_world({"width": 40, "height": 40, "spawns": [Vector2i(10, 20), Vector2i(37, 20)]})
	w.nests.max_hp = 200.0
	w.nests.hp = [200.0, 200.0]
	# A cannon powered by the core, just outside the no-build radius of the west nest.
	w.research.complete(w, "military_1")
	w.research.complete(w, "artillery")
	var t: int = w.place("turret_cannon", Vector2i(15, 19), 0)
	check(t != 0, "torre construída (%s)" % w.can_place("turret_cannon", Vector2i(15, 19), 0))
	w.buildings[t].inv = {"shell": 20}
	var plates: int = int(w.storage.get("iron_plate", 0))
	run_seconds(w, 40.0)
	eq(w.spawn_points.size(), 1, "ninho oeste destruído")
	eq(w.spawn_points[0], Vector2i(37, 20), "o outro continua")
	eq(w.stats.nests, 1, "contado")
	check(int(w.storage.iron_plate) >= plates + 100, "sucata recolhida")
	check(w.waves.next_spawn < w.spawn_points.size(), "próxima horda aponta para um ninho válido")
	var w2 = World.from_dict(data(), w.to_dict())
	eq(w2.spawn_points.size(), 1, "ninhos salvos")
	eq(w2.nests.hp.size(), 1, "integridade salva")


func test_wounded_nest_regrows_and_defends() -> void:
	var w = empty_world({"width": 40, "height": 40, "spawns": [Vector2i(2, 20)]})
	w.nests.damage(w, 0, 500.0)
	var after: float = w.nests.hp[0]
	run_seconds(w, 3.0)
	check(not w.enemies.is_empty(), "ninho ferido manda defensores")
	w.enemies.clear()
	run_seconds(w, 20.0)
	check(w.nests.hp[0] > after, "regenera quando deixa de ser atacado")
