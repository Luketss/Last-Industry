extends "res://tests/test_base.gd"


func test_place_and_remove_refunds() -> void:
	var w = empty_world()
	var before: int = w.storage.get("iron_plate", 0)
	var id: int = w.place("wall", Vector2i(5, 5), 0)
	check(id > 0, "muro deveria ser construído")
	eq(w.storage.iron_plate, before - 4, "custo descontado")
	check(w.building_at(Vector2i(5, 5)) != null, "grade ocupada")
	check(w.remove(id), "remoção")
	eq(w.storage.iron_plate, before, "custo reembolsado")
	check(w.building_at(Vector2i(5, 5)) == null, "grade liberada")


func test_invalid_placements() -> void:
	var w = empty_world()
	w.place("wall", Vector2i(5, 5), 0)
	eq(w.can_place("smelter", Vector2i(4, 4), 0), "Espaço ocupado", "sobreposição")
	eq(w.can_place("wall", Vector2i(-1, 0), 0), "Fora do mapa", "limites")
	w.set_terrain(Vector2i(8, 8), Defs.T_ROCK)
	eq(w.can_place("wall", Vector2i(8, 8), 0), "Terreno bloqueado", "ruínas")
	eq(w.can_place("miner", Vector2i(10, 4), 0), "Requer depósito de minério", "mineradora sem minério")
	eq(w.can_place("wall", Vector2i(2, 16), 0), "Muito perto de um ninho", "ninho")
	w.storage = {}
	eq(w.can_place("wall", Vector2i(10, 10), 0), "Recursos insuficientes", "custo")
	check(not w.remove(w.core_id), "núcleo não pode ser removido")


func test_rotation_swaps_footprint() -> void:
	var w = empty_world()
	w.data.buildings["test_long"] = {"name": "t", "kind": "wall", "size": [3, 1], "hp": 10, "cost": {}}
	var id: int = w.place("test_long", Vector2i(3, 3), 1)
	var b = w.buildings[id]
	eq(b.size, Vector2i(1, 3), "rotação troca dimensões")
	check(w.building_at(Vector2i(3, 5)) != null, "ocupa célula rotacionada")
	w.data.buildings.erase("test_long")


func test_destroy_leaves_ghost_and_rebuild() -> void:
	var w = empty_world()
	var id: int = w.place("assembler", Vector2i(4, 4), 2)
	w.set_recipe(w.buildings[id], "gear")
	w.damage_building(w.buildings[id], 10000)
	check(not w.buildings.has(id), "estrutura destruída")
	eq(w.ghosts.size(), 1, "fantasma criado")
	eq(w.rebuild_all_ghosts(), 1, "reconstrução")
	var b = w.building_at(Vector2i(4, 4))
	check(b != null and b.rot == 2 and b.recipe == "gear", "reconstruída com rotação e receita")
	eq(w.ghosts.size(), 0, "fantasma removido")


func test_core_destroyed_is_defeat() -> void:
	var w = empty_world()
	w.damage_building(w.core(), 1.0e6)
	eq(w.state, "lost", "derrota")


func test_fog_of_war_blocks_building_until_revealed() -> void:
	var w = World.new(data(), 42)
	var c: Vector2i = w.core().pos
	check(w.is_revealed(c + Vector2i(5, 5)), "área do Núcleo revelada")
	var far := c + Vector2i(24, 0)
	var found := false
	for dy in range(-6, 7):
		var p := far + Vector2i(0, dy)
		if w.in_bounds(p) and w.terrain_at(p) == Defs.T_GROUND and not w.is_revealed(p):
			far = p
			found = true
			break
	check(found, "há chão inexplorado longe do Núcleo")
	check(w.can_place("wall", far, 0).begins_with("Área inexplorada"), "não constrói na névoa")
	w.reveal(Vector2(far) + Vector2(0.5, 0.5), 2.0)
	eq(w.can_place("wall", far, 0), "", "constrói depois de revelar")
	var w2 = World.from_dict(data(), w.to_dict())
	check(w2.is_revealed(far), "névoa salva")
