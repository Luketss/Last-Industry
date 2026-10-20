extends "res://tests/test_base.gd"
## Research tree, unlocks, modifiers and the Phase 6 content (cannon, AA, flyers,
## saboteurs, solar).


func _lab_world():
	var w = empty_world()
	var lab: int = w.place("lab", Vector2i(12, 12), 0)
	return [w, w.buildings[lab]]


func test_locked_content_requires_research() -> void:
	var w = empty_world()
	check(w.can_place("turret_aa", Vector2i(5, 5), 0).begins_with("Requer pesquisa"), "antiaérea bloqueada")
	var a: int = w.place("assembler", Vector2i(12, 12), 0)
	w.set_recipe(w.buildings[a], "shell")
	eq(w.buildings[a].recipe, "ammo", "receita bloqueada não pode ser escolhida")
	w.research.complete(w, "military_1")
	w.research.complete(w, "artillery")
	eq(w.can_place("turret_cannon", Vector2i(5, 5), 0), "", "canhão liberado")
	w.set_recipe(w.buildings[a], "shell")
	eq(w.buildings[a].recipe, "shell", "receita liberada")


func test_lab_consumes_packs_and_completes() -> void:
	var r: Array = _lab_world()
	var w = r[0]
	var lab = r[1]
	check(not w.research.select(w, "anti_air"), "pré-requisito exigido")
	check(w.research.select(w, "automation_1"), "seleção")
	lab.inv = {"research_pack": 10}
	run_seconds(w, 30.0)
	check(w.research.fraction("automation_1") > 0.4, "progresso parcial: %.2f" % w.research.fraction("automation_1"))
	run_seconds(w, 30.0)
	check(w.research.done.has("automation_1"), "pesquisa concluída")
	eq(w.stats.researched, 1, "estatística")
	check(w.research.mod("crafter_speed") > 0.2, "modificador aplicado")
	eq(lab.status, "sem pesquisa", "laboratório ocioso após concluir")


func test_two_labs_do_not_overconsume() -> void:
	var w = empty_world()
	var a = w.buildings[w.place("lab", Vector2i(12, 12), 0)]
	var b = w.buildings[w.place("lab", Vector2i(19, 12), 0)]
	w.research.select(w, "automation_1")
	a.inv = {"research_pack": 10}
	b.inv = {"research_pack": 10}
	run_seconds(w, 40.0)
	check(w.research.done.has("automation_1"), "concluída com dois laboratórios")
	eq(w.stats.consumed.get("research_pack", 0), 10, "consumiu exatamente o custo")


func test_fortification_raises_existing_walls() -> void:
	var w = empty_world()
	var id: int = w.place("wall", Vector2i(5, 5), 0)
	w.buildings[id].hp = 300.0
	w.research.complete(w, "fortification")
	eq(w.buildings[id].max_hp, 900.0, "integridade máxima +50%")
	eq(w.buildings[id].hp, 450.0, "proporção preservada")
	var id2: int = w.place("wall", Vector2i(6, 6), 0)
	eq(w.buildings[id2].hp, 900.0, "muro novo já nasce reforçado")


func test_belt_speed_research() -> void:
	var w = empty_world()
	var b: int = w.place("belt", Vector2i(5, 5), 0)
	w.buildings[b].belt_items = [["iron_plate", 0.0]]
	w.step()
	var slow: float = w.buildings[b].belt_items[0][1]
	w.research.complete(w, "logistics_1")
	w.buildings[b].belt_items = [["iron_plate", 0.0]]
	w.step()
	check(w.buildings[b].belt_items[0][1] > slow * 1.4, "esteira mais rápida")


func test_cannon_splash_damage() -> void:
	var w = empty_world()
	w.research.complete(w, "military_1")
	w.research.complete(w, "artillery")
	var t: int = w.place("turret_cannon", Vector2i(12, 15), 0)
	w.buildings[t].inv = {"shell": 2}
	var ids := []
	for i in 4:
		ids.append(w.spawn_enemy("crawler", Vector2(7.5 + (i % 2) * 0.4, 15.5 + (i / 2) * 0.4)))
	run_ticks(w, 3)
	var hurt := 0
	for id in ids:
		var e = w.enemies.get(id)
		if e == null or e.hp < e.max_hp:
			hurt += 1
	check(hurt >= 3, "um disparo atinge o grupo (%d)" % hurt)


func test_flyer_ignores_walls_and_only_aa_hits_it() -> void:
	var w = empty_world()
	for y in range(0, 32):
		w.place("wall", Vector2i(8, y), 0, true)
	var gun: int = w.place("turret_gun", Vector2i(11, 10), 0)
	w.buildings[gun].inv = {"ammo": 4}
	var g: int = w.place("generator", Vector2i(12, 20), 0)
	var f: int = w.spawn_enemy("glider", Vector2(3.5, 20.5))
	run_seconds(w, 4.0)
	eq(w.stats.shots, 0, "torre balística não atira em voador")
	check(w.enemies.has(f) and w.enemies[f].pos.x > 9.0, "voador passou por cima do muro")
	run_seconds(w, 6.0)
	check(w.buildings[g].hp < w.buildings[g].max_hp, "voador atacou o gerador")
	w.research.complete(w, "military_1")
	w.research.complete(w, "anti_air")
	var aa: int = w.place("turret_aa", Vector2i(10, 17), 0)
	w.buildings[aa].inv = {"ammo": 4}
	run_seconds(w, 5.0)
	check(not w.enemies.has(f), "antiaérea abateu o voador")


func test_saboteur_prefers_infrastructure() -> void:
	var w = empty_world()
	var pole: int = w.place("pole", Vector2i(9, 16), 0)
	w.place("wall", Vector2i(6, 13), 0)
	var s: int = w.spawn_enemy("saboteur", Vector2(5.5, 16.5))
	run_seconds(w, 3.0)
	var e = w.enemies.get(s)
	check(e != null and e.target == pole, "sabotador mira o poste")


func test_solar_output_follows_daylight() -> void:
	var w = empty_world()
	w.research.complete(w, "automation_1")
	w.research.complete(w, "solar")
	w.place("solar", Vector2i(12, 12), 0)
	w.step()
	var day: float = w.power.totals.cap
	w.waves.night = 1.0
	w.step()
	var night: float = w.power.totals.cap
	check(day > night + 25.0, "solar rende menos à noite (%.0f vs %.0f)" % [day, night])


func test_research_survives_save() -> void:
	var w = empty_world()
	var lab = w.buildings[w.place("lab", Vector2i(12, 12), 0)]
	w.research.complete(w, "fortification")
	w.research.select(w, "automation_1")
	lab.inv = {"research_pack": 3}
	run_seconds(w, 6.0)
	var l = World.from_dict(data(), w.to_dict())
	check(l.research.done.has("fortification"), "pesquisas concluídas restauradas")
	eq(l.research.current, "automation_1", "pesquisa atual restaurada")
	eq(l.research.remaining_of("automation_1"), w.research.remaining_of("automation_1"), "progresso restaurado")
	check(l.research.mod("wall_hp") > 0.4, "modificadores reaplicados")
