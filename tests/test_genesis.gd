extends "res://tests/test_base.gd"
## Genesis ending and data terminals.


func _powered_world():
	var w = empty_world({"width": 40, "height": 40})
	w.research.complete(w, "military_1")
	w.research.complete(w, "artillery")
	w.research.complete(w, "anti_air")
	w.research.complete(w, "genesis_1")
	w.research.complete(w, "genesis_2")
	w.storage["iron_plate"] = 5000
	w.storage["gear"] = 5000
	w.storage["ammo"] = 500
	return w


func test_genesis_charges_and_waits_for_ending() -> void:
	var w = _powered_world()
	var c: Vector2i = w.core().pos
	var id: int = w.place("genesis", c + Vector2i(4, -1), 0)
	check(id != 0, "Genesis construída (%s)" % w.can_place("genesis", c + Vector2i(4, -1), 0))
	var g = w.buildings[id]
	g.def = g.def.duplicate()
	g.def.charge_time = 8.0
	g.def.power = 1.0   # the core's residual supply is enough in this test
	run_seconds(w, 11.0)
	eq(w.state, "genesis", "simulação aguarda a escolha")
	check(not w.enemies.is_empty(), "ondas de surto durante a carga")
	var t: int = w.tick
	run_seconds(w, 1.0)
	eq(w.tick, t, "simulação parada até a escolha")
	w.choose_ending("nao_existe")
	eq(w.state, "genesis", "final inválido ignorado")
	w.choose_ending("fortress")
	eq(w.state, "won", "campanha encerrada")
	eq(w.ending, "fortress", "final registrado")
	eq(w.stats.value("ending:fortress"), 1, "estatística para a conquista")
	var w2 = World.from_dict(data(), w.to_dict())
	eq(w2.ending, "fortress", "final salvo")


func test_genesis_locked_without_research() -> void:
	var w = empty_world()
	w.storage["iron_plate"] = 5000
	w.storage["gear"] = 5000
	w.storage["ammo"] = 500
	check(w.can_place("genesis", w.core().pos + Vector2i(4, -1), 0) != "", "requer Protocolo Genesis")


func test_terminals_need_presence_and_reward_once() -> void:
	var w = empty_world({"width": 40, "height": 40})
	var cell := Vector2i(30, 30)
	w.terminals[w.idx(cell)] = {"n": 2, "read": false}
	check(w.read_terminal(cell) != "", "longe de qualquer estrutura não decodifica")
	check(w.can_place("wall", cell, 0) != "", "não se constrói sobre o terminal")
	w.storage["iron_plate"] = 100
	w.place("wall", cell + Vector2i(-3, 0), 0)
	var plates: int = int(w.storage.get("iron_plate", 0))
	eq(w.read_terminal(cell), "", "decodifica com estrutura perto")
	eq(int(w.storage.iron_plate), plates + 40, "recompensa recebida")
	eq(w.stats.terminals, 1, "contado")
	check(w.transmissions.back().title == "TERMINAL 3-C", "transmissão do terminal")
	check(w.read_terminal(cell) != "", "só uma vez")
	var w2 = World.from_dict(data(), w.to_dict())
	check(w2.terminals[w.idx(cell)].read, "estado do terminal salvo")


func test_generated_maps_have_four_terminals() -> void:
	for s in [3, 77, 1337]:
		var w = World.new(data(), s)
		eq(w.terminals.size(), 4, "seed %d: quatro terminais" % s)
		for k in w.terminals:
			eq(w.terrain[k], Defs.T_GROUND, "terminal em chão livre")
