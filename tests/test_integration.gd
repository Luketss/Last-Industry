extends "res://tests/test_base.gd"
## End-to-end scenarios that exercise several systems together.


## Full ammo chain on one map: ore -> smelter -> assembler (+coal) -> belt past turrets,
## with a coal generator. Verifies production feeds the defense without manual help.
func test_full_ammo_chain_feeds_turrets() -> void:
	var w = empty_world({"width": 40, "height": 40, "spawns": [Vector2i(1, 1)]})
	for y in [10, 11]:
		for x in [4, 5]:
			w.set_terrain(Vector2i(x, y), Defs.T_IRON, 999)
			w.set_terrain(Vector2i(x, y + 6), Defs.T_COAL, 999)
	w.place("pole", Vector2i(7, 13), 0)
	w.place("pole", Vector2i(13, 13), 0)
	w.place("pole", Vector2i(19, 15), 0)
	w.place("pole", Vector2i(6, 18), 0)
	# Iron: miner -> belt -> smelter -> belt -> assembler (west input)
	w.place("miner", Vector2i(4, 10), 0)          # out (6,10)
	w.place("belt", Vector2i(6, 10), 0)
	w.place("smelter", Vector2i(7, 10), 0)        # out (9,10)
	w.place("belt", Vector2i(9, 10), 0)
	w.place("belt", Vector2i(10, 10), 0)
	w.place("assembler", Vector2i(11, 10), 0)     # out (13,10)
	# Coal: miner -> belt east -> generator pulls, then north into assembler bottom
	w.place("miner", Vector2i(4, 16), 0)          # out (6,16)
	for x in range(6, 11):
		w.place("belt", Vector2i(x, 16), 0)
	w.place("generator", Vector2i(7, 17), 0)      # touches belts at y=16
	w.place("belt", Vector2i(11, 16), 3)
	w.place("belt", Vector2i(11, 15), 3)
	w.place("belt", Vector2i(11, 14), 3)
	w.place("belt", Vector2i(11, 13), 3)
	w.place("belt", Vector2i(11, 12), 3)          # into assembler (11..12, 10..11)
	# Ammo line runs past two turrets and ends in the core.
	for x in range(13, 18):
		w.place("belt", Vector2i(x, 10), 0)
	w.place("belt", Vector2i(18, 10), 1)
	for y in range(11, 16):
		w.place("belt", Vector2i(18, y), 1)
	var t1: int = w.place("turret_gun", Vector2i(14, 8), 0)
	var t2: int = w.place("turret_gun", Vector2i(16, 11), 0)
	run_seconds(w, 120.0)
	check(w.stats.burned > 0, "gerador queimou carvão")
	check(w.stats.produced.get("ammo", 0) >= 10, "munição produzida: %d" % w.stats.produced.get("ammo", 0))
	var loaded: int = w.buildings[t1].rounds + w.buildings[t1].inv.get("ammo", 0) * 10
	var loaded2: int = w.buildings[t2].rounds + w.buildings[t2].inv.get("ammo", 0) * 10
	check(loaded > 0 and loaded2 > 0, "ambas as torres abastecidas automaticamente (%d, %d)" % [loaded, loaded2])


## Early campaign waves against a modest, supplied defense.
func test_basic_defense_survives_first_waves() -> void:
	var real: Dictionary = data().waves.duplicate(true)
	real.first_delay = 5.0
	real.interval = 50.0
	real.waves = real.waves.slice(0, 3)
	var w = empty_world({"width": 48, "height": 48, "spawns": [Vector2i(2, 24)], "waves": real})
	var c: Vector2i = w.core().pos
	var dep: int = w.place("depot", c + Vector2i(-2, -5), 3)
	w.buildings[dep].inv = {"ammo": 100}
	# Depot outputs north into a belt that runs west past two turrets.
	w.place("belt", c + Vector2i(-2, -6), 2)
	for x in range(-8, -2):
		w.place("belt", c + Vector2i(x, -6), 2)
	w.place("turret_gun", c + Vector2i(-6, -8), 0)
	w.place("turret_gun", c + Vector2i(-6, -5), 0)
	w.place("turret_tesla", c + Vector2i(-6, 3), 0)
	w.place("pole", c + Vector2i(-4, 1), 0)
	for y in range(-4, 7):
		w.place("wall", c + Vector2i(-9, y), 0)
	run_seconds(w, 200.0)
	eq(w.state, "won", "defesa sobreviveu às 3 primeiras hordas")
	check(w.core().hp > w.core().max_hp * 0.8, "núcleo preservado")


func test_simulation_performance_budget() -> void:
	var w = World.new(data(), 3)
	var c: Vector2i = w.core().pos
	w.storage = {"iron_plate": 100000, "gear": 100000}
	# 300 belts full of items and 150 enemies.
	for y in range(-20, -5):
		for x in range(-10, 10):
			var id: int = w.place("belt", c + Vector2i(x, y), 0)
			if id:
				w.buildings[id].belt_items = [["iron_plate", 0.9], ["iron_plate", 0.6], ["iron_plate", 0.3]]
	for i in 150:
		w.spawn_enemy("crawler", Vector2(w.spawn_points[i % 4]) + Vector2(0.5, 0.5))
	w.pathing.rebuild(w)
	var t0 := Time.get_ticks_usec()
	run_ticks(w, 100)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 100.0
	print("     desempenho: %.2f ms/tick (%d estruturas, %d inimigos)" % [ms, w.buildings.size(), w.enemies.size()])
	check(ms < 25.0, "tick abaixo de 25 ms (%.2f)" % ms)
