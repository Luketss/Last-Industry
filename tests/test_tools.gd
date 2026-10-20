extends "res://tests/test_base.gd"
## Phase 7 tools: blueprints and resource tracing.

const Blueprint = preload("res://src/sim/blueprint.gd")


func _chain(w) -> Dictionary:
	for y in [15, 16]:
		for x in [8, 9]:
			w.set_terrain(Vector2i(x, y), Defs.T_IRON, 500)
	var ids := {}
	ids.miner = w.place("miner", Vector2i(8, 15), 0)
	ids.b1 = w.place("belt", Vector2i(10, 15), 0)
	ids.smelter = w.place("smelter", Vector2i(11, 15), 0)
	ids.b2 = w.place("belt", Vector2i(13, 15), 0)
	ids.b3 = w.place("belt", Vector2i(14, 15), 0)
	ids.turret = w.place("turret_gun", Vector2i(13, 13), 0)
	return ids


func test_trace_upstream_and_downstream() -> void:
	var w = empty_world()
	var ids := _chain(w)
	w.logistics.rebuild(w)
	var up: Array = w.logistics.trace(w, ids.b3, true)
	check(ids.smelter in up and ids.miner in up and ids.b1 in up, "origem rastreada até a mineradora: %s" % str(up))
	var down: Array = w.logistics.trace(w, ids.miner, false)
	check(ids.smelter in down and w.core_id in down, "destino rastreado até o núcleo")
	check(ids.turret in down, "torre que puxa da esteira aparece no fluxo")


func test_blueprint_roundtrip_and_cost() -> void:
	var w = empty_world()
	var a: int = w.place("assembler", Vector2i(3, 3), 1)
	w.set_recipe(w.buildings[a], "gear")
	var b: int = w.place("belt", Vector2i(5, 3), 0)
	w.buildings[b].enabled = false
	var bp: Dictionary = Blueprint.capture(w, [a, b, w.core_id])
	eq(bp.entries.size(), 2, "núcleo excluído")
	eq([bp.w, bp.h], [3, 2], "dimensões")
	var before: int = w.storage.iron_plate
	var r: Array = Blueprint.paste(w, bp, Vector2i(3, 22))
	eq(r, [2, 0], "colado")
	eq(w.storage.iron_plate, before - 11, "custo cobrado")
	var na = w.building_at(Vector2i(3, 22))
	check(na != null and na.recipe == "gear" and na.rot == 1, "receita e rotação preservadas")
	check(not w.building_at(Vector2i(5, 22)).enabled, "estado ligado/desligado preservado")
	eq(Blueprint.paste(w, bp, Vector2i(3, 22)), [0, 2], "espaço ocupado é pulado")


func test_blueprint_rotation() -> void:
	var w = empty_world()
	var a: int = w.place("smelter", Vector2i(3, 3), 0)
	var b: int = w.place("belt", Vector2i(5, 3), 0)
	var bp: Dictionary = Blueprint.capture(w, [a, b])
	var r1: Dictionary = Blueprint.rotated(w, bp)
	eq([r1.w, r1.h], [2, 3], "dimensões giradas")
	var belt_e: Dictionary = r1.entries[1]
	eq([belt_e.x, belt_e.y, belt_e.rot], [1, 2, 1], "esteira girada para o sul abaixo da fundição")
	var r4: Dictionary = bp
	for i in 4:
		r4 = Blueprint.rotated(w, r4)
	eq(JSON.stringify(r4), JSON.stringify(bp), "quatro rotações voltam ao original")
	Blueprint.paste(w, r1, Vector2i(20, 3))
	var s = w.building_at(Vector2i(20, 3))
	check(s != null and s.type == "smelter" and Vector2i(21, 5) in s.output_cells(), "fundição girada entrega na esteira")
	eq(w.building_at(Vector2i(21, 5)).type, "belt", "esteira na saída girada")


func test_objective_marker_points_at_nearest_ore() -> void:
	var w = empty_world()
	var c: Vector2i = w.core().pos
	w.set_terrain(c + Vector2i(-9, 0), Defs.T_IRON, 100)
	w.set_terrain(c + Vector2i(5, 0), Defs.T_IRON, 100)
	var t = w.objectives.target(w)
	check(t != null, "objetivo inicial aponta para o minério")
	check(t.distance_to(Vector2(c + Vector2i(5, 0)) + Vector2(0.5, 0.5)) < 0.01, "jazida mais próxima do Núcleo (%s)" % str(t))
