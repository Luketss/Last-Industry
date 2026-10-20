extends "res://tests/test_base.gd"

const SaveSystem = preload("res://src/sim/save_system.gd")


func test_roundtrip_continues_identically() -> void:
	var w = World.new(data(), 5)
	w.waves.timer = 2.0
	var c: Vector2i = w.core().pos
	w.place("turret_gun", c + Vector2i(-3, 0), 0)
	w.buildings[w.building_at(c + Vector2i(-3, 0)).id].inv = {"ammo": 3}
	w.place("belt", c + Vector2i(4, 0), 0)
	w.place("wall", c + Vector2i(0, 5), 0)
	run_seconds(w, 15.0)
	check(not w.enemies.is_empty(), "inimigos ativos no salvamento")
	check(SaveSystem.save(w, "test_slot"), "salvou")
	var loaded = SaveSystem.load_world(data(), "test_slot")
	check(loaded != null, "carregou")
	if loaded == null:
		return
	run_seconds(w, 15.0)
	run_seconds(loaded, 15.0)
	eq(JSON.stringify(loaded.to_dict()), JSON.stringify(w.to_dict()), "continuação determinística")
	DirAccess.remove_absolute(SaveSystem.slot_path("test_slot"))
