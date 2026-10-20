extends "res://tests/test_base.gd"


## Builds: iron ore at (4..5, 15..16), miner -> belts east -> core (15..17).
func _ore_line(w, t: int = Defs.T_IRON) -> void:
	for y in [15, 16]:
		for x in [8, 9]:
			w.set_terrain(Vector2i(x, y), t, 500)


func test_miner_belt_core() -> void:
	var w = empty_world()
	_ore_line(w)
	check(w.place("miner", Vector2i(8, 15), 0) > 0, "mineradora")
	w.place("pole", Vector2i(10, 17), 0)
	for x in range(10, 15):
		w.place("belt", Vector2i(x, 15), 0)
	run_seconds(w, 20.0)
	check(w.storage.get("iron_ore", 0) >= 6, "minério chegou ao núcleo: %d" % w.storage.get("iron_ore", 0))


func test_smelter_chain_and_stats() -> void:
	var w = empty_world()
	_ore_line(w)
	w.place("miner", Vector2i(8, 15), 0)
	w.place("pole", Vector2i(10, 17), 0)
	w.place("belt", Vector2i(10, 15), 0)
	w.place("smelter", Vector2i(11, 15), 0)   # output at (13, 15)
	w.place("belt", Vector2i(13, 15), 0)
	w.place("belt", Vector2i(14, 15), 0)
	run_seconds(w, 30.0)
	check(w.stats.delivered.get("iron_plate", 0) >= 5, "placas entregues")
	check(w.stats.produced.get("iron_plate", 0) >= 10, "estatística de produção")
	check(w.stats.rate("iron_plate") > 0, "taxa por minuto")


func test_assembler_ammo_from_two_belts() -> void:
	var w = empty_world({"storage": {"iron_plate": 1000, "gear": 1000}})
	var a: int = w.place("assembler", Vector2i(11, 15), 0)
	eq(w.buildings[a].recipe, "ammo", "receita padrão")
	# Inject items directly through belts pointing into the assembler.
	var b1: int = w.place("belt", Vector2i(10, 15), 0)
	var b2: int = w.place("belt", Vector2i(11, 14), 1)
	w.place("belt", Vector2i(13, 15), 0)
	w.place("belt", Vector2i(14, 15), 0)
	for i in 30:
		w.buildings[b1].belt_items = [["iron_plate", 0.9]]
		w.buildings[b2].belt_items = [["coal", 0.9]]
		run_seconds(w, 1.0)
	check(w.storage.get("ammo", 0) >= 10, "munição produzida e entregue: %d" % w.storage.get("ammo", 0))


func test_machine_reports_missing_input() -> void:
	var w = empty_world()
	var s: int = w.place("smelter", Vector2i(11, 15), 0)
	run_seconds(w, 1.0)
	eq(w.buildings[s].status, "sem insumos", "status de gargalo")


func test_splitter_distributes() -> void:
	var w = empty_world()
	var feed: int = w.place("belt", Vector2i(5, 5), 0)
	w.place("splitter", Vector2i(6, 5), 0)
	var up: int = w.place("belt", Vector2i(6, 4), 3)
	var fw: int = w.place("belt", Vector2i(7, 5), 0)
	var dn: int = w.place("belt", Vector2i(6, 6), 1)
	for i in 9:
		w.buildings[feed].belt_items = [["iron_plate", 0.95]]
		run_ticks(w, 6)
	var counts := [w.buildings[up].belt_items.size(), w.buildings[fw].belt_items.size(), w.buildings[dn].belt_items.size()]
	check(counts[0] > 0 and counts[1] > 0 and counts[2] > 0, "três saídas recebem itens %s" % str(counts))


func test_turret_pulls_from_passing_belt() -> void:
	var w = empty_world()
	var t: int = w.place("turret_gun", Vector2i(6, 6), 0)
	var belt: int = w.place("belt", Vector2i(5, 6), 1)   # runs past (south), not into it
	w.buildings[belt].belt_items = [["ammo", 0.5]]
	run_seconds(w, 1.0)
	eq(w.buildings[t].rounds, 10, "torre puxou munição de esteira adjacente e carregou")
	eq(w.stats.loaded, 1, "estatística de carregamento")


func test_belt_destroyed_cuts_supply() -> void:
	var w = empty_world()
	_ore_line(w)
	w.place("miner", Vector2i(8, 15), 0)
	w.place("pole", Vector2i(10, 17), 0)
	for x in range(10, 15):
		w.place("belt", Vector2i(x, 15), 0)
	w.destroy(w.building_at(Vector2i(12, 15)))
	run_seconds(w, 20.0)
	eq(w.storage.get("iron_ore", 0), 0, "abastecimento interrompido")
	w.rebuild_all_ghosts()
	run_seconds(w, 20.0)
	check(w.storage.get("iron_ore", 0) > 0, "abastecimento restaurado")


func test_blocked_belt_resumes_when_freed() -> void:
	var w = empty_world()
	var a: int = w.place("belt", Vector2i(5, 5), 0)
	var wall: int = w.place("wall", Vector2i(6, 5), 0)
	w.buildings[a].belt_items = [["iron_plate", 0.95]]
	run_seconds(w, 1.0)
	eq(w.buildings[a].belt_items.size(), 1, "item parado diante do bloqueio")
	w.remove(wall)
	w.place("belt", Vector2i(6, 5), 0)
	run_seconds(w, 0.5)
	eq(w.buildings[a].belt_items.size(), 0, "esteira volta a andar após liberar o destino")
