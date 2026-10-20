extends "res://tests/test_base.gd"
const Items = preload("res://src/sim/items.gd")


func test_gun_kills_enemy_with_ammo() -> void:
	var w = empty_world()
	var t: int = w.place("turret_gun", Vector2i(10, 15), 0)
	w.buildings[t].inv = {"ammo": 2}
	var e: int = w.spawn_enemy("crawler", Vector2(5.5, 16.5))
	run_seconds(w, 5.0)
	check(not w.enemies.has(e), "inimigo eliminado")
	eq(w.stats.kills, 1, "abate contado")
	check(w.stats.consumed.get("ammo", 0) >= 1, "munição consumida")


func test_gun_without_ammo_does_not_fire() -> void:
	var w = empty_world()
	var t: int = w.place("turret_gun", Vector2i(10, 15), 0)
	w.spawn_enemy("crawler", Vector2(7.5, 16.5))
	run_seconds(w, 1.0)
	eq(w.stats.shots, 0, "sem munição não dispara")
	eq(w.buildings[t].status, "sem munição", "status")


func test_tesla_chains_and_uses_power() -> void:
	var w = empty_world()
	var t: int = w.place("turret_tesla", Vector2i(11, 15), 0)
	w.buildings[t].energy = float(w.buildings[t].def.shot_cost)
	for i in 3:
		w.spawn_enemy("crawler", Vector2(7.5, 15.2 + i * 0.6))
	var used := 0.0
	var max_chain := 0
	for i in 60:
		w.step()
		used += w.power.totals.used
		for ev in w.events:
			if ev.e == "arc":
				max_chain = maxi(max_chain, ev.points.size() - 1)
		w.events.clear()
	check(used > 0.0, "consumiu energia para recarregar")
	eq(max_chain, 3, "descarga em cadeia atinge 3 alvos")


func test_enemy_walks_to_core_and_attacks() -> void:
	var w = empty_world()
	w.spawn_enemy("crawler", Vector2(3.5, 16.5))
	var hp0: float = w.core().hp
	run_seconds(w, 20.0)
	check(w.core().hp < hp0, "núcleo atacado")


func test_runner_goes_around_walls_brute_breaks_them() -> void:
	var w = empty_world()
	# Wall line with a gap far away.
	for y in range(4, 30):
		w.place("wall", Vector2i(8, y), 0, true)
	var r: int = w.spawn_enemy("runner", Vector2(4.5, 16.5))
	var b: int = w.spawn_enemy("brute", Vector2(4.5, 16.5))
	var r_hit_wall := false
	var b_hit_wall := false
	for i in 400:
		w.step()
		var re = w.enemies.get(r)
		if re and re.target != 0 and w.buildings.has(re.target) and w.buildings[re.target].kind == "wall":
			r_hit_wall = true
		var be = w.enemies.get(b)
		if be and be.target != 0 and w.buildings.has(be.target) and w.buildings[be.target].kind == "wall":
			b_hit_wall = true
	check(not r_hit_wall, "corredor contorna o muro")
	check(b_hit_wall, "aríete ataca o muro")


func test_repair_station_heals_with_plates() -> void:
	var w = empty_world()
	var wall: int = w.place("wall", Vector2i(10, 10), 0)
	var rs: int = w.place("repair", Vector2i(12, 12), 0)
	w.buildings[rs].inv = {"iron_plate": 5}
	w.buildings[wall].hp = 100.0
	run_seconds(w, 4.0)
	check(w.buildings[wall].hp > 150.0, "muro reparado: %.0f" % w.buildings[wall].hp)
	check(w.stats.consumed.get("iron_plate", 0) >= 1, "placas consumidas")


func test_spitter_attacks_over_walls_from_range() -> void:
	var w = empty_world()
	# A wall line between the spitter and a turret: it must hit the turret from afar.
	for y in range(12, 20):
		w.place("wall", Vector2i(8, y), 0)
	var t: int = w.place("turret_gun", Vector2i(10, 15), 0)
	var e: int = w.spawn_enemy("spitter", Vector2(6.5, 16.0))
	var hp0: float = w.buildings[t].hp
	var spits := 0
	for i in int(6.0 / Defs.DT):
		w.step()
		for ev in w.events:
			if ev.e == "spit":
				spits += 1
		w.events = []
	check(spits > 0, "cuspiu ácido")
	check(w.buildings[t].hp < hp0, "atingiu a torre atrás do muro")
	check(w.enemies[e].pos.x < 8.0, "ficou do lado de fora do muro")


func test_drone_hub_repairs_far_with_core_plates() -> void:
	var w = empty_world({"width": 40, "height": 40})
	w.research.complete(w, "automation_1")
	w.research.complete(w, "military_1")
	w.research.complete(w, "drones")
	var c: Vector2i = w.core().pos
	var hub: int = w.place("drone_hub", c + Vector2i(-4, 0), 0)
	check(hub != 0, "hub construído (%s)" % w.can_place("drone_hub", c + Vector2i(-4, 0), 0))
	var wall: int = w.place("wall", c + Vector2i(-14, 0), 0)
	w.buildings[wall].hp = 50.0
	var plates: int = int(w.storage.iron_plate)
	var drones := 0
	for i in int(6.0 / Defs.DT):
		w.step()
		for ev in w.events:
			if ev.e == "drone":
				drones += 1
		w.events = []
	check(w.buildings[wall].hp > 50.0, "muro distante reparado")
	check(int(w.storage.iron_plate) < plates, "placas saem do estoque do Núcleo")
	check(drones > 0, "drones voando")


func test_supply_hub_feeds_turrets_from_core() -> void:
	var w = empty_world({"width": 40, "height": 40})
	for t in ["automation_1", "military_1", "drones", "drones_2"]:
		w.research.complete(w, t)
	var c: Vector2i = w.core().pos
	var hub: int = w.place("supply_hub", c + Vector2i(-4, 0), 0)
	check(hub != 0, "hub construído (%s)" % w.can_place("supply_hub", c + Vector2i(-4, 0), 0))
	var gun: int = w.place("turret_gun", c + Vector2i(-12, 0), 0)
	var far: int = w.place("turret_gun", c + Vector2i(6, 14), 0)
	w.storage["ammo"] = 50
	run_seconds(w, 8.0)
	check(Items.count(w.buildings[gun].inv, "ammo") > 0, "torre no alcance recebe munição sem esteira")
	check(int(w.storage.ammo) < 50, "munição sai do estoque do Núcleo")
	eq(Items.count(w.buildings[far].inv, "ammo"), 0, "torre fora do alcance não recebe")
