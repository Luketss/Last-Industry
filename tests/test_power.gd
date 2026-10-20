extends "res://tests/test_base.gd"


func test_disconnected_has_no_power() -> void:
	var w = empty_world()
	var s: int = w.place("smelter", Vector2i(2, 2), 0)
	w.buildings[s].inv = {"iron_ore": 2}
	run_seconds(w, 1.0)
	eq(w.buildings[s].power_net, -1, "fora da rede")
	eq(w.buildings[s].status, "sem energia", "sem energia")


func test_poles_extend_network() -> void:
	var w = empty_world()
	w.place("pole", Vector2i(4, 10), 0)
	w.place("pole", Vector2i(10, 12), 0)
	var s: int = w.place("smelter", Vector2i(3, 7), 0)
	w.buildings[s].inv = {"iron_ore": 3}
	run_seconds(w, 3.0)
	check(w.buildings[s].power_net >= 0, "conectado via postes")
	check(w.stats.produced.get("iron_plate", 0) >= 1, "produziu com energia")


func test_priority_defense_first() -> void:
	var w = empty_world()
	# Core gives 80 kW. Tesla (110, prio 0) + smelter (40, prio 1) exceed it.
	var t: int = w.place("turret_tesla", Vector2i(12, 12), 0)
	var s: int = w.place("smelter", Vector2i(19, 15), 0)
	w.buildings[s].inv = {"iron_ore": 5}
	run_ticks(w, 2)
	check(w.buildings[t].power_sat > 0.7, "defesa atendida primeiro (%.2f)" % w.buildings[t].power_sat)
	eq(w.buildings[s].power_sat, 0.0, "produção sem energia")


func test_generator_burns_coal_and_battery() -> void:
	var w = empty_world()
	var g: int = w.place("generator", Vector2i(12, 12), 0)
	var bat: int = w.place("battery", Vector2i(19, 15), 0)
	w.buildings[g].inv = {"coal": 2}
	run_seconds(w, 10.0)
	check(w.stats.burned >= 1, "carvão queimado")
	check(w.buildings[bat].energy > 0.0, "bateria carregou")
	var stored: float = w.buildings[bat].energy
	# Big consumer: tesla drains battery once fuel runs out.
	w.buildings[g].inv = {}
	w.buildings[g].energy = 0.0
	var t: int = w.place("turret_tesla", Vector2i(12, 18), 0)
	w.place("turret_tesla", Vector2i(19, 12), 0)
	run_seconds(w, 2.0)
	check(w.buildings[bat].energy < stored, "bateria descarregou")
	check(w.buildings[t].power_sat > 0.99, "bateria cobriu déficit")
